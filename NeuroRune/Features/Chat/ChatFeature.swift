//
//  ChatFeature.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import ComposableArchitecture

nonisolated struct ChatFeature: Reducer {

    /// Effect 취소 ID. Phase 20: 스트리밍 중 [Stop] 버튼으로 현재 LLM 요청 취소.
    enum CancelID: Hashable {
        case streaming
    }

    struct State: Equatable {
        var conversation: Conversation
        var inputText: String
        var isStreaming: Bool
        var error: LLMError?
        var persistenceError: String? = nil
        /// 진행 중인 tool 호출. 칩으로 표시되고 완료 시 제거.
        var activeToolCalls: [ToolCallStatus] = []
        /// Claude가 write_memory 요청. nil이 아니면 confirm modal 열림.
        var pendingWrite: WriteRequest? = nil
        /// 가장 최근 응답에서 파싱된 Anthropic rate limit 쿼터. nil이면 아직 정보 없음.
        var rateLimit: RateLimitState? = nil
        /// Phase 21 — 마이크 녹음 중 여부.
        var isRecording: Bool = false
        /// STT 에러. LLMError와 별개 타입이라 별도 슬롯에 보관.
        var sttError: STTError? = nil
    }

    /// 사용자에게 보여줄 tool 호출 정보 (id로 lifecycle 추적).
    nonisolated struct ToolCallStatus: Equatable, Sendable, Identifiable {
        let id: String
        let name: String
        let input: [String: String]
    }

    /// write_memory tool 호출 요청. confirm modal이 바인딩.
    nonisolated struct WriteRequest: Equatable, Sendable, Identifiable {
        let id: String
        let role: CredentialsRole
        let path: String
        let content: String
        let commitMessage: String
    }

    enum Action: Equatable {
        // MARK: - Input & Send
        case inputChanged(String)
        case sendTapped

        // MARK: - Streaming
        case streamChunkReceived(String)
        case streamFinished
        /// 스트리밍 중 [Stop] 버튼. 현재 effect를 취소하고 partial 응답을 보존한 채 종료.
        case stopTapped

        // MARK: - Errors & Retry
        case errorOccurred(LLMError)
        /// 에러 버블의 [재시도] 버튼. 마지막 user 메시지를 다시 보낸다.
        case retryTapped
        /// 에러 버블의 [닫기] 버튼 또는 사용자 수동 해제.
        case errorDismissed

        // MARK: - Persistence
        case persistenceFailed(String)
        case persistenceErrorDismissed

        // MARK: - Conversation lifecycle
        case newConversationStarted(modelId: String)

        // MARK: - Rate limit
        case rateLimitUpdated(RateLimitState)

        // MARK: - Tools
        case toolUseRequested(id: String, name: String, input: [String: String])
        case toolUseCompleted(id: String)

        // MARK: - Write approval
        case writeApprovalRequested(WriteRequest)
        case writeApproved(id: String)
        case writeRejected(id: String, reason: String?)

        // MARK: - STT (Phase 21)
        /// 마이크 버튼 토글. 녹음 중이면 stop, 아니면 권한→start.
        case micTapped
        case recordingStarted
        case recordingStopped(Data)
        case transcribed(STTResult)
        case sttErrorOccurred(STTError)
        case sttErrorDismissed
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.date) var date
        @Dependency(\.uuid) var uuid
        @Dependency(\.llmClient) var llmClient
        @Dependency(\.conversationStore) var conversationStore
        @Dependency(\.githubClient) var githubClient
        @Dependency(\.githubCredentialsClient) var githubCredentialsClient
        @Dependency(\.writeApprovalGate) var writeApprovalGate

        switch action {
        case let .inputChanged(text):
            state.inputText = text
            return .none

        case let .newConversationStarted(modelId):
            state.conversation = Conversation(
                id: uuid(),
                title: "",
                messages: [],
                modelId: modelId,
                createdAt: date.now
            )
            state.inputText = ""
            state.isStreaming = false
            state.error = nil
            return .none

        case .sendTapped:
            guard !state.inputText.isEmpty, !state.isStreaming else { return .none }
            let userMessage = Message(
                role: .user,
                content: state.inputText,
                createdAt: date.now
            )
            let placeholder = Message(
                role: .assistant,
                content: "",
                createdAt: date.now
            )
            state.conversation = state.conversation
                .appending(userMessage)
                .appending(placeholder)
            state.inputText = ""
            state.isStreaming = true
            state.error = nil

            // 디스크엔 placeholder 없이 저장. placeholder는 UI 전용 스트리밍 타겟.
            let conversationForDisk = state.conversation.droppingLastMessage()
            let messagesForAPI = conversationForDisk.messages
            let model = LLMModel.resolve(id: state.conversation.modelId)
            return .run { send in
                await Self.save(conversationForDisk, using: conversationStore, send: send)
                do {
                    let system = await Self.loadSystemPrompt(
                        github: githubClient,
                        creds: githubCredentialsClient
                    )
                    var roundMessages: [APIMessage] = messagesForAPI.map {
                        APIMessage.text(role: $0.role.rawValue, content: $0.content)
                    }
                    let tools: [LLMTool] = [.readMemory, .writeMemory]
                    let maxRounds = 5
                    for _ in 0..<maxRounds {
                        var roundText = ""
                        var roundToolUses: [(id: String, name: String, inputJSON: String)] = []
                        let stream = try await llmClient.streamMessage(
                            roundMessages, model, conversationForDisk.effort, system, tools
                        )
                        for try await event in stream {
                            switch event {
                            case .textDelta(let text):
                                roundText += text
                                await send(.streamChunkReceived(text))
                            case let .toolUseRequest(id, name, inputJSON):
                                roundToolUses.append((id, name, inputJSON))
                            case let .rateLimitUpdate(state):
                                await send(.rateLimitUpdated(state))
                            }
                        }
                        if roundToolUses.isEmpty { break }

                        // 다음 라운드: 이번 round의 assistant content + tool_result blocks
                        roundMessages.append(Self.buildAssistantTurn(roundText: roundText, toolUses: roundToolUses))
                        let resultBlocks = await Self.executeTools(
                            roundToolUses,
                            send: send,
                            github: githubClient,
                            creds: githubCredentialsClient,
                            gate: writeApprovalGate
                        )
                        roundMessages.append(APIMessage(role: "user", content: .blocks(resultBlocks)))
                    }
                    await send(.streamFinished)
                } catch is CancellationError {
                    // stopTapped가 streamFinished를 명시적으로 보낸다.
                    // 취소된 effect는 후속 액션을 중복 발행하지 않는다.
                } catch let error as LLMError {
                    await send(.errorOccurred(error))
                } catch {
                    await send(.errorOccurred(.network(error.localizedDescription)))
                }
            }
            .cancellable(id: CancelID.streaming, cancelInFlight: true)

        case .stopTapped:
            // 현재 진행 중인 스트리밍 effect를 취소하고 기존 완료 경로로 정리한다.
            guard state.isStreaming else { return .none }
            return .concatenate(
                .cancel(id: CancelID.streaming),
                .send(.streamFinished)
            )

        case let .streamChunkReceived(chunk):
            guard let last = state.conversation.messages.last, last.role == .assistant else {
                return .none
            }
            let updated = Message(
                role: last.role,
                content: last.content + chunk,
                createdAt: last.createdAt
            )
            state.conversation = state.conversation.replacingLastMessage(with: updated)
            return .none

        case .streamFinished:
            state.isStreaming = false
            let conversation = state.conversation
            return .run { send in
                await Self.save(conversation, using: conversationStore, send: send)
            }

        case let .errorOccurred(llmError):
            state.error = llmError
            state.isStreaming = false
            // 에러 시 진행 중이던 tool 칩/modal도 정리. stream 도중 실패면
            // 미해결 continuation은 effect cancel로 함께 사라짐.
            state.activeToolCalls = []
            state.pendingWrite = nil
            // 429 응답에 담긴 rate limit 쿼터를 state로 끌어올려 배지에 반영.
            if case let .rateLimited(_, rateLimit?) = llmError {
                state.rateLimit = rateLimit
            }
            // 스트리밍 중 실패면 trailing assistant(placeholder/부분응답) 제거 + 재저장.
            // 부분 응답 보존 X — "이게 진짜 답인가" 혼란 방지, 사용자는 재시도.
            let hadTrailingAssistant = state.conversation.messages.last?.role == .assistant
            if hadTrailingAssistant {
                state.conversation = state.conversation.droppingLastMessage()
                let conversation = state.conversation
                return .run { send in
                    await Self.save(conversation, using: conversationStore, send: send)
                }
            }
            return .none

        case let .persistenceFailed(message):
            state.persistenceError = message
            return .none

        case .persistenceErrorDismissed:
            state.persistenceError = nil
            return .none

        case let .toolUseRequested(id, name, input):
            state.activeToolCalls.append(ToolCallStatus(id: id, name: name, input: input))
            return .none

        case let .toolUseCompleted(id):
            state.activeToolCalls.removeAll { $0.id == id }
            return .none

        case let .writeApprovalRequested(req):
            state.pendingWrite = req
            return .none

        case let .writeApproved(id):
            state.pendingWrite = nil
            return .run { _ in
                writeApprovalGate.setApproval(id, .approve)
            }

        case let .writeRejected(id, reason):
            state.pendingWrite = nil
            return .run { _ in
                writeApprovalGate.setApproval(id, .reject(reason: reason))
            }

        case let .rateLimitUpdated(rateLimit):
            state.rateLimit = rateLimit
            return .none

        case .retryTapped:
            // errorOccurred에서 trailing assistant placeholder는 이미 드롭된 상태.
            // 마지막 user 메시지를 꺼내고, 제거한 뒤 sendTapped로 재전송.
            guard let last = state.conversation.messages.last, last.role == .user else {
                return .none
            }
            state.error = nil
            state.conversation = state.conversation.droppingLastMessage()
            state.inputText = last.content
            return .send(.sendTapped)

        case .errorDismissed:
            state.error = nil
            return .none

        // MARK: - STT (ChatFeature+STT.swift로 위임)

        case .micTapped, .recordingStarted, .recordingStopped, .transcribed,
             .sttErrorOccurred, .sttErrorDismissed:
            return reduceSTT(into: &state, action: action)
        }
    }

    /// 이번 라운드 assistant 메시지 구성: text + tool_use 블록들.
    private static func buildAssistantTurn(
        roundText: String,
        toolUses: [(id: String, name: String, inputJSON: String)]
    ) -> APIMessage {
        var blocks: [APIContentBlock] = []
        if !roundText.isEmpty {
            blocks.append(.text(roundText))
        }
        for tool in toolUses {
            let input = parseToolInput(tool.inputJSON) ?? [:]
            blocks.append(.toolUse(id: tool.id, name: tool.name, input: input))
        }
        return APIMessage(role: "assistant", content: .blocks(blocks))
    }

    /// 라운드 내 tool_use 블록들을 순차 실행해서 tool_result 블록 리스트 반환.
    /// write_memory는 gate.requestApproval로 사용자 응답 대기.
    private static func executeTools(
        _ toolUses: [(id: String, name: String, inputJSON: String)],
        send: Send<Action>,
        github: GitHubClient,
        creds: GitHubCredentialsClient,
        gate: WriteApprovalGate
    ) async -> [APIContentBlock] {
        var resultBlocks: [APIContentBlock] = []
        for tool in toolUses {
            let input = parseToolInput(tool.inputJSON) ?? [:]
            await send(.toolUseRequested(id: tool.id, name: tool.name, input: input))
            let result: String
            if tool.name == "write_memory", let req = parseWriteRequest(id: tool.id, input: input) {
                await send(.writeApprovalRequested(req))
                let decision = await gate.requestApproval(tool.id)
                switch decision {
                case .approve:
                    result = await executeWriteMemory(request: req, github: github, creds: creds)
                case let .reject(reason):
                    result = "User rejected" + (reason.map { ": \($0)" } ?? "")
                }
            } else {
                result = await executeTool(name: tool.name, input: input, github: github, creds: creds)
            }
            await send(.toolUseCompleted(id: tool.id))
            resultBlocks.append(.toolResult(toolUseID: tool.id, content: result))
        }
        return resultBlocks
    }

    /// Claude의 tool_use input JSON을 [String:String]로 파싱.
    /// read_memory 같은 string-only 파라미터 tool 한정.
    private static func parseToolInput(_ json: String) -> [String: String]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// tool 이름별 dispatch. 알 수 없는 tool은 에러 텍스트 반환 (멀티턴 계속 진행).
    private static func executeTool(
        name: String,
        input: [String: String],
        github: GitHubClient,
        creds: GitHubCredentialsClient
    ) async -> String {
        switch name {
        case "read_memory":
            return await executeReadMemory(input: input, github: github, creds: creds)
        default:
            return "Error: unknown tool '\(name)'"
        }
    }

    /// write_memory tool input → WriteRequest 파싱. role/path/content/commit_message 중 하나라도
    /// 누락/잘못되면 nil.
    private static func parseWriteRequest(id: String, input: [String: String]) -> WriteRequest? {
        guard let roleStr = input["role"],
              let role = CredentialsRole(rawValue: roleStr),
              let path = input["path"],
              let content = input["content"],
              let commitMessage = input["commit_message"]
        else { return nil }
        return WriteRequest(id: id, role: role, path: path, content: content, commitMessage: commitMessage)
    }

    /// 사용자 approve 후 GitHub saveFile 호출. 기존 파일이면 sha 조회해서 upsert.
    private static func executeWriteMemory(
        request: WriteRequest,
        github: GitHubClient,
        creds: GitHubCredentialsClient
    ) async -> String {
        guard let credentials = try? creds.load(request.role) else {
            return "Error: \(request.role.rawValue) credentials not configured"
        }
        let existingSha = try? await github.loadFile(credentials.repoConfig, request.path).sha
        do {
            let saved = try await github.saveFile(
                credentials.repoConfig,
                request.path,
                request.content,
                existingSha,
                request.commitMessage
            )
            return "Saved: \(saved.path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private static func executeReadMemory(
        input: [String: String],
        github: GitHubClient,
        creds: GitHubCredentialsClient
    ) async -> String {
        guard let roleStr = input["role"], let role = CredentialsRole(rawValue: roleStr) else {
            return "Error: missing or invalid 'role' (expected 'global' or 'local')"
        }
        guard let path = input["path"] else {
            return "Error: missing 'path'"
        }
        guard let credentials = try? creds.load(role) else {
            return "Error: \(role.rawValue) credentials not configured"
        }
        do {
            let file = try await github.loadFile(credentials.repoConfig, path)
            return file.content
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    /// 두 role(.global/.local)의 MEMORY.md를 fetch해 헤더 붙여 concat.
    /// credentials 없거나 fetch 실패한 role은 skip. 둘 다 비면 nil 반환.
    /// fetch 실패는 LLMError로 surface하지 않음 (메모리는 보조 컨텍스트, 누락이 send 자체를 막진 않음).
    private static func loadSystemPrompt(
        github: GitHubClient,
        creds: GitHubCredentialsClient
    ) async -> String? {
        var sections: [String] = []
        for role in CredentialsRole.allCases {
            guard let credentials = try? creds.load(role) else { continue }
            let path = credentials.path.isEmpty
                ? "MEMORY.md"
                : "\(credentials.path)/MEMORY.md"
            guard let file = try? await github.loadFile(credentials.repoConfig, path) else { continue }
            let header = role == .global ? "## Global Memory" : "## Local Memory"
            sections.append("\(header)\n\n\(file.content)")
        }
        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    /// 저장 실패 시 `.persistenceFailed(String)` 액션을 디스패치한다.
    /// sendTapped/streamFinished/errorOccurred의 공통 save 패턴 추출.
    private static func save(
        _ conversation: Conversation,
        using store: ConversationStore,
        send: Send<Action>
    ) async {
        do {
            try await store.save(conversation)
        } catch {
            await send(.persistenceFailed(error.localizedDescription))
        }
    }
}

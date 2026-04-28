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
    /// Phase 22: TTS 재생 중 새 탭으로 기존 재생 취소.
    enum CancelID: Hashable {
        case streaming
        case speaking
        /// STT 전사 완료 후 자동 전송 카운트다운 타이머.
        case autoSend
    }

    struct State: Equatable {
        var conversation: Conversation
        var inputText: String
        var isStreaming: Bool
        var error: LLMError?
        var persistenceError: String?
        /// 진행 중인 tool 호출. 칩으로 표시되고 완료 시 제거.
        var activeToolCalls: [ToolCallStatus] = []
        /// Claude가 write_memory 요청. nil이 아니면 confirm modal 열림.
        var pendingWrite: WriteRequest?
        /// 가장 최근 응답에서 파싱된 Anthropic rate limit 쿼터. nil이면 아직 정보 없음.
        var rateLimit: RateLimitState?
        /// Phase 21 — 마이크 녹음 중 여부.
        var isRecording: Bool = false
        /// STT 에러. LLMError와 별개 타입이라 별도 슬롯에 보관.
        var sttError: STTError?
        /// Phase 22 — 현재 재생 중인 메시지 id. nil이면 재생 중 아님.
        var speakingMessageID: UUID?
        /// TTS 에러.
        var speakError: SpeechError?
        /// 사용자 TTS 설정 (voice·rate·pitch·autoSpeak). 첫 진입 시 client.load()로 동기화.
        var speechSettings: SpeechSettings = SpeechSettings()
        /// 상세 설정 sheet 노출 여부.
        var showSpeechSettings: Bool = false
        /// Phase 22.5 — autoSpeak 스트리밍 시 문장 추출 버퍼.
        var speakBuffer: String = ""
        /// 합성·재생 대기 큐 (FIFO).
        var speakQueue: [String] = []
        /// 현재 큐 처리 중 여부.
        var isSpeakingQueue: Bool = false
        /// 현재 assistant 응답의 TTS 누적 문자 수.
        var speakTotalChars: Int = 0
        /// Phase 21 — STT 전사 완료 후 자동 전송 카운트다운(2 → 1 → 발사/취소).
        /// nil이면 카운트다운 없음. 입력창 탭 또는 mic 재탭으로 취소.
        var autoSendCountdown: Int?
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
        /// 기존 파일 내용. nil이면 신규 생성. 승인 modal에서 before/after 비교에 사용.
        let existingContent: String?

        init(id: String, role: CredentialsRole, path: String, content: String, commitMessage: String, existingContent: String? = nil) {
            self.id = id
            self.role = role
            self.path = path
            self.content = content
            self.commitMessage = commitMessage
            self.existingContent = existingContent
        }
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
        /// Phase 21 — 전사 완료 후 자동 전송 타이머 tick. 2→1→sendTapped 또는 0→sendTapped.
        case autoSendTick
        /// 카운트다운 취소 (입력창 탭 또는 mic 재탭).
        case autoSendCancelled

        // MARK: - TTS (Phase 22)
        /// assistant 버블 스피커 버튼. 해당 메시지 재생 시작 또는 중단 토글.
        case speakTapped(UUID)
        case speakingStarted(UUID)
        case speakingFinished
        case stopSpeakTapped
        case speakErrorOccurred(SpeechError)
        case speakErrorDismissed

        // MARK: - TTS sentence queue (Phase 22.5)
        case speakSentenceEnqueued(String)
        case processSpeakQueue
        case sentencePlaybackCompleted

        // MARK: - Speech settings (Phase 22 Slice 7)
        case loadSpeechSettings
        case speechSettingsLoaded(SpeechSettings)
        case speechVoiceSelected(voiceId: String, voiceName: String)
        case autoSpeakToggled(Bool)
        case speechStabilityChanged(Double)
        case speechSimilarityChanged(Double)
        case speechStyleChanged(Double)
        case speechSpeakerBoostToggled(Bool)
        case speechSettingsTapped
        case speechSettingsDismissed
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
            // 카운트다운 중 입력 변경 = 사용자가 개입. 자동 전송 취소.
            if state.autoSendCountdown != nil {
                state.autoSendCountdown = nil
                return .cancel(id: CancelID.autoSend)
            }
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

        // MARK: - Streaming (ChatFeature+Streaming.swift로 위임)

        case .sendTapped, .stopTapped, .streamChunkReceived, .streamFinished, .retryTapped:
            return reduceStreaming(into: &state, action: action)

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

        // MARK: - Write approval (ChatFeature+WriteApproval.swift로 위임)

        case .writeApprovalRequested, .writeApproved, .writeRejected:
            return reduceWriteApproval(into: &state, action: action)

        case let .rateLimitUpdated(rateLimit):
            state.rateLimit = rateLimit
            return .none

        case .errorDismissed:
            state.error = nil
            return .none

        // MARK: - STT (ChatFeature+STT.swift로 위임)

        case .micTapped, .recordingStarted, .recordingStopped, .transcribed,
             .sttErrorOccurred, .sttErrorDismissed, .autoSendTick, .autoSendCancelled:
            return reduceSTT(into: &state, action: action)

        // MARK: - TTS (ChatFeature+Speak.swift로 위임)

        case .speakTapped, .speakingStarted, .speakingFinished,
             .stopSpeakTapped, .speakErrorOccurred, .speakErrorDismissed,
             .speakSentenceEnqueued, .processSpeakQueue, .sentencePlaybackCompleted,
             .loadSpeechSettings, .speechSettingsLoaded,
             .speechVoiceSelected, .autoSpeakToggled,
             .speechStabilityChanged, .speechSimilarityChanged,
             .speechStyleChanged, .speechSpeakerBoostToggled,
             .speechSettingsTapped, .speechSettingsDismissed:
            return reduceSpeak(into: &state, action: action)
        }
    }

    /// 이번 라운드 assistant 메시지 구성: text + tool_use 블록들.
    static func buildAssistantTurn(
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
    static func executeTools(
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
            if tool.name == "write_memory", let parsed = parseWriteRequest(id: tool.id, input: input) {
                // 기존 파일 load — 실패(notFound 등)면 nil = 신규 생성
                let existingContent = try? await github.loadFile(parsed.role, parsed.path).content
                let req = WriteRequest(
                    id: parsed.id,
                    role: parsed.role,
                    path: parsed.path,
                    content: parsed.content,
                    commitMessage: parsed.commitMessage,
                    existingContent: existingContent
                )
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
    static func parseToolInput(_ json: String) -> [String: String]? {
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
    /// 누락/잘못되면 nil. path는 `MemoryPathPolicy`로 검증·정규화.
    private static func parseWriteRequest(id: String, input: [String: String]) -> WriteRequest? {
        guard let roleStr = input["role"],
              let role = CredentialsRole(rawValue: roleStr),
              let rawPath = input["path"],
              let path = try? MemoryPathPolicy.validate(rawPath),
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
        guard (try? creds.load(request.role)) != nil else {
            return "Error: \(request.role.rawValue) credentials not configured"
        }
        let existingSha = try? await github.loadFile(request.role, request.path).sha
        do {
            let saved = try await github.saveFile(
                request.role,
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
        guard let rawPath = input["path"] else {
            return "Error: missing 'path'"
        }
        let path: String
        do {
            path = try MemoryPathPolicy.validate(rawPath)
        } catch let error as MemoryPathError {
            return "Error: invalid path — \(error.localizedMessage)"
        } catch {
            return "Error: invalid path"
        }
        guard (try? creds.load(role)) != nil else {
            return "Error: \(role.rawValue) credentials not configured"
        }
        do {
            let file = try await github.loadFile(role, path)
            return file.content
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    /// 두 role(.global/.local)의 MEMORY.md를 fetch해 헤더 붙여 concat.
    /// credentials 없거나 fetch 실패한 role은 skip. 둘 다 비면 nil 반환.
    /// fetch 실패는 LLMError로 surface하지 않음 (메모리는 보조 컨텍스트, 누락이 send 자체를 막진 않음).
    static func loadSystemPrompt(
        github: GitHubClient,
        creds: GitHubCredentialsClient
    ) async -> String? {
        var sections: [String] = []
        for role in CredentialsRole.allCases {
            guard let credentials = try? creds.load(role) else { continue }
            let rawPath = credentials.path.isEmpty
                ? "MEMORY.md"
                : "\(credentials.path)/MEMORY.md"
            guard let path = try? MemoryPathPolicy.validate(rawPath) else { continue }
            guard let file = try? await github.loadFile(role, path) else { continue }
            let header = role == .global ? "## Global Memory" : "## Local Memory"
            sections.append("\(header)\n\n\(file.content)")
        }
        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    /// 모델 정체성 preamble + 메모리 컨텍스트 합성.
    /// 새 모델은 학습 데이터에 자기 자신이 없어 cutoff 직전 모델로 자칭하는 환각이 있음.
    /// system 첫 줄에 정체성을 박아 대화 중 자칭/메타 인지가 정확하도록 보정.
    static func composeSystemPrompt(model: LLMModel, memory: String?) -> String {
        let identity = "You are \(model.displayName) (model id: \(model.id))."
        guard let memory else { return identity }
        return "\(identity)\n\n\(memory)"
    }

    /// 저장 실패 시 `.persistenceFailed(String)` 액션을 디스패치한다.
    /// sendTapped/streamFinished/errorOccurred의 공통 save 패턴 추출.
    static func save(
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

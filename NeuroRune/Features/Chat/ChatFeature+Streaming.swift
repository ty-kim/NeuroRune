//
//  ChatFeature+Streaming.swift
//  NeuroRune
//
//  Created by tykim
//
//  스트리밍 응답 파이프라인(send → chunks → finished/error) + stop/retry 를
//  main reducer에서 분리. +STT, +Speak, +WriteApproval 패턴 대칭.
//

import Foundation
import ComposableArchitecture

nonisolated extension ChatFeature {

    /// 스트리밍·전송·취소·재시도 관련 action 전담 reducer.
    func reduceStreaming(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.date) var date
        @Dependency(\.llmClient) var llmClient
        @Dependency(\.conversationStore) var conversationStore
        @Dependency(\.githubClient) var githubClient
        @Dependency(\.githubCredentialsClient) var githubCredentialsClient
        @Dependency(\.writeApprovalGate) var writeApprovalGate

        switch action {
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
            state.speakTotalChars = 0
            // 카운트다운 중 Send 누르면 즉시 전송. 타이머 취소.
            state.autoSendCountdown = nil

            // 디스크엔 placeholder 없이 저장. placeholder는 UI 전용 스트리밍 타겟.
            let conversationForDisk = state.conversation.droppingLastMessage()
            let messagesForAPI = conversationForDisk.messages
            let model = LLMModel.resolve(id: state.conversation.modelId)
            return .merge(
                .cancel(id: CancelID.autoSend),
                .run { send in
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
                    } catch let error as LLMError {
                        await send(.errorOccurred(error))
                    } catch {
                        await send(.errorOccurred(.network(error.localizedDescription)))
                    }
                }
                .cancellable(id: CancelID.streaming, cancelInFlight: true)
            )

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
                id: last.id,
                role: last.role,
                content: last.content + chunk,
                createdAt: last.createdAt
            )
            state.conversation = state.conversation.replacingLastMessage(with: updated)

            // Phase 22.5: autoSpeak + 스트리밍이면 문장 단위로 큐에 enqueue
            guard state.speechSettings.autoSpeak else { return .none }
            let sentences = SentenceStreamer.extract(chunk, buffer: &state.speakBuffer)
            guard !sentences.isEmpty else { return .none }
            return .run { send in
                for s in sentences {
                    await send(.speakSentenceEnqueued(s))
                }
            }

        case .streamFinished:
            state.isStreaming = false
            let conversation = state.conversation
            // Phase 22.5 — autoSpeak 스트리밍 모드: 남은 버퍼를 마지막 문장으로 flush.
            let finalSentence: String? = {
                guard state.speechSettings.autoSpeak else { return nil }
                let remainder = state.speakBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                state.speakBuffer = ""
                return remainder.isEmpty ? nil : remainder
            }()
            return .run { send in
                await Self.save(conversation, using: conversationStore, send: send)
                if let s = finalSentence {
                    await send(.speakSentenceEnqueued(s))
                }
            }

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

        default:
            return .none
        }
    }
}

//
//  ChatFeature.swift
//  NeuroRune
//

import Foundation
import ComposableArchitecture

nonisolated struct ChatFeature: Reducer {

    struct State: Equatable {
        var conversation: Conversation
        var inputText: String
        var isStreaming: Bool
        var error: LLMError?
        var persistenceError: String? = nil
    }

    enum Action: Equatable {
        case inputChanged(String)
        case sendTapped
        case streamChunkReceived(String)
        case streamFinished
        case errorOccurred(LLMError)
        case persistenceFailed(String)
        case persistenceErrorDismissed
        case newConversationStarted(modelId: String)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.date) var date
        @Dependency(\.uuid) var uuid
        @Dependency(\.llmClient) var llmClient
        @Dependency(\.conversationStore) var conversationStore

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
            let conversationForDisk: Conversation = {
                var c = state.conversation
                c.messages = Array(c.messages.dropLast())
                return c
            }()
            let messagesForAPI = conversationForDisk.messages
            let model = LLMModel.resolve(id: state.conversation.modelId)
            return .run { send in
                await Self.save(conversationForDisk, using: conversationStore, send: send)
                do {
                    let stream = try await llmClient.streamMessage(messagesForAPI, model)
                    for try await chunk in stream {
                        await send(.streamChunkReceived(chunk))
                    }
                    await send(.streamFinished)
                } catch let error as LLMError {
                    await send(.errorOccurred(error))
                } catch {
                    await send(.errorOccurred(.network(error.localizedDescription)))
                }
            }

        case let .streamChunkReceived(chunk):
            guard let last = state.conversation.messages.last, last.role == .assistant else {
                return .none
            }
            let updated = Message(
                role: last.role,
                content: last.content + chunk,
                createdAt: last.createdAt
            )
            var newMessages = state.conversation.messages
            newMessages[newMessages.count - 1] = updated
            state.conversation.messages = newMessages
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
            // 스트리밍 중 실패면 trailing assistant(placeholder/부분응답) 제거 + 재저장.
            // 부분 응답 보존 X — "이게 진짜 답인가" 혼란 방지, 사용자는 재시도.
            let hadTrailingAssistant = state.conversation.messages.last?.role == .assistant
            if hadTrailingAssistant {
                state.conversation.messages.removeLast()
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
        }
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

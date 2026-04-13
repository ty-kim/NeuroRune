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

            let conversation = state.conversation
            let messagesForAPI = Array(conversation.messages.dropLast())
            let model = LLMModel.resolve(id: conversation.modelId)
            return .run { send in
                do {
                    try await conversationStore.save(conversation)
                } catch {
                    await send(.persistenceFailed(error.localizedDescription))
                }
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
                do {
                    try await conversationStore.save(conversation)
                } catch {
                    await send(.persistenceFailed(error.localizedDescription))
                }
            }

        case let .errorOccurred(llmError):
            state.error = llmError
            state.isStreaming = false
            return .none

        case let .persistenceFailed(message):
            state.persistenceError = message
            return .none

        case .persistenceErrorDismissed:
            state.persistenceError = nil
            return .none
        }
    }
}

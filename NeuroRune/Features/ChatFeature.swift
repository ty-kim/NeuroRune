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
        case messageReceived(Message)
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
            state.conversation = state.conversation.appending(userMessage)
            state.inputText = ""
            state.isStreaming = true
            state.error = nil

            let conversation = state.conversation
            let messages = conversation.messages
            let model = LLMModel.resolve(id: conversation.modelId)
            return .run { send in
                do {
                    try await conversationStore.save(conversation)
                } catch {
                    await send(.persistenceFailed(error.localizedDescription))
                }
                do {
                    let reply = try await llmClient.sendMessage(messages, model)
                    await send(.messageReceived(reply))
                } catch let error as LLMError {
                    await send(.errorOccurred(error))
                } catch {
                    await send(.errorOccurred(.network(error.localizedDescription)))
                }
            }

        case let .messageReceived(message):
            state.conversation = state.conversation.appending(message)
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

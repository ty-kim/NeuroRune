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
    }

    enum Action: Equatable {
        case inputChanged(String)
        case sendTapped
        case messageReceived(Message)
        case errorOccurred(LLMError)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.date) var date
        @Dependency(\.llmClient) var llmClient
        @Dependency(\.conversationStore) var conversationStore

        switch action {
        case let .inputChanged(text):
            state.inputText = text
            return .none

        case .sendTapped:
            guard !state.inputText.isEmpty else { return .none }
            let userMessage = Message(
                role: .user,
                content: state.inputText,
                createdAt: date.now
            )
            state.conversation = state.conversation.appending(userMessage)
            state.inputText = ""
            state.isStreaming = true

            let messages = state.conversation.messages
            let model = LLMModel(
                id: state.conversation.modelId,
                displayName: ""
            )
            return .run { send in
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
            return .run { _ in
                try? await conversationStore.save(conversation)
            }

        case let .errorOccurred(llmError):
            state.error = llmError
            state.isStreaming = false
            return .none
        }
    }
}

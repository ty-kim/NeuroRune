//
//  ChatFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

@MainActor
struct ChatFeatureTests {

    @Test("State는 conversation, inputText, isStreaming, error 필드를 가진다")
    func stateHasRequiredFields() {
        let conversation = Conversation.empty(modelId: "claude-opus-4-6")
        let state = ChatFeature.State(
            conversation: conversation,
            inputText: "",
            isStreaming: false,
            error: nil
        )

        #expect(state.conversation == conversation)
        #expect(state.inputText == "")
        #expect(state.isStreaming == false)
        #expect(state.error == nil)
    }

    @Test(".inputChanged는 inputText를 업데이트한다")
    func inputChangedUpdatesInputText() async {
        let store = TestStore(
            initialState: ChatFeature.State(
                conversation: Conversation.empty(modelId: "claude-opus-4-6"),
                inputText: "",
                isStreaming: false,
                error: nil
            )
        ) {
            ChatFeature()
        }

        await store.send(.inputChanged("hello")) {
            $0.inputText = "hello"
        }
    }

    @Test("sendTapped는 inputText가 비어있으면 아무 효과 없음")
    func sendTappedNoOpWhenEmpty() async {
        let store = TestStore(
            initialState: ChatFeature.State(
                conversation: Conversation.empty(modelId: "claude-opus-4-6"),
                inputText: "",
                isStreaming: false,
                error: nil
            )
        ) {
            ChatFeature()
        }

        await store.send(.sendTapped)
        // State 변화 없음, Effect 없음
    }

    @Test("sendTapped는 user Message 추가 + inputText 비움 + isStreaming=true + LLMClient.sendMessage 호출")
    func sendTappedTriggersLLMEffect() async {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let reply = Message(role: .assistant, content: "world", createdAt: fixedDate)
        let calledModelId = LockIsolated<String?>(nil)
        let calledMessagesCount = LockIsolated<Int?>(nil)

        let store = TestStore(
            initialState: ChatFeature.State(
                conversation: Conversation.empty(modelId: "claude-opus-4-6"),
                inputText: "hello",
                isStreaming: false,
                error: nil
            )
        ) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(fixedDate)
            $0.llmClient.sendMessage = { @Sendable messages, model in
                calledMessagesCount.setValue(messages.count)
                calledModelId.setValue(model.id)
                return reply
            }
            $0.conversationStore.save = { @Sendable _ in }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation.appending(
                Message(role: .user, content: "hello", createdAt: fixedDate)
            )
            $0.inputText = ""
            $0.isStreaming = true
        }

        await store.receive(.messageReceived(reply)) {
            $0.conversation = $0.conversation.appending(reply)
            $0.isStreaming = false
        }

        await store.finish()

        #expect(calledMessagesCount.value == 1)
        #expect(calledModelId.value == "claude-opus-4-6")
    }

    @Test("messageReceived는 assistant Message를 추가하고 isStreaming=false로 바꾼다")
    func messageReceivedAppendsAndClearsStreaming() async {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let reply = Message(role: .assistant, content: "world", createdAt: fixedDate)

        let store = TestStore(
            initialState: ChatFeature.State(
                conversation: Conversation.empty(modelId: "claude-opus-4-6"),
                inputText: "",
                isStreaming: true,
                error: nil
            )
        ) {
            ChatFeature()
        } withDependencies: {
            $0.conversationStore.save = { @Sendable _ in }
        }

        await store.send(.messageReceived(reply)) {
            $0.conversation = $0.conversation.appending(reply)
            $0.isStreaming = false
        }

        await store.finish()
    }

    @Test("errorOccurred는 error를 세팅하고 isStreaming=false로 바꾼다")
    func errorOccurredSetsErrorAndClearsStreaming() async {
        let store = TestStore(
            initialState: ChatFeature.State(
                conversation: Conversation.empty(modelId: "claude-opus-4-6"),
                inputText: "",
                isStreaming: true,
                error: nil
            )
        ) {
            ChatFeature()
        }

        await store.send(.errorOccurred(.unauthorized)) {
            $0.error = .unauthorized
            $0.isStreaming = false
        }
    }

    @Test("messageReceived 후 ConversationStore.save가 호출된다")
    func messageReceivedTriggersSave() async {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let reply = Message(role: .assistant, content: "world", createdAt: fixedDate)
        let savedMessagesCount = LockIsolated<Int?>(nil)
        let savedLastContent = LockIsolated<String?>(nil)

        let store = TestStore(
            initialState: ChatFeature.State(
                conversation: Conversation.empty(modelId: "claude-opus-4-6"),
                inputText: "",
                isStreaming: true,
                error: nil
            )
        ) {
            ChatFeature()
        } withDependencies: {
            $0.conversationStore.save = { @Sendable conversation in
                savedMessagesCount.setValue(conversation.messages.count)
                savedLastContent.setValue(conversation.messages.last?.content)
            }
        }

        await store.send(.messageReceived(reply)) {
            $0.conversation = $0.conversation.appending(reply)
            $0.isStreaming = false
        }

        await store.finish()

        #expect(savedMessagesCount.value == 1)
        #expect(savedLastContent.value == "world")
    }
}

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

    private static let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    private func makeState(
        inputText: String = "",
        isStreaming: Bool = false,
        error: LLMError? = nil
    ) -> ChatFeature.State {
        ChatFeature.State(
            conversation: Conversation.empty(modelId: LLMModel.opus46.id),
            inputText: inputText,
            isStreaming: isStreaming,
            error: error
        )
    }

    @Test("State는 conversation, inputText, isStreaming, error 필드를 가진다")
    func stateHasRequiredFields() {
        let state = makeState()

        #expect(state.conversation.modelId == LLMModel.opus46.id)
        #expect(state.conversation.messages.isEmpty)
        #expect(state.inputText == "")
        #expect(state.isStreaming == false)
        #expect(state.error == nil)
    }

    @Test(".inputChanged는 inputText를 업데이트한다")
    func inputChangedUpdatesInputText() async {
        let store = TestStore(initialState: makeState()) {
            ChatFeature()
        }

        await store.send(.inputChanged("hello")) {
            $0.inputText = "hello"
        }
    }

    @Test("sendTapped는 inputText가 비어있으면 아무 효과 없음")
    func sendTappedNoOpWhenEmpty() async {
        let store = TestStore(initialState: makeState()) {
            ChatFeature()
        }

        await store.send(.sendTapped)
    }

    @Test("sendTapped는 isStreaming 중이면 아무 효과 없음")
    func sendTappedNoOpWhileStreaming() async {
        let store = TestStore(initialState: makeState(inputText: "hello", isStreaming: true)) {
            ChatFeature()
        }

        await store.send(.sendTapped)
    }

    @Test("sendTapped는 user Message 추가 + inputText 비움 + isStreaming=true + LLMClient.sendMessage 호출")
    func sendTappedTriggersLLMEffect() async {
        let reply = Message(role: .assistant, content: "world", createdAt: Self.fixedDate)
        let calledModelId = LockIsolated<String?>(nil)
        let calledMessagesCount = LockIsolated<Int?>(nil)

        let store = TestStore(initialState: makeState(inputText: "hello")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.sendMessage = { @Sendable messages, model in
                calledMessagesCount.setValue(messages.count)
                calledModelId.setValue(model.id)
                return reply
            }
            $0.conversationStore.save = { @Sendable _ in }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation.appending(
                Message(role: .user, content: "hello", createdAt: Self.fixedDate)
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
        #expect(calledModelId.value == LLMModel.opus46.id)
    }

    @Test("messageReceived는 assistant Message를 추가하고 isStreaming=false로 바꾼다")
    func messageReceivedAppendsAndClearsStreaming() async {
        let reply = Message(role: .assistant, content: "world", createdAt: Self.fixedDate)

        let store = TestStore(initialState: makeState(isStreaming: true)) {
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
        let store = TestStore(initialState: makeState(isStreaming: true)) {
            ChatFeature()
        }

        await store.send(.errorOccurred(.unauthorized)) {
            $0.error = .unauthorized
            $0.isStreaming = false
        }
    }

    @Test("새 Conversation 시작 시 selectedModel.id가 conversation.modelId에 고정된다")
    func newConversationUsesSelectedModel() async {
        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let store = TestStore(initialState: makeState()) {
            ChatFeature()
        } withDependencies: {
            $0.uuid = .constant(fixedUUID)
            $0.date = .constant(Self.fixedDate)
        }

        await store.send(.newConversationStarted(modelId: LLMModel.haiku45.id)) {
            $0.conversation = Conversation(
                id: fixedUUID,
                title: "",
                messages: [],
                modelId: LLMModel.haiku45.id,
                createdAt: Self.fixedDate
            )
        }
    }

    @Test("messageReceived 후 ConversationStore.save가 호출된다")
    func messageReceivedTriggersSave() async {
        let reply = Message(role: .assistant, content: "world", createdAt: Self.fixedDate)
        let savedMessagesCount = LockIsolated<Int?>(nil)
        let savedLastContent = LockIsolated<String?>(nil)

        let store = TestStore(initialState: makeState(isStreaming: true)) {
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

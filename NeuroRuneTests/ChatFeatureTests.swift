//
//  ChatFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

private enum SaveTestError: LocalizedError {
    case failed
    var errorDescription: String? { "save failed" }
}

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

    @Test("sendTapped는 conversation.effort를 streamMessage로 전달한다")
    func sendTappedPassesEffort() async {
        let receivedEffort = LockIsolated<EffortLevel?>(nil)

        var state = makeState(inputText: "hi")
        state.conversation = Conversation(
            id: UUID(),
            title: "",
            messages: [],
            modelId: LLMModel.opus46.id,
            createdAt: Self.fixedDate,
            effort: .medium
        )

        let store = TestStore(initialState: state) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, effort in
                receivedEffort.setValue(effort)
                return AsyncThrowingStream { $0.finish() }
            }
            $0.conversationStore.save = { @Sendable _ in }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation
                .appending(Message(role: .user, content: "hi", createdAt: Self.fixedDate))
                .appending(Message(role: .assistant, content: "", createdAt: Self.fixedDate))
            $0.inputText = ""
            $0.isStreaming = true
        }

        await store.receive(.streamFinished) {
            $0.isStreaming = false
        }

        await store.finish()
        #expect(receivedEffort.value == .medium)
    }

    @Test("sendTapped는 isStreaming 중이면 아무 효과 없음")
    func sendTappedNoOpWhileStreaming() async {
        let store = TestStore(initialState: makeState(inputText: "hello", isStreaming: true)) {
            ChatFeature()
        }

        await store.send(.sendTapped)
    }

    @Test("sendTapped는 user/empty-assistant placeholder 추가 + isStreaming=true + streamMessage 호출")
    func sendTappedTriggersStream() async {
        let calledModelId = LockIsolated<String?>(nil)
        let calledMessagesCount = LockIsolated<Int?>(nil)

        let store = TestStore(initialState: makeState(inputText: "hello")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable messages, model, _ in
                calledMessagesCount.setValue(messages.count)
                calledModelId.setValue(model.id)
                return AsyncThrowingStream { continuation in
                    continuation.yield("world")
                    continuation.finish()
                }
            }
            $0.conversationStore.save = { @Sendable _ in }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation
                .appending(Message(role: .user, content: "hello", createdAt: Self.fixedDate))
                .appending(Message(role: .assistant, content: "", createdAt: Self.fixedDate))
            $0.inputText = ""
            $0.isStreaming = true
        }

        await store.receive(.streamChunkReceived("world")) {
            var msgs = $0.conversation.messages
            msgs[msgs.count - 1] = Message(role: .assistant, content: "world", createdAt: Self.fixedDate)
            $0.conversation.messages = msgs
        }

        await store.receive(.streamFinished) {
            $0.isStreaming = false
        }

        await store.finish()

        #expect(calledMessagesCount.value == 1) // user message only, placeholder excluded
        #expect(calledModelId.value == LLMModel.opus46.id)
    }

    @Test("streamChunkReceived는 마지막 assistant 메시지에 append한다")
    func streamChunkAppendsToLastAssistant() async {
        var state = makeState(isStreaming: true)
        state.conversation = state.conversation
            .appending(Message(role: .user, content: "hi", createdAt: Self.fixedDate))
            .appending(Message(role: .assistant, content: "partial ", createdAt: Self.fixedDate))

        let store = TestStore(initialState: state) {
            ChatFeature()
        }

        await store.send(.streamChunkReceived("done")) {
            var msgs = $0.conversation.messages
            msgs[msgs.count - 1] = Message(role: .assistant, content: "partial done", createdAt: Self.fixedDate)
            $0.conversation.messages = msgs
        }
    }

    @Test("streamFinished는 isStreaming=false + save 호출")
    func streamFinishedClearsStreamingAndSaves() async {
        let savedMessages = LockIsolated<Int?>(nil)

        let store = TestStore(initialState: makeState(isStreaming: true)) {
            ChatFeature()
        } withDependencies: {
            $0.conversationStore.save = { @Sendable conversation in
                savedMessages.setValue(conversation.messages.count)
            }
        }

        await store.send(.streamFinished) {
            $0.isStreaming = false
        }

        await store.finish()
        #expect(savedMessages.value == 0)
    }

    @Test("sendTapped 초기 save는 placeholder(빈 assistant)를 제외한다")
    func sendTappedInitialSaveExcludesPlaceholder() async {
        let allSaves = LockIsolated<[[Message]]>([])

        let store = TestStore(initialState: makeState(inputText: "hello")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield("resp")
                    continuation.finish()
                }
            }
            $0.conversationStore.save = { @Sendable conversation in
                allSaves.withValue { $0.append(conversation.messages) }
            }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation
                .appending(Message(role: .user, content: "hello", createdAt: Self.fixedDate))
                .appending(Message(role: .assistant, content: "", createdAt: Self.fixedDate))
            $0.inputText = ""
            $0.isStreaming = true
        }

        await store.receive(.streamChunkReceived("resp")) {
            var msgs = $0.conversation.messages
            msgs[msgs.count - 1] = Message(role: .assistant, content: "resp", createdAt: Self.fixedDate)
            $0.conversation.messages = msgs
        }

        await store.receive(.streamFinished) {
            $0.isStreaming = false
        }

        await store.finish()

        let saves = allSaves.value
        #expect(saves.count == 2)
        // 초기 save: [user]만, placeholder 없음
        #expect(saves[0].count == 1)
        #expect(saves[0].first?.role == .user)
        // streamFinished save: [user, assistant]
        #expect(saves[1].count == 2)
        #expect(saves[1].last?.content == "resp")
    }

    @Test("errorOccurred는 trailing assistant placeholder/부분응답 제거 + save 호출")
    func errorOccurredRemovesPlaceholderAndSaves() async {
        let savedMessages = LockIsolated<[Message]?>(nil)
        var state = makeState(isStreaming: true)
        state.conversation = state.conversation
            .appending(Message(role: .user, content: "hi", createdAt: Self.fixedDate))
            .appending(Message(role: .assistant, content: "partial", createdAt: Self.fixedDate))

        let store = TestStore(initialState: state) {
            ChatFeature()
        } withDependencies: {
            $0.conversationStore.save = { @Sendable conversation in
                savedMessages.setValue(conversation.messages)
            }
        }

        await store.send(.errorOccurred(.rateLimited)) {
            $0.error = .rateLimited
            $0.isStreaming = false
            $0.conversation.messages = [
                Message(role: .user, content: "hi", createdAt: Self.fixedDate)
            ]
        }

        await store.finish()

        #expect(savedMessages.value?.count == 1)
        #expect(savedMessages.value?.first?.role == .user)
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

    @Test("streamFinished 저장 실패 시 persistenceFailed가 발행된다")
    func saveFailureSurfacesPersistenceError() async {
        let store = TestStore(initialState: makeState(isStreaming: true)) {
            ChatFeature()
        } withDependencies: {
            $0.conversationStore.save = { @Sendable _ in
                throw SaveTestError.failed
            }
        }

        await store.send(.streamFinished) {
            $0.isStreaming = false
        }

        await store.receive(.persistenceFailed(SaveTestError.failed.localizedDescription)) {
            $0.persistenceError = SaveTestError.failed.localizedDescription
        }
    }

    @Test("persistenceErrorDismissed는 persistenceError를 nil로 만든다")
    func persistenceErrorDismissedClearsError() async {
        var state = makeState()
        state.persistenceError = "saved failed"

        let store = TestStore(initialState: state) {
            ChatFeature()
        }

        await store.send(.persistenceErrorDismissed) {
            $0.persistenceError = nil
        }
    }

    @Test("sendTapped 중 save 실패해도 stream 요청은 진행된다")
    func sendTappedContinuesStreamDespiteSaveFailure() async {
        let llmCalled = LockIsolated<Bool>(false)

        let store = TestStore(initialState: makeState(inputText: "hello")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, _ in
                llmCalled.setValue(true)
                return AsyncThrowingStream { continuation in
                    continuation.yield("ok")
                    continuation.finish()
                }
            }
            $0.conversationStore.save = { @Sendable _ in
                throw SaveTestError.failed
            }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation
                .appending(Message(role: .user, content: "hello", createdAt: Self.fixedDate))
                .appending(Message(role: .assistant, content: "", createdAt: Self.fixedDate))
            $0.inputText = ""
            $0.isStreaming = true
        }

        await store.receive(.persistenceFailed(SaveTestError.failed.localizedDescription)) {
            $0.persistenceError = SaveTestError.failed.localizedDescription
        }

        await store.receive(.streamChunkReceived("ok")) {
            var msgs = $0.conversation.messages
            msgs[msgs.count - 1] = Message(role: .assistant, content: "ok", createdAt: Self.fixedDate)
            $0.conversation.messages = msgs
        }

        await store.receive(.streamFinished) {
            $0.isStreaming = false
        }

        await store.receive(.persistenceFailed(SaveTestError.failed.localizedDescription))

        await store.finish()

        #expect(llmCalled.value == true)
    }

}

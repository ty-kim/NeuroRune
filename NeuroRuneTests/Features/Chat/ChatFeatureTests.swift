//
//  ChatFeatureTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

enum SaveTestError: LocalizedError {
    case failed
    var errorDescription: String? { "save failed" }
}

@MainActor
struct ChatFeatureTests {

    static let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    func makeState(
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
            $0.llmClient.streamMessage = { @Sendable _, _, effort, _, _ in
                receivedEffort.setValue(effort)
                return AsyncThrowingStream { $0.finish() }
            }
            $0.conversationStore.save = { @Sendable _ in }
            $0.githubCredentialsClient.load = { @Sendable _ in nil }
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

    @Test("sendTapped는 .global + .local MEMORY.md를 concat해 system으로 전달")
    func sendTappedConcatsBothMemoryFilesIntoSystem() async {
        let receivedSystem = LockIsolated<String?>(nil)
        let loadedPaths = LockIsolated<[String]>([])

        let store = TestStore(initialState: makeState(inputText: "hi")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, _, system, _ in
                receivedSystem.setValue(system)
                return AsyncThrowingStream { $0.finish() }
            }
            $0.githubClient.loadFile = { @Sendable _, path in
                loadedPaths.withValue { $0.append(path) }
                return GitHubFile(path: path, sha: "s", content: "body-of-\(path)", isDirectory: false)
            }
            $0.githubCredentialsClient.load = { @Sendable role in
                GitHubCredentials(role: role, pat: "p", owner: "o", repo: "r-\(role.rawValue)", path: "memory")
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
        let system = receivedSystem.value ?? ""
        #expect(system.contains("body-of-memory/MEMORY.md"))
        #expect(system.contains("## Global Memory"))
        #expect(system.contains("## Local Memory"))
        #expect(loadedPaths.value.sorted() == ["memory/MEMORY.md", "memory/MEMORY.md"])
    }

    @Test("sendTapped는 credentials가 없으면 system도 nil")
    func sendTappedPassesNilSystemWhenNoCredentials() async {
        let receivedSystem = LockIsolated<String?>("not-set")

        let store = TestStore(initialState: makeState(inputText: "hi")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, _, system, _ in
                receivedSystem.setValue(system)
                return AsyncThrowingStream { $0.finish() }
            }
            $0.githubCredentialsClient.load = { @Sendable _ in nil }
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
        #expect(receivedSystem.value == nil)
    }

    @Test("sendTapped는 한쪽 role의 MEMORY.md fetch가 notFound이면 그 섹션 제외")
    func sendTappedSkipsMissingMemoryFile() async {
        let receivedSystem = LockIsolated<String?>(nil)

        let store = TestStore(initialState: makeState(inputText: "hi")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, _, system, _ in
                receivedSystem.setValue(system)
                return AsyncThrowingStream { $0.finish() }
            }
            $0.githubClient.loadFile = { @Sendable config, path in
                if config.repo == "r-local" {
                    throw GitHubError.notFound
                }
                return GitHubFile(path: path, sha: "s", content: "global body", isDirectory: false)
            }
            $0.githubCredentialsClient.load = { @Sendable role in
                GitHubCredentials(role: role, pat: "p", owner: "o", repo: "r-\(role.rawValue)", path: "")
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
        let system = receivedSystem.value ?? ""
        #expect(system.contains("## Global Memory"))
        #expect(system.contains("global body"))
        #expect(!system.contains("## Local Memory"))
    }

    // NOTE: rateLimitUpdated 테스트는 `ChatFeatureTests+RateLimit.swift`로 이동.
    // NOTE: writeApproval/Rejected + toolUseRequested/Completed + 멀티턴은 `ChatFeatureTests+Tools.swift`로 이동.

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
            $0.llmClient.streamMessage = { @Sendable messages, model, _, _, _ in
                calledMessagesCount.setValue(messages.count)
                calledModelId.setValue(model.id)
                return AsyncThrowingStream { continuation in
                    continuation.yield(.textDelta("world"))
                    continuation.finish()
                }
            }
            $0.conversationStore.save = { @Sendable _ in }
            $0.githubCredentialsClient.load = { @Sendable _ in nil }
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
            $0.llmClient.streamMessage = { @Sendable _, _, _, _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(.textDelta("resp"))
                    continuation.finish()
                }
            }
            $0.conversationStore.save = { @Sendable conversation in
                allSaves.withValue { $0.append(conversation.messages) }
            }
            $0.githubCredentialsClient.load = { @Sendable _ in nil }
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

        await store.send(.errorOccurred(.rateLimited(retryAfter: nil, state: nil))) {
            $0.error = .rateLimited(retryAfter: nil, state: nil)
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

    @Test("errorOccurred는 activeToolCalls + pendingWrite도 초기화한다")
    func errorOccurredClearsToolStateAndPendingWrite() async {
        var state = makeState(isStreaming: true)
        state.activeToolCalls = [
            ChatFeature.ToolCallStatus(id: "t1", name: "read_memory", input: ["path": "x.md"])
        ]
        state.pendingWrite = ChatFeature.WriteRequest(
            id: "w1", role: .global, path: "p", content: "c", commitMessage: "m"
        )

        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.errorOccurred(.rateLimited(retryAfter: nil, state: nil))) {
            $0.error = .rateLimited(retryAfter: nil, state: nil)
            $0.isStreaming = false
            $0.activeToolCalls = []
            $0.pendingWrite = nil
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
            $0.llmClient.streamMessage = { @Sendable _, _, _, _, _ in
                llmCalled.setValue(true)
                return AsyncThrowingStream { continuation in
                    continuation.yield(.textDelta("ok"))
                    continuation.finish()
                }
            }
            $0.conversationStore.save = { @Sendable _ in
                throw SaveTestError.failed
            }
            $0.githubCredentialsClient.load = { @Sendable _ in nil }
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

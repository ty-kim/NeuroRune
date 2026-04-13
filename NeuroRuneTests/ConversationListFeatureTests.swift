//
//  ConversationListFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

@MainActor
struct ConversationListFeatureTests {

    private static let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    private static func sampleConversation(id: UUID = UUID(), title: String = "t") -> Conversation {
        Conversation(
            id: id,
            title: title,
            messages: [],
            modelId: LLMModel.opus46.id,
            createdAt: fixedDate
        )
    }

    @Test(".task는 loadAll 성공 시 conversationsLoaded를 발행한다")
    func taskLoadsConversationsOnSuccess() async {
        let conversations = [Self.sampleConversation(title: "a"), Self.sampleConversation(title: "b")]

        let store = TestStore(initialState: ConversationListFeature.State()) {
            ConversationListFeature()
        } withDependencies: {
            $0.conversationStore.loadAll = { @Sendable in conversations }
        }

        await store.send(.task)
        await store.receive(.conversationsLoaded(conversations)) {
            $0.conversations = conversations
            $0.isLoading = false
        }
    }

    @Test(".task는 loadAll 실패 시 loadFailed를 발행하고 listError를 세팅한다")
    func taskSetsErrorOnLoadFailure() async {
        let store = TestStore(initialState: ConversationListFeature.State()) {
            ConversationListFeature()
        } withDependencies: {
            $0.conversationStore.loadAll = { @Sendable in
                throw PersistenceError.containerUnavailable
            }
        }

        await store.send(.task)
        await store.receive(.loadFailed) {
            $0.isLoading = false
            $0.listError = String(localized: "list.loadFailed")
        }
    }

    @Test("deleteTapped 성공 시 conversations에서 제거된다")
    func deleteSucceededRemovesFromState() async {
        let id = UUID()
        let conversation = Self.sampleConversation(id: id)
        var state = ConversationListFeature.State()
        state.conversations = [conversation]
        state.isLoading = false

        let store = TestStore(initialState: state) {
            ConversationListFeature()
        } withDependencies: {
            $0.conversationStore.delete = { @Sendable _ in }
        }

        await store.send(.deleteTapped(conversation))
        await store.receive(.deleteSucceeded(id)) {
            $0.conversations = []
        }
    }

    @Test("deleteTapped 실패 시 listError가 세팅되고 conversations는 유지된다")
    func deleteFailureKeepsList() async {
        let conversation = Self.sampleConversation()
        var state = ConversationListFeature.State()
        state.conversations = [conversation]
        state.isLoading = false

        let store = TestStore(initialState: state) {
            ConversationListFeature()
        } withDependencies: {
            $0.conversationStore.delete = { @Sendable _ in
                throw PersistenceError.containerUnavailable
            }
        }

        await store.send(.deleteTapped(conversation))
        await store.receive(.deleteFailed) {
            $0.listError = String(localized: "list.deleteFailed")
        }
    }

    @Test("modelSelected는 thinkingEnabled && 모델 지원 시 Conversation에 thinking true 전달")
    func modelSelectedRespectsThinkingCapability() async {
        var state = ConversationListFeature.State()
        state.thinkingEnabled = true
        state.isLoading = false

        let store = TestStore(initialState: state) {
            ConversationListFeature()
        }

        // Conversation.empty 내부에서 UUID/Date 생성 → 정확한 equality 대신
        // thinkingEnabled / modelId만 검증.
        store.exhaustivity = .off
        await store.send(.modelSelected(.opus46))
        #expect(store.state.showModelPicker == false)
        #expect(store.state.selectedConversation?.modelId == LLMModel.opus46.id)
        #expect(store.state.selectedConversation?.thinkingEnabled == true)
    }

    @Test("modelSelected는 모델 미지원 시 thinking을 false로 강제")
    func modelSelectedForcesThinkingFalseForUnsupportedModel() async {
        var state = ConversationListFeature.State()
        state.thinkingEnabled = true
        state.isLoading = false

        let store = TestStore(initialState: state) {
            ConversationListFeature()
        }

        // Conversation.empty 내부에서 UUID/Date 생성이라 equality가 어려워짐.
        // 대신 thinkingEnabled만 검증하기 위해 non-exhaustive로.
        store.exhaustivity = .off
        await store.send(.modelSelected(.haiku45))
        #expect(store.state.selectedConversation?.thinkingEnabled == false)
    }

    @Test("thinkingToggled는 state.thinkingEnabled를 업데이트한다")
    func thinkingToggledUpdatesState() async {
        let store = TestStore(initialState: ConversationListFeature.State()) {
            ConversationListFeature()
        }

        await store.send(.thinkingToggled(true)) {
            $0.thinkingEnabled = true
        }
    }

    @Test("resetApiKeyTapped는 showResetConfirmation을 true로 바꾼다")
    func resetApiKeyTappedShowsConfirmation() async {
        let store = TestStore(initialState: ConversationListFeature.State()) {
            ConversationListFeature()
        }

        await store.send(.resetApiKeyTapped) {
            $0.showResetConfirmation = true
        }
    }

    @Test("resetApiKeyConfirmed는 Keychain delete를 호출한다")
    func resetApiKeyConfirmedDeletesKey() async {
        let deletedKey = LockIsolated<String?>(nil)
        var state = ConversationListFeature.State()
        state.showResetConfirmation = true

        let store = TestStore(initialState: state) {
            ConversationListFeature()
        } withDependencies: {
            $0.keychainClient.delete = { @Sendable key in
                deletedKey.setValue(key)
            }
        }

        await store.send(.resetApiKeyConfirmed) {
            $0.showResetConfirmation = false
        }
        await store.finish()

        #expect(deletedKey.value == OnboardingFeature.anthropicKeyName)
    }

    @Test("errorDismissed는 listError를 nil로 만든다")
    func errorDismissedClearsError() async {
        var state = ConversationListFeature.State()
        state.listError = "something"

        let store = TestStore(initialState: state) {
            ConversationListFeature()
        }

        await store.send(.errorDismissed) {
            $0.listError = nil
        }
    }
}

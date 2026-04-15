//
//  ConversationListFeature.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import ComposableArchitecture

nonisolated struct ConversationListFeature: Reducer {

    struct State: Equatable {
        var conversations: [Conversation] = []
        var isLoading: Bool = true
        var selectedConversation: Conversation?
        var showModelPicker: Bool = false
        var selectedEffort: EffortLevel? = nil
        var listError: String?
        var showMemoryList: Bool = false
        var showGroqCredentials: Bool = false
        var showOnboarding: Bool = false
    }

    enum Action: Equatable {
        case task
        case conversationsLoaded([Conversation])
        case loadFailed
        case deleteTapped(Conversation)
        case deleteSucceeded(UUID)
        case deleteFailed
        case conversationSelected(Conversation?)
        case newConversationTapped
        case modelPickerDismissed
        case modelSelected(LLMModel)
        case effortSelected(EffortLevel?)
        case memoryListTapped
        case memoryListDismissed
        case onboardingTapped
        case onboardingDismissed
        case groqCredentialsTapped
        case groqCredentialsDismissed
        case errorDismissed
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.conversationStore) var store
        @Dependency(\.keychainClient) var keychain

        switch action {
        case .task:
            return .run { send in
                do {
                    let loaded = try await store.loadAll()
                    await send(.conversationsLoaded(loaded))
                } catch {
                    await send(.loadFailed)
                }
            }

        case let .conversationsLoaded(conversations):
            state.conversations = conversations
            state.isLoading = false
            return .none

        case .loadFailed:
            state.isLoading = false
            state.listError = String(localized: "list.loadFailed")
            return .none

        case let .deleteTapped(conversation):
            let id = conversation.id
            return .run { send in
                do {
                    try await store.delete(id)
                    await send(.deleteSucceeded(id))
                } catch {
                    await send(.deleteFailed)
                }
            }

        case let .deleteSucceeded(id):
            state.conversations.removeAll { $0.id == id }
            return .none

        case .deleteFailed:
            state.listError = String(localized: "list.deleteFailed")
            return .none

        case let .conversationSelected(conversation):
            state.selectedConversation = conversation
            // ChatView에서 pop으로 돌아오면 (nil) 목록을 다시 로드.
            // 그 사이 새 메시지가 저장됐을 수 있음.
            if conversation == nil {
                return .run { send in
                    do {
                        let loaded = try await store.loadAll()
                        await send(.conversationsLoaded(loaded))
                    } catch {
                        await send(.loadFailed)
                    }
                }
            }
            return .none

        case .newConversationTapped:
            // Anthropic 키 없으면 Onboarding sheet, 있으면 모델 피커.
            let hasKey = (try? keychain.load(OnboardingFeature.anthropicKeyName)) != nil
            if hasKey {
                state.showModelPicker = true
            } else {
                state.showOnboarding = true
            }
            return .none

        case .modelPickerDismissed:
            state.showModelPicker = false
            return .none

        case let .modelSelected(model):
            state.showModelPicker = false
            let effort = model.supportsEffort ? state.selectedEffort : nil
            state.selectedConversation = Conversation.empty(
                modelId: model.id,
                effort: effort
            )
            return .none

        case let .effortSelected(effort):
            state.selectedEffort = effort
            return .none

        case .memoryListTapped:
            state.showMemoryList = true
            return .none

        case .memoryListDismissed:
            state.showMemoryList = false
            return .none

        case .onboardingTapped:
            state.showOnboarding = true
            return .none

        case .onboardingDismissed:
            state.showOnboarding = false
            return .none

        case .groqCredentialsTapped:
            state.showGroqCredentials = true
            return .none

        case .groqCredentialsDismissed:
            state.showGroqCredentials = false
            return .none

        case .errorDismissed:
            state.listError = nil
            return .none
        }
    }
}

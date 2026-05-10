//
//  AnthropicCredentialsFeature.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import ComposableArchitecture

nonisolated struct AnthropicCredentialsFeature: Reducer {

    struct State: Equatable {
        var apiKey: String = ""
        var isSaving: Bool = false
        var error: String?

        var isValid: Bool {
            apiKey.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("sk-ant-")
        }
    }

    enum Action: Equatable {
        case apiKeyChanged(String)
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
        case clearTapped
        case cleared
        case loadExisting
        case existingLoaded(String?)
    }

    nonisolated static let anthropicKeyName = "anthropic_api_key"

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.keychainClient) var keychain

            switch action {
            case let .apiKeyChanged(value):
                state.apiKey = value
                state.error = nil
                return .none

            case .saveTapped:
                guard state.isValid else { return .none }
                state.isSaving = true
                state.error = nil
                let apiKey = state.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                return .run { send in
                    do {
                        try keychain.save(Self.anthropicKeyName, apiKey)
                        await send(.saveSucceeded)
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .saveSucceeded:
                state.isSaving = false
                state.error = nil
                state.apiKey = ""
                return .none

            case let .saveFailed(message):
                state.isSaving = false
                state.error = message
                return .none

            case .clearTapped:
                return .run { send in
                    try? keychain.delete(Self.anthropicKeyName)
                    await send(.cleared)
                }

            case .cleared:
                state.apiKey = ""
                return .none

            case .loadExisting:
                return .run { send in
                    let existing = try? keychain.load(Self.anthropicKeyName)
                    await send(.existingLoaded(existing))
                }

            case let .existingLoaded(value):
                if let value {
                    state.apiKey = value
                }
                return .none
            }
        }
    }
}

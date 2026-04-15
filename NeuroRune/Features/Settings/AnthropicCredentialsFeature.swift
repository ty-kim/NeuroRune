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
        var apiKeyInput: String = ""
        var error: String?
        var isSaving: Bool = false

        var isValid: Bool {
            apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("sk-ant-")
        }
    }

    enum Action: Equatable {
        case apiKeyChanged(String)
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
    }

    nonisolated static let anthropicKeyName = "anthropic_api_key"

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .apiKeyChanged(value):
            state.apiKeyInput = value
            state.error = nil
            return .none

        case .saveTapped:
            guard state.isValid else {
                return .none
            }
            state.isSaving = true
            state.error = nil
            let apiKey = state.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            @Dependency(\.keychainClient) var keychainClient
            let client = keychainClient
            return .run { send in
                do {
                    try client.save(Self.anthropicKeyName, apiKey)
                    await send(.saveSucceeded)
                } catch {
                    await send(.saveFailed(error.localizedDescription))
                }
            }

        case .saveSucceeded:
            state.isSaving = false
            state.error = nil
            state.apiKeyInput = ""
            return .none

        case let .saveFailed(message):
            state.isSaving = false
            state.error = message
            return .none
        }
    }
}

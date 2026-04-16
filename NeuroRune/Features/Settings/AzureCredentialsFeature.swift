//
//  AzureCredentialsFeature.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — Azure Speech Service 자격 증명 입력/저장.
//

import Foundation
import ComposableArchitecture

nonisolated struct AzureCredentialsFeature: Reducer {

    struct State: Equatable {
        var apiKey: String = ""
        var region: String = ""
        var isSaving: Bool = false
        var error: String?

        var isValid: Bool {
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: Equatable {
        case apiKeyChanged(String)
        case regionChanged(String)
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
        case clearTapped
        case cleared
        case loadExisting
        case existingLoaded(AzureCredentials?)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.azureCredentialsClient) var client

        switch action {
        case let .apiKeyChanged(v):
            state.apiKey = v
            state.error = nil
            return .none

        case let .regionChanged(v):
            state.region = v
            state.error = nil
            return .none

        case .saveTapped:
            guard state.isValid else { return .none }
            state.isSaving = true
            state.error = nil
            let creds = AzureCredentials(
                apiKey: state.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                region: state.region.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            return .run { send in
                do {
                    try client.save(creds)
                    await send(.saveSucceeded)
                } catch {
                    await send(.saveFailed(error.localizedDescription))
                }
            }

        case .saveSucceeded:
            state.isSaving = false
            state.apiKey = ""
            return .none

        case let .saveFailed(message):
            state.isSaving = false
            state.error = message
            return .none

        case .clearTapped:
            return .run { send in
                try? client.clear()
                await send(.cleared)
            }

        case .cleared:
            state.apiKey = ""
            state.region = ""
            return .none

        case .loadExisting:
            return .run { send in
                let creds = try? client.load()
                await send(.existingLoaded(creds))
            }

        case let .existingLoaded(creds):
            if let creds {
                state.apiKey = creds.apiKey
                state.region = creds.region
            }
            return .none
        }
    }
}

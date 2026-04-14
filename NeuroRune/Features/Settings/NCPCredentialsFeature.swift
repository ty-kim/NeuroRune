//
//  NCPCredentialsFeature.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — Naver Cloud Platform API 자격 증명 입력/저장.
//  GitHubCredentialsFeature 패턴을 따름.
//

import Foundation
import ComposableArchitecture

nonisolated struct NCPCredentialsFeature: Reducer {

    struct State: Equatable {
        var apiKeyID: String = ""
        var apiKey: String = ""
        var isSaving: Bool = false
        var error: String?

        var isValid: Bool {
            !apiKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: Equatable {
        case apiKeyIDChanged(String)
        case apiKeyChanged(String)
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
        case clearTapped
        case cleared
        case loadExisting
        case existingLoaded(NCPCredentials?)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.ncpCredentialsClient) var client

        switch action {
        case let .apiKeyIDChanged(v):
            state.apiKeyID = v
            state.error = nil
            return .none

        case let .apiKeyChanged(v):
            state.apiKey = v
            state.error = nil
            return .none

        case .saveTapped:
            guard state.isValid else { return .none }
            state.isSaving = true
            state.error = nil
            let creds = NCPCredentials(
                apiKeyID: state.apiKeyID.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: state.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
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
            state.apiKeyID = ""
            state.apiKey = ""
            return .none

        case .loadExisting:
            return .run { send in
                let creds = try? client.load()
                await send(.existingLoaded(creds ?? nil))
            }

        case let .existingLoaded(creds):
            if let creds {
                state.apiKeyID = creds.apiKeyID
                state.apiKey = creds.apiKey
            }
            return .none
        }
    }
}

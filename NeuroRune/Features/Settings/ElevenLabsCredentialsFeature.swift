//
//  ElevenLabsCredentialsFeature.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs TTS 자격 증명 입력/저장. 단일 apiKey 필드.
//

import Foundation
import ComposableArchitecture

nonisolated struct ElevenLabsCredentialsFeature: Reducer {

    struct State: Equatable {
        var apiKey: String = ""
        var isSaving: Bool = false
        var error: String?

        var isValid: Bool {
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        case existingLoaded(ElevenLabsCredentials?)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.elevenLabsCredentialsClient) var client

        switch action {
        case let .apiKeyChanged(v):
            state.apiKey = v
            state.error = nil
            return .none

        case .saveTapped:
            guard state.isValid else { return .none }
            state.isSaving = true
            state.error = nil
            let creds = ElevenLabsCredentials(
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
            state.apiKey = ""
            return .none

        case .loadExisting:
            return .run { send in
                let creds = try? client.load()
                await send(.existingLoaded(creds))
            }

        case let .existingLoaded(creds):
            if let creds {
                state.apiKey = creds.apiKey
            }
            return .none
        }
    }
}

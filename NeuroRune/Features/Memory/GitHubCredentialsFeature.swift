//
//  GitHubCredentialsFeature.swift
//  NeuroRune
//

import Foundation
import ComposableArchitecture

nonisolated struct GitHubCredentialsFeature: Reducer {

    struct State: Equatable {
        var pat: String = ""
        var owner: String = ""
        var repo: String = ""
        var branch: String = "main"
        var path: String = ""
        var isSaving: Bool = false
        var error: String?

        var isValid: Bool {
            !pat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: Equatable {
        case patChanged(String)
        case ownerChanged(String)
        case repoChanged(String)
        case branchChanged(String)
        case pathChanged(String)
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
        case loadExisting
        case existingLoaded(GitHubCredentials?)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.githubCredentialsClient) var client

        switch action {
        case let .patChanged(v):
            state.pat = v
            state.error = nil
            return .none
        case let .ownerChanged(v):
            state.owner = v
            state.error = nil
            return .none
        case let .repoChanged(v):
            state.repo = v
            state.error = nil
            return .none
        case let .branchChanged(v):
            state.branch = v
            state.error = nil
            return .none

        case let .pathChanged(v):
            state.path = v
            state.error = nil
            return .none

        case .saveTapped:
            guard state.isValid else { return .none }
            state.isSaving = true
            state.error = nil
            let creds = GitHubCredentials(
                pat: state.pat.trimmingCharacters(in: .whitespacesAndNewlines),
                owner: state.owner.trimmingCharacters(in: .whitespacesAndNewlines),
                repo: state.repo.trimmingCharacters(in: .whitespacesAndNewlines),
                branch: state.branch.trimmingCharacters(in: .whitespacesAndNewlines),
                path: state.path.trimmingCharacters(in: .whitespacesAndNewlines)
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
            state.pat = ""
            return .none

        case let .saveFailed(message):
            state.isSaving = false
            state.error = message
            return .none

        case .loadExisting:
            return .run { send in
                let creds = try? client.load(.global)
                await send(.existingLoaded(creds ?? nil))
            }

        case let .existingLoaded(creds):
            if let creds {
                state.pat = creds.pat
                state.owner = creds.owner
                state.repo = creds.repo
                state.branch = creds.branch
                state.path = creds.path
            }
            return .none
        }
    }
}

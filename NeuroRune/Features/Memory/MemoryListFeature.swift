//
//  MemoryListFeature.swift
//  NeuroRune
//

import Foundation
import ComposableArchitecture

nonisolated struct MemoryListFeature: Reducer {

    struct State: Equatable {
        var files: [GitHubFile] = []
        var isLoading: Bool = true
        var listError: String?
        var selectedFile: GitHubFile?
        /// credentials 미설정 시 true. UI에서 설정 화면 유도.
        var credentialsMissing: Bool = false
        var basePath: String = "memory"
        var config: GitHubRepoConfig?
    }

    enum Action: Equatable {
        case task
        case filesLoaded([GitHubFile])
        case loadFailed(String)
        case credentialsMissing
        case fileSelected(GitHubFile?)
        case deleteTapped(GitHubFile)
        case deleteSucceeded(String /* path */)
        case deleteFailed(String)
        case refresh
        case errorDismissed
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.githubClient) var github
        @Dependency(\.githubCredentialsClient) var creds

        switch action {
        case .task, .refresh:
            state.isLoading = true
            let basePath = state.basePath
            return .run { send in
                guard let loaded = try? creds.load() else {
                    await send(.credentialsMissing)
                    return
                }
                guard let loaded else {
                    await send(.credentialsMissing)
                    return
                }
                let config = loaded.repoConfig
                do {
                    let files = try await github.listContents(config, basePath)
                    await send(.filesLoaded(files))
                } catch let error as GitHubError {
                    await send(.loadFailed(errorMessage(for: error)))
                } catch {
                    await send(.loadFailed(error.localizedDescription))
                }
            }

        case let .filesLoaded(files):
            state.files = files.filter { !$0.isDirectory }
            state.isLoading = false
            state.credentialsMissing = false
            state.config = loadConfig(creds: creds)
            return .none

        case let .loadFailed(message):
            state.isLoading = false
            state.listError = message
            return .none

        case .credentialsMissing:
            state.isLoading = false
            state.credentialsMissing = true
            state.files = []
            return .none

        case let .fileSelected(file):
            state.selectedFile = file
            return .none

        case let .deleteTapped(file):
            guard let creds = try? creds.load(), let creds else {
                return .send(.credentialsMissing)
            }
            let config = creds.repoConfig
            let path = file.path
            let sha = file.sha
            return .run { send in
                do {
                    try await github.deleteFile(config, path, sha, "Delete \(path)")
                    await send(.deleteSucceeded(path))
                } catch let error as GitHubError {
                    await send(.deleteFailed(errorMessage(for: error)))
                } catch {
                    await send(.deleteFailed(error.localizedDescription))
                }
            }

        case let .deleteSucceeded(path):
            state.files.removeAll { $0.path == path }
            return .none

        case let .deleteFailed(message):
            state.listError = message
            return .none

        case .errorDismissed:
            state.listError = nil
            return .none
        }
    }

    private func loadConfig(creds: GitHubCredentialsClient) -> GitHubRepoConfig? {
        (try? creds.load())??.repoConfig
    }

    private func errorMessage(for error: GitHubError) -> String {
        switch error {
        case .unauthorized: return String(localized: "memory.error.unauthorized")
        case .notFound: return String(localized: "memory.error.notFound")
        case .rateLimited: return String(localized: "memory.error.rateLimited")
        case .conflict: return String(localized: "memory.error.conflict")
        case let .server(_, message): return message
        case let .network(message): return message
        case let .decoding(message): return message
        }
    }
}

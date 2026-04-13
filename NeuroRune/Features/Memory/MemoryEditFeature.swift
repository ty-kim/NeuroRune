//
//  MemoryEditFeature.swift
//  NeuroRune
//

import Foundation
import ComposableArchitecture

nonisolated struct MemoryEditFeature: Reducer {

    struct State: Equatable {
        /// 편집 대상 파일 메타데이터. sha는 저장 성공 시 갱신됨.
        var file: GitHubFile
        var content: String = ""
        var isLoading: Bool = true
        var isSaving: Bool = false
        var error: String?
        var hasUnsavedChanges: Bool = false

        init(file: GitHubFile) {
            self.file = file
        }
    }

    enum Action: Equatable {
        case task
        case contentLoaded(content: String, sha: String)
        case loadFailed(String)
        case contentChanged(String)
        case saveTapped
        case saveSucceeded(GitHubFile)
        case saveFailed(String)
        case errorDismissed
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.githubClient) var github
        @Dependency(\.githubCredentialsClient) var credsClient

        switch action {
        case .task:
            state.isLoading = true
            let path = state.file.path
            return .run { send in
                let loaded = (try? credsClient.load()) ?? nil
                guard let loaded else {
                    await send(.loadFailed(String(localized: "memory.error.unauthorized")))
                    return
                }
                do {
                    let file = try await github.loadFile(loaded.repoConfig, path)
                    await send(.contentLoaded(content: file.content, sha: file.sha))
                } catch let error as GitHubError {
                    await send(.loadFailed(errorMessage(for: error)))
                } catch {
                    await send(.loadFailed(error.localizedDescription))
                }
            }

        case let .contentLoaded(content, sha):
            state.content = content
            state.file = GitHubFile(
                path: state.file.path,
                sha: sha,
                content: content,
                isDirectory: false
            )
            state.isLoading = false
            state.hasUnsavedChanges = false
            return .none

        case let .loadFailed(message):
            state.isLoading = false
            state.error = message
            return .none

        case let .contentChanged(content):
            state.content = content
            state.hasUnsavedChanges = content != state.file.content
            return .none

        case .saveTapped:
            guard state.hasUnsavedChanges, !state.isSaving else { return .none }
            state.isSaving = true
            state.error = nil
            let path = state.file.path
            let sha = state.file.sha
            let content = state.content
            let message = "Update \(URL(fileURLWithPath: path).lastPathComponent)"
            return .run { send in
                let loaded = (try? credsClient.load()) ?? nil
                guard let loaded else {
                    await send(.saveFailed(String(localized: "memory.error.unauthorized")))
                    return
                }
                do {
                    let saved = try await github.saveFile(loaded.repoConfig, path, content, sha, message)
                    await send(.saveSucceeded(saved))
                } catch let error as GitHubError {
                    await send(.saveFailed(errorMessage(for: error)))
                } catch {
                    await send(.saveFailed(error.localizedDescription))
                }
            }

        case let .saveSucceeded(file):
            state.isSaving = false
            state.file = file
            state.hasUnsavedChanges = false
            return .none

        case let .saveFailed(message):
            state.isSaving = false
            state.error = message
            return .none

        case .errorDismissed:
            state.error = nil
            return .none
        }
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

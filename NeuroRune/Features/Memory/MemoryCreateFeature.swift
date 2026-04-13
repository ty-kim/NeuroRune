//
//  MemoryCreateFeature.swift
//  NeuroRune
//

import Foundation
import ComposableArchitecture

nonisolated struct MemoryCreateFeature: Reducer {

    struct State: Equatable {
        /// creds.path — repo 안 메모리 디렉터리. 빈 문자열이면 repo 루트.
        var basePath: String = ""
        var filename: String = ""
        var content: String = ""
        var isSaving: Bool = false
        var error: String?
        /// 저장 성공 시 parent에게 전달할 새 파일. View가 onChange로 감지해 sheet dismiss.
        var createdFile: GitHubFile?

        var isValid: Bool {
            !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var fullPath: String {
            let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
            let withExt = trimmed.hasSuffix(".md") ? trimmed : "\(trimmed).md"
            return basePath.isEmpty ? withExt : "\(basePath)/\(withExt)"
        }
    }

    enum Action: Equatable {
        case filenameChanged(String)
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
        case let .filenameChanged(v):
            state.filename = v
            state.error = nil
            return .none

        case let .contentChanged(v):
            state.content = v
            state.error = nil
            return .none

        case .saveTapped:
            guard state.isValid, !state.isSaving else { return .none }
            state.isSaving = true
            state.error = nil
            let path = state.fullPath
            let content = state.content
            let message = "Create \(URL(fileURLWithPath: path).lastPathComponent)"
            return .run { send in
                let loaded = (try? credsClient.load()) ?? nil
                guard let loaded else {
                    await send(.saveFailed(String(localized: "memory.error.unauthorized")))
                    return
                }
                do {
                    let file = try await github.saveFile(loaded.repoConfig, path, content, nil, message)
                    await send(.saveSucceeded(file))
                } catch let error as GitHubError {
                    await send(.saveFailed(errorMessage(for: error)))
                } catch {
                    await send(.saveFailed(error.localizedDescription))
                }
            }

        case let .saveSucceeded(file):
            state.isSaving = false
            state.createdFile = file
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

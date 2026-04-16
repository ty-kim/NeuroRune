//
//  MemoryCreateFeature.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import ComposableArchitecture

nonisolated struct MemoryCreateFeature: Reducer {

    struct State: Equatable {
        var role: CredentialsRole = .global
        /// creds.path — repo 안 메모리 디렉터리. 빈 문자열이면 repo 루트.
        var basePath: String = ""
        var filename: String = ""
        var content: String = ""
        var isSaving: Bool = false
        var error: String?
        /// 저장 성공 시 parent에게 전달할 새 파일. View가 onChange로 감지해 sheet dismiss.
        var createdFile: GitHubFile?

        var isValid: Bool {
            let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            // 단일 파일만 허용. 디렉터리 traversal/escape/숨김파일 차단.
            // basePath는 credentials에서 설정 (별도 위치).
            let invalid = CharacterSet(charactersIn: "/\\")
                .union(.controlCharacters)
            guard trimmed.rangeOfCharacter(from: invalid) == nil else { return false }
            guard !trimmed.hasPrefix(".") else { return false }
            guard !trimmed.contains("..") else { return false }
            return true
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
            let role = state.role
            let message = "Create \(URL(fileURLWithPath: path).lastPathComponent)"
            return .run { send in
                guard credsClient.loadIgnoringError(role: role) != nil else {
                    await send(.saveFailed(String(localized: "memory.error.unauthorized")))
                    return
                }
                do {
                    let file = try await github.saveFile(role, path, content, nil, message)
                    await send(.saveSucceeded(file))
                } catch let error as GitHubError {
                    await send(.saveFailed(error.localizedMessage))
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

}

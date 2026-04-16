//
//  MemoryListFeature.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import ComposableArchitecture

nonisolated struct MemoryListFeature: Reducer {

    struct State: Equatable {
        var role: CredentialsRole = .global
        var files: [GitHubFile] = []
        var isLoading: Bool = true
        var listError: String?
        var selectedFile: GitHubFile?
        /// credentials 미설정 시 true. UI에서 설정 화면 유도.
        var credentialsMissing: Bool = false
        var config: GitHubRepoConfig?
        /// 새 파일 생성 시 사용할 repo 내 디렉터리 경로. 로드 성공 시 채워짐.
        var basePath: String = ""
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
        case fileAdded(GitHubFile)
        case refresh
        case errorDismissed
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.githubClient) var github
        @Dependency(\.githubCredentialsClient) var creds

        switch action {
        case .task, .refresh:
            state.isLoading = true
            let role = state.role
            return .run { send in
                guard let loaded = creds.loadIgnoringError(role: role) else {
                    await send(.credentialsMissing)
                    return
                }
                let path = loaded.path
                do {
                    let files = try await github.listContents(role, path)
                    await send(.filesLoaded(files))
                } catch GitHubError.notFound {
                    // 서브디렉터리 404 = 아직 비어있음으로 해석.
                    // repo 루트(path="")조차 404면 repo 설정 문제 → 명시적 에러.
                    if path.isEmpty {
                        await send(.loadFailed(GitHubError.notFound.localizedMessage))
                    } else {
                        await send(.filesLoaded([]))
                    }
                } catch let error as GitHubError {
                    await send(.loadFailed(error.localizedMessage))
                } catch {
                    await send(.loadFailed(error.localizedDescription))
                }
            }

        case let .filesLoaded(files):
            state.files = files
                .filter { !$0.isDirectory }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            state.isLoading = false
            state.credentialsMissing = false
            let loaded = creds.loadIgnoringError(role: state.role)
            state.config = loaded?.repoConfig
            state.basePath = loaded?.path ?? ""
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
            let role = state.role
            guard creds.loadIgnoringError(role: role) != nil else {
                return .send(.credentialsMissing)
            }
            let path = file.path
            let sha = file.sha
            return .run { send in
                do {
                    try await github.deleteFile(role, path, sha, "Delete \(path)")
                    await send(.deleteSucceeded(path))
                } catch GitHubError.notFound {
                    // 서버에 이미 없음 = 사실상 삭제 상태. 로컬도 정리.
                    await send(.deleteSucceeded(path))
                } catch let error as GitHubError {
                    await send(.deleteFailed(error.localizedMessage))
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

        case let .fileAdded(file):
            // 중복 방지: 같은 path 이미 있으면 교체, 없으면 추가. 이름순 정렬 유지.
            var updated = state.files.filter { $0.path != file.path }
            updated.append(file)
            state.files = updated
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return .none

        case .errorDismissed:
            state.listError = nil
            return .none
        }
    }

}

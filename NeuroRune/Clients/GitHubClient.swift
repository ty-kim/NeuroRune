//
//  GitHubClient.swift
//  NeuroRune
//

import Foundation
import Dependencies

nonisolated struct GitHubClient: Sendable {
    /// 디렉터리 경로에 있는 파일/서브디렉터리 목록.
    var listContents: @Sendable (GitHubRepoConfig, String) async throws -> [GitHubFile]
    /// 단일 파일 내용(Base64 디코딩).
    var loadFile: @Sendable (GitHubRepoConfig, String) async throws -> GitHubFile
    /// 파일 생성 또는 업데이트. 기존 파일이면 sha 필요, 신규면 sha=nil.
    /// 성공 시 갱신된 sha 포함 GitHubFile 반환.
    var saveFile: @Sendable (GitHubRepoConfig, _ path: String, _ content: String, _ sha: String?, _ message: String) async throws -> GitHubFile
    /// 파일 삭제. sha 필수.
    var deleteFile: @Sendable (GitHubRepoConfig, _ path: String, _ sha: String, _ message: String) async throws -> Void
}

nonisolated extension GitHubClient: DependencyKey {
    /// liveValue는 호출 시점에 .global credentials의 PAT를 로드한다.
    /// .local role을 쓰려는 호출부는 `GitHubClient.live(session:pat:)`를 직접 구성.
    static let liveValue: GitHubClient = {
        let credsClient = GitHubCredentialsClient.liveValue
        return GitHubClient(
            listContents: { config, path in
                let pat = try loadPAT(credsClient)
                return try await GitHubClient.live(session: .shared, pat: pat).listContents(config, path)
            },
            loadFile: { config, path in
                let pat = try loadPAT(credsClient)
                return try await GitHubClient.live(session: .shared, pat: pat).loadFile(config, path)
            },
            saveFile: { config, path, content, sha, message in
                let pat = try loadPAT(credsClient)
                return try await GitHubClient.live(session: .shared, pat: pat).saveFile(config, path, content, sha, message)
            },
            deleteFile: { config, path, sha, message in
                let pat = try loadPAT(credsClient)
                try await GitHubClient.live(session: .shared, pat: pat).deleteFile(config, path, sha, message)
            }
        )
    }()

    private static func loadPAT(_ credsClient: GitHubCredentialsClient) throws -> String {
        guard let creds = try credsClient.load(.global) else {
            throw GitHubError.unauthorized
        }
        return creds.pat
    }

    static let testValue = GitHubClient(
        listContents: unimplemented("GitHubClient.listContents"),
        loadFile: unimplemented("GitHubClient.loadFile"),
        saveFile: unimplemented("GitHubClient.saveFile"),
        deleteFile: unimplemented("GitHubClient.deleteFile")
    )

    static let previewValue = GitHubClient(
        listContents: { _, _ in
            [
                GitHubFile(path: "memory/user_profile.md", sha: "abc", content: "", isDirectory: false),
                GitHubFile(path: "memory/project_neurorune.md", sha: "def", content: "", isDirectory: false),
            ]
        },
        loadFile: { _, path in
            GitHubFile(path: path, sha: "preview-sha", content: "# Preview\n\nSample content.", isDirectory: false)
        },
        saveFile: { _, path, content, _, _ in
            GitHubFile(path: path, sha: "preview-new-sha", content: content, isDirectory: false)
        },
        deleteFile: { _, _, _, _ in }
    )
}

extension DependencyValues {
    nonisolated var githubClient: GitHubClient {
        get { self[GitHubClient.self] }
        set { self[GitHubClient.self] = newValue }
    }
}

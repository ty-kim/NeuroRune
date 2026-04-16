//
//  GitHubClient.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import Dependencies

nonisolated struct GitHubClient: Sendable {
    /// 디렉터리 경로에 있는 파일/서브디렉터리 목록.
    var listContents: @Sendable (CredentialsRole, String) async throws -> [GitHubFile]
    /// 단일 파일 내용(Base64 디코딩).
    var loadFile: @Sendable (CredentialsRole, String) async throws -> GitHubFile
    /// 파일 생성 또는 업데이트. 기존 파일이면 sha 필요, 신규면 sha=nil.
    /// 성공 시 갱신된 sha 포함 GitHubFile 반환.
    var saveFile: @Sendable (
        CredentialsRole, _ path: String, _ content: String, _ sha: String?, _ message: String
    ) async throws -> GitHubFile
    /// 파일 삭제. sha 필수.
    var deleteFile: @Sendable (CredentialsRole, _ path: String, _ sha: String, _ message: String) async throws -> Void
}

nonisolated extension GitHubClient: DependencyKey {
    /// liveValue는 호출 시 `role`에 해당하는 credentials(PAT + repoConfig)를 로드해
    /// 내부 `GitHubClient.live(session:pat:config:)`에 위임한다.
    /// role별 PAT와 repoConfig 쌍이 반드시 일치하도록 보장.
    static let liveValue: GitHubClient = {
        let credsClient = GitHubCredentialsClient.liveValue
        return GitHubClient(
            listContents: { role, path in
                let creds = try loadCreds(credsClient, role: role)
                return try await live(session: .shared, pat: creds.pat, config: creds.repoConfig)
                    .listContents(role, path)
            },
            loadFile: { role, path in
                let creds = try loadCreds(credsClient, role: role)
                return try await live(session: .shared, pat: creds.pat, config: creds.repoConfig)
                    .loadFile(role, path)
            },
            saveFile: { role, path, content, sha, message in
                let creds = try loadCreds(credsClient, role: role)
                return try await live(session: .shared, pat: creds.pat, config: creds.repoConfig)
                    .saveFile(role, path, content, sha, message)
            },
            deleteFile: { role, path, sha, message in
                let creds = try loadCreds(credsClient, role: role)
                try await live(session: .shared, pat: creds.pat, config: creds.repoConfig)
                    .deleteFile(role, path, sha, message)
            }
        )
    }()

    private static func loadCreds(_ credsClient: GitHubCredentialsClient, role: CredentialsRole) throws -> GitHubCredentials {
        guard let creds = try credsClient.load(role) else {
            throw GitHubError.unauthorized
        }
        return creds
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

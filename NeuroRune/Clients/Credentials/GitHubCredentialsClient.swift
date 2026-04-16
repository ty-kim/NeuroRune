//
//  GitHubCredentialsClient.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import Dependencies
import os

nonisolated struct GitHubCredentialsClient: Sendable {
    var load: @Sendable (CredentialsRole) throws -> GitHubCredentials?
    var save: @Sendable (GitHubCredentials) throws -> Void
    var clear: @Sendable (CredentialsRole) throws -> Void
}

nonisolated extension GitHubCredentialsClient {
    /// 구버전 단일 키. 존재하면 role=.global로 마이그레이션.
    static let legacyKeychainKey = "github_credentials"

    static func keychainKey(for role: CredentialsRole) -> String {
        "github_credentials_\(role.rawValue)"
    }

    static func keychainBacked(keychain: KeychainClient) -> GitHubCredentialsClient {
        GitHubCredentialsClient(
            load: { role in
                if let json = try keychain.load(keychainKey(for: role)) {
                    return try decode(json)
                }
                // 마이그레이션: legacy 키 읽어 .global로 저장
                if role == .global, let legacy = try keychain.load(legacyKeychainKey) {
                    let creds = try decode(legacy)
                    try save(creds, keychain: keychain)
                    try keychain.delete(legacyKeychainKey)
                    Logger.keychain.info("migrated legacy github_credentials → role=global")
                    return creds
                }
                return nil
            },
            save: { credentials in
                try save(credentials, keychain: keychain)
            },
            clear: { role in
                try keychain.delete(keychainKey(for: role))
                Logger.keychain.info("github credentials cleared, role: \(role.rawValue, privacy: .public)")
            }
        )
    }

    private static func save(_ credentials: GitHubCredentials, keychain: KeychainClient) throws {
        let data = try JSONEncoder().encode(credentials)
        guard let json = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        try keychain.save(keychainKey(for: credentials.role), json)
        Logger.keychain.info("github credentials saved, role: \(credentials.role.rawValue, privacy: .public)")
    }

    private static func decode(_ json: String) throws -> GitHubCredentials {
        guard let data = json.data(using: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return try JSONDecoder().decode(GitHubCredentials.self, from: data)
    }
}

nonisolated extension GitHubCredentialsClient {
    /// 로드 실패(Keychain 에러 등)와 미설정을 모두 nil로 통합.
    func loadIgnoringError(role: CredentialsRole = .global) -> GitHubCredentials? {
        (try? load(role))
    }
}

nonisolated extension GitHubCredentialsClient: DependencyKey {
    static let liveValue = GitHubCredentialsClient.keychainBacked(keychain: KeychainClient.liveValue)

    static let testValue = GitHubCredentialsClient(
        load: unimplemented("GitHubCredentialsClient.load"),
        save: unimplemented("GitHubCredentialsClient.save"),
        clear: unimplemented("GitHubCredentialsClient.clear")
    )

    static let previewValue = GitHubCredentialsClient(
        load: { role in
            switch role {
            case .global:
                return GitHubCredentials(role: .global, pat: "ghp_preview", owner: "ty-kim", repo: "global-memory")
            case .local:
                return GitHubCredentials(role: .local, pat: "ghp_preview", owner: "ty-kim", repo: "neurorune-memory")
            }
        },
        save: { _ in },
        clear: { _ in }
    )
}

extension DependencyValues {
    nonisolated var githubCredentialsClient: GitHubCredentialsClient {
        get { self[GitHubCredentialsClient.self] }
        set { self[GitHubCredentialsClient.self] = newValue }
    }
}

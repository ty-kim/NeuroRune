//
//  GitHubCredentialsClient.swift
//  NeuroRune
//

import Foundation
import Dependencies
import os

nonisolated struct GitHubCredentialsClient: Sendable {
    var load: @Sendable () throws -> GitHubCredentials?
    var save: @Sendable (GitHubCredentials) throws -> Void
    var clear: @Sendable () throws -> Void
}

nonisolated extension GitHubCredentialsClient {
    static let keychainKey = "github_credentials"

    static func keychainBacked(keychain: KeychainClient) -> GitHubCredentialsClient {
        GitHubCredentialsClient(
            load: {
                guard let json = try keychain.load(keychainKey) else {
                    return nil
                }
                guard let data = json.data(using: .utf8) else {
                    throw KeychainError.decodingFailed
                }
                return try JSONDecoder().decode(GitHubCredentials.self, from: data)
            },
            save: { credentials in
                let data = try JSONEncoder().encode(credentials)
                guard let json = String(data: data, encoding: .utf8) else {
                    throw KeychainError.decodingFailed
                }
                try keychain.save(keychainKey, json)
                Logger.keychain.info("github credentials saved")
            },
            clear: {
                try keychain.delete(keychainKey)
                Logger.keychain.info("github credentials cleared")
            }
        )
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
        load: {
            GitHubCredentials(pat: "ghp_preview", owner: "ty-kim", repo: "memory")
        },
        save: { _ in },
        clear: {}
    )
}

extension DependencyValues {
    nonisolated var githubCredentialsClient: GitHubCredentialsClient {
        get { self[GitHubCredentialsClient.self] }
        set { self[GitHubCredentialsClient.self] = newValue }
    }
}

//
//  GroqCredentialsClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  GroqCredentials의 Keychain 영속화.
//

import Foundation
import Dependencies
import os

nonisolated struct GroqCredentialsClient: Sendable {
    var load: @Sendable () throws -> GroqCredentials?
    var save: @Sendable (GroqCredentials) throws -> Void
    var clear: @Sendable () throws -> Void
}

nonisolated extension GroqCredentialsClient {
    static func keychainBacked(keychain: KeychainClient) -> GroqCredentialsClient {
        GroqCredentialsClient(
            load: {
                guard let key = try keychain.load(GroqCredentials.KeychainKey.apiKey) else {
                    return nil
                }
                return GroqCredentials(apiKey: key)
            },
            save: { creds in
                try keychain.save(GroqCredentials.KeychainKey.apiKey, creds.apiKey)
            },
            clear: {
                try keychain.delete(GroqCredentials.KeychainKey.apiKey)
            }
        )
    }
}

nonisolated extension GroqCredentialsClient: DependencyKey {
    static let liveValue = GroqCredentialsClient.keychainBacked(keychain: KeychainClient.liveValue)

    static let testValue = GroqCredentialsClient(
        load: unimplemented("GroqCredentialsClient.load"),
        save: unimplemented("GroqCredentialsClient.save"),
        clear: unimplemented("GroqCredentialsClient.clear")
    )

    static let previewValue = GroqCredentialsClient(
        load: { nil },
        save: { _ in },
        clear: { }
    )
}

extension DependencyValues {
    nonisolated var groqCredentialsClient: GroqCredentialsClient {
        get { self[GroqCredentialsClient.self] }
        set { self[GroqCredentialsClient.self] = newValue }
    }
}

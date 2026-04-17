//
//  ElevenLabsCredentialsClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabsCredentials의 Keychain 영속화. GroqCredentialsClient 패턴.
//

import Foundation
import Dependencies

nonisolated struct ElevenLabsCredentialsClient: Sendable {
    var load: @Sendable () throws -> ElevenLabsCredentials?
    var save: @Sendable (ElevenLabsCredentials) throws -> Void
    var clear: @Sendable () throws -> Void
}

nonisolated extension ElevenLabsCredentialsClient {
    static func keychainBacked(keychain: KeychainClient) -> ElevenLabsCredentialsClient {
        ElevenLabsCredentialsClient(
            load: {
                guard let key = try keychain.load(ElevenLabsCredentials.keychainKey) else {
                    return nil
                }
                return ElevenLabsCredentials(apiKey: key)
            },
            save: { creds in
                try keychain.save(ElevenLabsCredentials.keychainKey, creds.apiKey)
            },
            clear: {
                try keychain.delete(ElevenLabsCredentials.keychainKey)
            }
        )
    }
}

nonisolated extension ElevenLabsCredentialsClient: DependencyKey {
    static let liveValue = ElevenLabsCredentialsClient.keychainBacked(keychain: KeychainClient.liveValue)

    static let testValue = ElevenLabsCredentialsClient(
        load: unimplemented("ElevenLabsCredentialsClient.load"),
        save: unimplemented("ElevenLabsCredentialsClient.save"),
        clear: unimplemented("ElevenLabsCredentialsClient.clear")
    )

    static let previewValue = ElevenLabsCredentialsClient(
        load: { nil },
        save: { _ in },
        clear: { }
    )
}

extension DependencyValues {
    nonisolated var elevenLabsCredentialsClient: ElevenLabsCredentialsClient {
        get { self[ElevenLabsCredentialsClient.self] }
        set { self[ElevenLabsCredentialsClient.self] = newValue }
    }
}

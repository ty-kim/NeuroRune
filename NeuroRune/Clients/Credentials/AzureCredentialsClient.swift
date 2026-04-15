//
//  AzureCredentialsClient.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import Dependencies
import os

nonisolated struct AzureCredentialsClient: Sendable {
    var load: @Sendable () throws -> AzureCredentials?
    var save: @Sendable (AzureCredentials) throws -> Void
    var clear: @Sendable () throws -> Void
}

nonisolated extension AzureCredentialsClient {
    static func keychainBacked(keychain: KeychainClient) -> AzureCredentialsClient {
        AzureCredentialsClient(
            load: {
                guard let key = try keychain.load(AzureCredentials.KeychainKey.apiKey),
                      let region = try keychain.load(AzureCredentials.KeychainKey.region) else {
                    return nil
                }
                return AzureCredentials(apiKey: key, region: region)
            },
            save: { creds in
                try keychain.save(AzureCredentials.KeychainKey.apiKey, creds.apiKey)
                try keychain.save(AzureCredentials.KeychainKey.region, creds.region)
            },
            clear: {
                try keychain.delete(AzureCredentials.KeychainKey.apiKey)
                try keychain.delete(AzureCredentials.KeychainKey.region)
            }
        )
    }
}

nonisolated extension AzureCredentialsClient: DependencyKey {
    static let liveValue = AzureCredentialsClient.keychainBacked(keychain: KeychainClient.liveValue)

    static let testValue = AzureCredentialsClient(
        load: unimplemented("AzureCredentialsClient.load"),
        save: unimplemented("AzureCredentialsClient.save"),
        clear: unimplemented("AzureCredentialsClient.clear")
    )

    static let previewValue = AzureCredentialsClient(
        load: { nil },
        save: { _ in },
        clear: { }
    )
}

extension DependencyValues {
    nonisolated var azureCredentialsClient: AzureCredentialsClient {
        get { self[AzureCredentialsClient.self] }
        set { self[AzureCredentialsClient.self] = newValue }
    }
}

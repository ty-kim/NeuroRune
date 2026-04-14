//
//  NCPCredentialsClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  NCPCredentials의 Keychain 영속화. GitHubCredentialsClient 패턴을 따름.
//

import Foundation
import Dependencies
import os

nonisolated struct NCPCredentialsClient: Sendable {
    /// Keychain에서 NCP 자격 증명 로드. 어느 키든 없으면 nil.
    var load: @Sendable () throws -> NCPCredentials?
    /// 저장. 두 키를 원자적으로 쓰지는 않지만 Keychain 작업은 일반적으로 신뢰할 만함.
    var save: @Sendable (NCPCredentials) throws -> Void
    /// 삭제. 두 키 모두 제거.
    var clear: @Sendable () throws -> Void
}

nonisolated extension NCPCredentialsClient {
    static func keychainBacked(keychain: KeychainClient) -> NCPCredentialsClient {
        NCPCredentialsClient(
            load: {
                guard let id = try keychain.load(NCPCredentials.KeychainKey.apiKeyID),
                      let key = try keychain.load(NCPCredentials.KeychainKey.apiKey) else {
                    return nil
                }
                return NCPCredentials(apiKeyID: id, apiKey: key)
            },
            save: { creds in
                try keychain.save(NCPCredentials.KeychainKey.apiKeyID, creds.apiKeyID)
                try keychain.save(NCPCredentials.KeychainKey.apiKey, creds.apiKey)
            },
            clear: {
                try keychain.delete(NCPCredentials.KeychainKey.apiKeyID)
                try keychain.delete(NCPCredentials.KeychainKey.apiKey)
            }
        )
    }
}

nonisolated extension NCPCredentialsClient: DependencyKey {
    static let liveValue = NCPCredentialsClient.keychainBacked(keychain: KeychainClient.liveValue)

    static let testValue = NCPCredentialsClient(
        load: unimplemented("NCPCredentialsClient.load"),
        save: unimplemented("NCPCredentialsClient.save"),
        clear: unimplemented("NCPCredentialsClient.clear")
    )

    static let previewValue = NCPCredentialsClient(
        load: { nil },
        save: { _ in },
        clear: { }
    )
}

extension DependencyValues {
    nonisolated var ncpCredentialsClient: NCPCredentialsClient {
        get { self[NCPCredentialsClient.self] }
        set { self[NCPCredentialsClient.self] = newValue }
    }
}

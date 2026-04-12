//
//  KeychainClient.swift
//  NeuroRune
//

import Foundation
import Dependencies

nonisolated struct KeychainClient: Sendable {
    var save: @Sendable (_ key: String, _ value: String) throws -> Void
    var load: @Sendable (_ key: String) throws -> String?
    var delete: @Sendable (_ key: String) throws -> Void
}

nonisolated enum KeychainError: Error, Equatable {
    case unhandled(status: OSStatus)
    case decodingFailed
}

nonisolated extension KeychainClient {

    static func liveBacked(service: String) -> KeychainClient {
        KeychainClient(
            save: { key, value in
                try KeychainInterop.save(service: service, key: key, value: value)
            },
            load: { key in
                try KeychainInterop.load(service: service, key: key)
            },
            delete: { key in
                try KeychainInterop.delete(service: service, key: key)
            }
        )
    }
}

nonisolated extension KeychainClient: DependencyKey {
    static let liveValue = KeychainClient.liveBacked(service: "com.neurorune.default")

    static let testValue = KeychainClient(
        save: unimplemented("KeychainClient.save"),
        load: unimplemented("KeychainClient.load"),
        delete: unimplemented("KeychainClient.delete")
    )
}

extension DependencyValues {
    nonisolated var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}

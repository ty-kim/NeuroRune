//
//  KeychainClient.swift
//  NeuroRune
//

import Foundation
import Security
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
                try saveToKeychain(service: service, key: key, value: value)
            },
            load: { key in
                try loadFromKeychain(service: service, key: key)
            },
            delete: { key in
                try deleteFromKeychain(service: service, key: key)
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

// MARK: - Keychain 저수준 구현

private nonisolated func saveToKeychain(service: String, key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
        throw KeychainError.decodingFailed
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]

    // Delete any existing entry for idempotent save
    SecItemDelete(query as CFDictionary)

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.unhandled(status: status)
    }
}

private nonisolated func loadFromKeychain(service: String, key: String) throws -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecItemNotFound {
        return nil
    }
    guard status == errSecSuccess else {
        throw KeychainError.unhandled(status: status)
    }

    guard let data = result as? Data,
          let value = String(data: data, encoding: .utf8) else {
        throw KeychainError.decodingFailed
    }
    return value
}

private nonisolated func deleteFromKeychain(service: String, key: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw KeychainError.unhandled(status: status)
    }
}

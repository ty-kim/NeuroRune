//
//  KeychainInterop.swift
//  NeuroRune
//

import Foundation
import Security
import os

nonisolated enum KeychainInterop {

    static func save(service: String, key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            Logger.keychain.error("save failed, encoding error, key: \(key, privacy: .public)")
            throw KeychainError.decodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            Logger.keychain.fault("save failed, key: \(key, privacy: .public), OSStatus: \(status)")
            throw KeychainError.unhandled(status: status)
        }
        Logger.keychain.info("save succeeded, key: \(key, privacy: .public)")
    }

    static func load(service: String, key: String) throws -> String? {
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
            Logger.keychain.info("load miss, key: \(key, privacy: .public)")
            return nil
        }
        guard status == errSecSuccess else {
            Logger.keychain.fault("load failed, key: \(key, privacy: .public), OSStatus: \(status)")
            throw KeychainError.unhandled(status: status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            Logger.keychain.error("load decoding failed, key: \(key, privacy: .public)")
            throw KeychainError.decodingFailed
        }
        Logger.keychain.info("load hit, key: \(key, privacy: .public)")
        return value
    }

    static func delete(service: String, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Logger.keychain.fault("delete failed, key: \(key, privacy: .public), OSStatus: \(status)")
            throw KeychainError.unhandled(status: status)
        }
        Logger.keychain.info("delete succeeded, key: \(key, privacy: .public)")
    }
}

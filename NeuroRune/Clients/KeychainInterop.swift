//
//  KeychainInterop.swift
//  NeuroRune
//
//  Created by tykim
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

        let lookupQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let lookupStatus = SecItemCopyMatching(lookupQuery as CFDictionary, nil)

        switch lookupStatus {
        case errSecSuccess:
            let updateAttrs: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let status = SecItemUpdate(lookupQuery as CFDictionary, updateAttrs as CFDictionary)
            guard status == errSecSuccess else {
                Logger.keychain.fault("update failed, key: \(key, privacy: .public), OSStatus: \(status)")
                throw KeychainError.unhandled(status: status)
            }
            Logger.keychain.info("update succeeded, key: \(key, privacy: .public)")

        case errSecItemNotFound:
            var addQuery = lookupQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            guard status == errSecSuccess else {
                Logger.keychain.fault("add failed, key: \(key, privacy: .public), OSStatus: \(status)")
                throw KeychainError.unhandled(status: status)
            }
            Logger.keychain.info("add succeeded, key: \(key, privacy: .public)")

        default:
            Logger.keychain.fault("lookup failed, key: \(key, privacy: .public), OSStatus: \(lookupStatus)")
            throw KeychainError.unhandled(status: lookupStatus)
        }
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

//
//  KeychainClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
import Security
@testable import NeuroRune

struct KeychainClientTests {

    // 각 테스트가 struct instance 재생성 시 고유 service로 격리
    let client: KeychainClient
    let service: String

    init() {
        service = "com.neurorune.tests.keychain.\(UUID().uuidString)"
        client = .liveBacked(service: service)
    }

    @Test("save 후 load는 같은 값을 반환한다")
    func saveThenLoadReturnsSameValue() throws {
        try client.save("anthropic_api_key", "sk-ant-abc123")

        let loaded = try client.load("anthropic_api_key")

        #expect(loaded == "sk-ant-abc123")
    }

    @Test("존재하지 않는 key에 대한 load는 nil을 반환한다")
    func loadMissingKeyReturnsNil() throws {
        let loaded = try client.load("nonexistent")

        #expect(loaded == nil)
    }

    @Test("save는 기존 값을 덮어쓴다")
    func saveOverwritesExistingValue() throws {
        try client.save("token", "first")
        try client.save("token", "second")

        let loaded = try client.load("token")

        #expect(loaded == "second")
    }

    @Test("delete 후 load는 nil을 반환한다")
    func deleteRemovesStoredValue() throws {
        try client.save("github_pat", "ghp_xyz")
        try client.delete("github_pat")

        let loaded = try client.load("github_pat")

        #expect(loaded == nil)
    }

    @Test("저장된 item은 WhenUnlockedThisDeviceOnly 접근 정책을 가진다")
    func savedItemHasThisDeviceOnlyAccessibility() throws {
        try client.save("token", "value")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "token",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        #expect(status == errSecSuccess)

        let attrs = result as? [String: Any]
        let accessible = attrs?[kSecAttrAccessible as String] as? String
        #expect(accessible == (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String))
    }

    @Test("서로 다른 key는 독립적으로 저장된다")
    func differentKeysAreIndependent() throws {
        try client.save("key_a", "value_a")
        try client.save("key_b", "value_b")

        #expect(try client.load("key_a") == "value_a")
        #expect(try client.load("key_b") == "value_b")

        try client.delete("key_a")

        #expect(try client.load("key_a") == nil)
        #expect(try client.load("key_b") == "value_b")
    }
}

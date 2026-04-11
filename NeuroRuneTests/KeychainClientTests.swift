//
//  KeychainClientTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
@testable import NeuroRune

struct KeychainClientTests {

    // 각 테스트가 struct instance 재생성 시 고유 service로 격리
    let client: LiveKeychainClient

    init() {
        let uniqueService = "com.neurorune.tests.keychain.\(UUID().uuidString)"
        client = LiveKeychainClient(service: uniqueService)
    }

    @Test("LiveKeychainClient는 KeychainClient 프로토콜을 준수한다")
    func liveKeychainClientConformsToProtocol() {
        let _: any KeychainClient = client
    }

    @Test("save 후 load는 같은 값을 반환한다")
    func saveThenLoadReturnsSameValue() throws {
        try client.save(key: "anthropic_api_key", value: "sk-ant-abc123")

        let loaded = try client.load(key: "anthropic_api_key")

        #expect(loaded == "sk-ant-abc123")
    }

    @Test("존재하지 않는 key에 대한 load는 nil을 반환한다")
    func loadMissingKeyReturnsNil() throws {
        let loaded = try client.load(key: "nonexistent")

        #expect(loaded == nil)
    }

    @Test("save는 기존 값을 덮어쓴다")
    func saveOverwritesExistingValue() throws {
        try client.save(key: "token", value: "first")
        try client.save(key: "token", value: "second")

        let loaded = try client.load(key: "token")

        #expect(loaded == "second")
    }

    @Test("delete 후 load는 nil을 반환한다")
    func deleteRemovesStoredValue() throws {
        try client.save(key: "github_pat", value: "ghp_xyz")
        try client.delete(key: "github_pat")

        let loaded = try client.load(key: "github_pat")

        #expect(loaded == nil)
    }

    @Test("서로 다른 key는 독립적으로 저장된다")
    func differentKeysAreIndependent() throws {
        try client.save(key: "key_a", value: "value_a")
        try client.save(key: "key_b", value: "value_b")

        #expect(try client.load(key: "key_a") == "value_a")
        #expect(try client.load(key: "key_b") == "value_b")

        try client.delete(key: "key_a")

        #expect(try client.load(key: "key_a") == nil)
        #expect(try client.load(key: "key_b") == "value_b")
    }
}

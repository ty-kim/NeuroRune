//
//  GroqCredentialsClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  GroqCredentialsClient.keychainBacked 통합 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct GroqCredentialsClientTests {

    private let client: GroqCredentialsClient

    init() {
        let uniqueService = "com.neurorune.tests.groq-creds.\(UUID().uuidString)"
        let keychain = KeychainClient.liveBacked(service: uniqueService)
        self.client = .keychainBacked(keychain: keychain)
    }

    @Test("저장 후 로드 시 같은 credentials 반환")
    func saveThenLoad() throws {
        let creds = GroqCredentials(apiKey: "gsk_secret_xyz")

        try client.save(creds)
        let loaded = try client.load()

        #expect(loaded == creds)
    }

    @Test("저장 없이 로드 시 nil")
    func loadWhenEmptyReturnsNil() throws {
        let loaded = try client.load()
        #expect(loaded == nil)
    }

    @Test("clear 후 로드 시 nil")
    func clearRemovesCredentials() throws {
        try client.save(GroqCredentials(apiKey: "gsk_x"))
        try client.clear()

        #expect(try client.load() == nil)
    }

    @Test("save는 기존 값을 덮어쓴다")
    func saveOverwrites() throws {
        try client.save(GroqCredentials(apiKey: "gsk_a"))
        try client.save(GroqCredentials(apiKey: "gsk_b"))

        #expect(try client.load() == GroqCredentials(apiKey: "gsk_b"))
    }
}

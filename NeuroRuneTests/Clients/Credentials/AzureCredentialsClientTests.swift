//
//  AzureCredentialsClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Foundation
import Testing
@testable import NeuroRune

struct AzureCredentialsClientTests {

    private let client: AzureCredentialsClient

    init() {
        let uniqueService = "com.neurorune.tests.azure-creds.\(UUID().uuidString)"
        let keychain = KeychainClient.liveBacked(service: uniqueService)
        self.client = .keychainBacked(keychain: keychain)
    }

    @Test("저장 후 로드 시 같은 credentials 반환")
    func saveThenLoad() throws {
        let creds = AzureCredentials(apiKey: "azure-secret", region: "koreacentral")

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
        try client.save(AzureCredentials(apiKey: "k", region: "eastus"))
        try client.clear()

        #expect(try client.load() == nil)
    }

    @Test("save는 기존 값을 덮어쓴다")
    func saveOverwrites() throws {
        try client.save(AzureCredentials(apiKey: "k1", region: "eastus"))
        try client.save(AzureCredentials(apiKey: "k2", region: "koreacentral"))

        #expect(try client.load() == AzureCredentials(apiKey: "k2", region: "koreacentral"))
    }
}

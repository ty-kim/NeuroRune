//
//  GitHubCredentialsClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
@testable import NeuroRune

struct GitHubCredentialsClientTests {

    let client: GitHubCredentialsClient

    init() {
        let uniqueService = "com.neurorune.tests.github-creds.\(UUID().uuidString)"
        let keychain = KeychainClient.liveBacked(service: uniqueService)
        client = .keychainBacked(keychain: keychain)
    }

    @Test("저장 후 로드 시 같은 credentials 반환")
    func saveThenLoad() throws {
        let creds = GitHubCredentials(pat: "ghp_abc", owner: "alice", repo: "memory", branch: "dev")

        try client.save(creds)
        let loaded = try client.load(.global)

        #expect(loaded == creds)
    }

    @Test("저장 없이 로드 시 nil")
    func loadWhenEmptyReturnsNil() throws {
        let loaded = try client.load(.global)
        #expect(loaded == nil)
    }

    @Test("clear 후 로드 시 nil")
    func clearRemovesCredentials() throws {
        let creds = GitHubCredentials(pat: "ghp_abc", owner: "alice", repo: "memory")
        try client.save(creds)

        try client.clear(.global)

        #expect(try client.load(.global) == nil)
    }

    @Test("save는 기존 값을 덮어쓴다")
    func saveOverwrites() throws {
        try client.save(GitHubCredentials(pat: "old", owner: "o1", repo: "r1"))
        try client.save(GitHubCredentials(pat: "new", owner: "o2", repo: "r2", branch: "dev"))

        let loaded = try client.load(.global)

        #expect(loaded?.pat == "new")
        #expect(loaded?.owner == "o2")
        #expect(loaded?.branch == "dev")
    }
}

struct GitHubCredentialsDomainTests {

    @Test("isValid는 pat/owner/repo 모두 non-empty일 때 true")
    func isValidRequiresAllFields() {
        #expect(GitHubCredentials(pat: "p", owner: "o", repo: "r").isValid == true)
        #expect(GitHubCredentials(pat: "", owner: "o", repo: "r").isValid == false)
        #expect(GitHubCredentials(pat: "p", owner: "", repo: "r").isValid == false)
        #expect(GitHubCredentials(pat: "p", owner: "o", repo: "").isValid == false)
        #expect(GitHubCredentials(pat: "  ", owner: "o", repo: "r").isValid == false)
    }

    @Test("repoConfig는 owner/repo/branch를 GitHubRepoConfig로 매핑")
    func repoConfigMapping() {
        let creds = GitHubCredentials(pat: "p", owner: "alice", repo: "memory", branch: "dev")
        #expect(creds.repoConfig == GitHubRepoConfig(owner: "alice", repo: "memory", branch: "dev"))
    }
}

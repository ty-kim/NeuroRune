//
//  GitHubClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
import Dependencies
@testable import NeuroRune

struct GitHubClientTests {

    @Test("GitHubClient는 4개 클로저를 가진다 (listContents/loadFile/saveFile/deleteFile)")
    func structHasFourClosures() async throws {
        let stub = GitHubClient(
            listContents: { _, _ in [] },
            loadFile: { _, path in
                GitHubFile(path: path, sha: "s", content: "c", isDirectory: false)
            },
            saveFile: { _, path, content, _, _ in
                GitHubFile(path: path, sha: "new-sha", content: content, isDirectory: false)
            },
            deleteFile: { _, _, _, _ in }
        )

        let config = GitHubRepoConfig(owner: "u", repo: "r")

        let list = try await stub.listContents(config, "memory")
        #expect(list.isEmpty)

        let file = try await stub.loadFile(config, "memory/a.md")
        #expect(file.path == "memory/a.md")
        #expect(file.content == "c")

        let saved = try await stub.saveFile(config, "memory/b.md", "hello", nil, "add b")
        #expect(saved.sha == "new-sha")
        #expect(saved.content == "hello")

        try await stub.deleteFile(config, "memory/b.md", "new-sha", "remove b")
    }

    @Test("GitHubClient는 TCA DependencyKey로 등록되어 있다")
    func registeredAsDependency() async throws {
        let injected = GitHubClient(
            listContents: { _, _ in
                [GitHubFile(path: "x.md", sha: "1", content: "", isDirectory: false)]
            },
            loadFile: GitHubClient.testValue.loadFile,
            saveFile: GitHubClient.testValue.saveFile,
            deleteFile: GitHubClient.testValue.deleteFile
        )

        let result = try await withDependencies {
            $0.githubClient = injected
        } operation: {
            @Dependency(\.githubClient) var client
            return try await client.listContents(
                GitHubRepoConfig(owner: "u", repo: "r"),
                "memory"
            )
        }

        #expect(result.count == 1)
        #expect(result.first?.path == "x.md")
    }
}

struct GitHubDomainTests {

    @Test("GitHubFile.name은 path의 마지막 segment")
    func fileNameIsLastPathSegment() {
        let file = GitHubFile(path: "memory/user_profile.md", sha: "s", content: "", isDirectory: false)
        #expect(file.name == "user_profile.md")
    }

    @Test("GitHubRepoConfig는 기본 branch=main")
    func repoConfigDefaultsToMain() {
        let config = GitHubRepoConfig(owner: "u", repo: "r")
        #expect(config.branch == "main")
    }
}

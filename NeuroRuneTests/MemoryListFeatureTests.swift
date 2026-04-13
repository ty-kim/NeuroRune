//
//  MemoryListFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

@MainActor
struct MemoryListFeatureTests {

    private static let sampleCreds = GitHubCredentials(
        pat: "ghp_test",
        owner: "ty-kim",
        repo: "memory"
    )

    private static let sampleFiles = [
        GitHubFile(path: "memory/a.md", sha: "sha-a", content: "", isDirectory: false),
        GitHubFile(path: "memory/b.md", sha: "sha-b", content: "", isDirectory: false),
        GitHubFile(path: "memory/sub", sha: "sha-dir", content: "", isDirectory: true),
    ]

    @Test(".task는 creds가 있으면 listContents를 호출하고 filesLoaded를 발행한다")
    func taskLoadsFilesWithCreds() async {
        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { Self.sampleCreds }
            $0.githubClient.listContents = { _, _ in Self.sampleFiles }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.filesLoaded(Self.sampleFiles)) {
            // 디렉터리는 필터링됨
            $0.files = Self.sampleFiles.filter { !$0.isDirectory }
            $0.isLoading = false
            $0.credentialsMissing = false
            $0.config = Self.sampleCreds.repoConfig
        }
    }

    @Test(".task는 creds 없으면 credentialsMissing을 발행한다")
    func taskEmitsCredentialsMissingWhenAbsent() async {
        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { nil }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.credentialsMissing) {
            $0.isLoading = false
            $0.credentialsMissing = true
            $0.files = []
        }
    }

    @Test(".task는 listContents 실패 시 loadFailed를 발행한다")
    func taskEmitsLoadFailedOnError() async {
        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { Self.sampleCreds }
            $0.githubClient.listContents = { _, _ in throw GitHubError.unauthorized }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.loadFailed(String(localized: "memory.error.unauthorized"))) {
            $0.isLoading = false
            $0.listError = String(localized: "memory.error.unauthorized")
        }
    }

    @Test("deleteTapped 성공 시 files에서 제거된다")
    func deleteSucceededRemovesFromList() async {
        let fileToDelete = Self.sampleFiles[0]
        var state = MemoryListFeature.State()
        state.files = [fileToDelete, Self.sampleFiles[1]]
        state.isLoading = false

        let store = TestStore(initialState: state) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { Self.sampleCreds }
            $0.githubClient.deleteFile = { _, _, _, _ in }
        }

        await store.send(.deleteTapped(fileToDelete))
        await store.receive(.deleteSucceeded(fileToDelete.path)) {
            $0.files = [Self.sampleFiles[1]]
        }
    }

    @Test("deleteTapped 실패 시 listError가 세팅되고 목록은 유지된다")
    func deleteFailureKeepsList() async {
        let file = Self.sampleFiles[0]
        var state = MemoryListFeature.State()
        state.files = [file]
        state.isLoading = false

        let store = TestStore(initialState: state) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { Self.sampleCreds }
            $0.githubClient.deleteFile = { _, _, _, _ in throw GitHubError.conflict }
        }

        await store.send(.deleteTapped(file))
        await store.receive(.deleteFailed(String(localized: "memory.error.conflict"))) {
            $0.listError = String(localized: "memory.error.conflict")
        }
    }

    @Test("errorDismissed는 listError를 nil로 만든다")
    func errorDismissedClearsError() async {
        var state = MemoryListFeature.State()
        state.listError = "boom"

        let store = TestStore(initialState: state) {
            MemoryListFeature()
        }

        await store.send(.errorDismissed) {
            $0.listError = nil
        }
    }

    @Test("fileSelected는 selectedFile을 업데이트한다")
    func fileSelectedUpdatesState() async {
        let file = Self.sampleFiles[0]
        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        }

        await store.send(.fileSelected(file)) {
            $0.selectedFile = file
        }
    }
}

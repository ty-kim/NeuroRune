//
//  MemoryEditFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

private nonisolated enum EditFixtures {
    static let creds = GitHubCredentials(
        pat: "ghp_test",
        owner: "ty-kim",
        repo: "memory"
    )

    static let file = GitHubFile(
        path: "memory/user_profile.md",
        sha: "sha-0",
        content: "",
        isDirectory: false
    )
}

@MainActor
struct MemoryEditFeatureTests {

    @Test(".task는 loadFile 성공 시 contentLoaded를 발행한다")
    func taskLoadsContent() async {
        let store = TestStore(initialState: MemoryEditFeature.State(file: EditFixtures.file)) {
            MemoryEditFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { EditFixtures.creds }
            $0.githubClient.loadFile = { _, _ in
                GitHubFile(
                    path: EditFixtures.file.path,
                    sha: "sha-loaded",
                    content: "# Hello",
                    isDirectory: false
                )
            }
        }

        await store.send(.task)
        await store.receive(.contentLoaded(content: "# Hello", sha: "sha-loaded")) {
            $0.content = "# Hello"
            $0.file = GitHubFile(
                path: EditFixtures.file.path,
                sha: "sha-loaded",
                content: "# Hello",
                isDirectory: false
            )
            $0.isLoading = false
            $0.hasUnsavedChanges = false
        }
    }

    @Test("contentChanged는 hasUnsavedChanges를 true로 바꾼다 (원본과 다를 때)")
    func contentChangedMarksDirty() async {
        let file = GitHubFile(
            path: "a.md",
            sha: "sha",
            content: "original",
            isDirectory: false
        )
        var state = MemoryEditFeature.State(file: file)
        state.content = "original"
        state.isLoading = false

        let store = TestStore(initialState: state) {
            MemoryEditFeature()
        }

        await store.send(.contentChanged("modified")) {
            $0.content = "modified"
            $0.hasUnsavedChanges = true
        }

        await store.send(.contentChanged("original")) {
            $0.content = "original"
            $0.hasUnsavedChanges = false
        }
    }

    @Test("saveTapped는 saveFile을 호출하고 saveSucceeded로 file/sha를 갱신한다")
    func saveTappedCallsSave() async {
        let file = GitHubFile(
            path: "memory/a.md",
            sha: "old-sha",
            content: "old",
            isDirectory: false
        )
        var state = MemoryEditFeature.State(file: file)
        state.content = "new"
        state.isLoading = false
        state.hasUnsavedChanges = true

        let capturedMessage = LockIsolated<String?>(nil)
        let capturedSha = LockIsolated<String?>(nil)

        let store = TestStore(initialState: state) {
            MemoryEditFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { EditFixtures.creds }
            $0.githubClient.saveFile = { _, _, _, sha, message in
                capturedSha.setValue(sha)
                capturedMessage.setValue(message)
                return GitHubFile(
                    path: file.path,
                    sha: "new-sha",
                    content: "new",
                    isDirectory: false
                )
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        let expectedSaved = GitHubFile(
            path: file.path,
            sha: "new-sha",
            content: "new",
            isDirectory: false
        )
        await store.receive(.saveSucceeded(expectedSaved)) {
            $0.isSaving = false
            $0.file = expectedSaved
            $0.hasUnsavedChanges = false
            $0.saveCount = 1
        }

        #expect(capturedSha.value == "old-sha")
        #expect(capturedMessage.value == "Update a.md")
    }

    @Test("saveTapped는 hasUnsavedChanges=false일 때 no-op")
    func saveTappedNoOpWhenClean() async {
        var state = MemoryEditFeature.State(file: EditFixtures.file)
        state.isLoading = false
        state.hasUnsavedChanges = false

        let store = TestStore(initialState: state) {
            MemoryEditFeature()
        }

        await store.send(.saveTapped)
    }

    @Test("save 실패 시 error 세팅 + isSaving=false")
    func saveFailureSetsError() async {
        var state = MemoryEditFeature.State(file: EditFixtures.file)
        state.content = "new"
        state.isLoading = false
        state.hasUnsavedChanges = true

        let store = TestStore(initialState: state) {
            MemoryEditFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { EditFixtures.creds }
            $0.githubClient.saveFile = { _, _, _, _, _ in
                throw GitHubError.conflict
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveFailed(String(localized: "memory.error.conflict"))) {
            $0.isSaving = false
            $0.error = String(localized: "memory.error.conflict")
        }
    }

    @Test("loadFailed 시 isLoading=false + error 세팅")
    func loadFailureSetsError() async {
        let store = TestStore(initialState: MemoryEditFeature.State(file: EditFixtures.file)) {
            MemoryEditFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { EditFixtures.creds }
            $0.githubClient.loadFile = { _, _ in throw GitHubError.notFound }
        }

        await store.send(.task)
        await store.receive(.loadFailed(String(localized: "memory.error.notFound"))) {
            $0.isLoading = false
            $0.error = String(localized: "memory.error.notFound")
        }
    }

    @Test("errorDismissed는 error를 nil로 만든다")
    func errorDismissedClears() async {
        var state = MemoryEditFeature.State(file: EditFixtures.file)
        state.error = "boom"

        let store = TestStore(initialState: state) {
            MemoryEditFeature()
        }

        await store.send(.errorDismissed) {
            $0.error = nil
        }
    }
}

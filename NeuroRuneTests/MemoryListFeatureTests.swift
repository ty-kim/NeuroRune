//
//  MemoryListFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

private nonisolated enum Fixtures {
    static let creds = GitHubCredentials(
        pat: "ghp_test",
        owner: "ty-kim",
        repo: "memory"
    )

    static let files = [
        GitHubFile(path: "memory/a.md", sha: "sha-a", content: "", isDirectory: false),
        GitHubFile(path: "memory/b.md", sha: "sha-b", content: "", isDirectory: false),
        GitHubFile(path: "memory/sub", sha: "sha-dir", content: "", isDirectory: true),
    ]
}

@MainActor
struct MemoryListFeatureTests {

    @Test(".task는 creds가 있으면 listContents를 호출하고 filesLoaded를 발행한다")
    func taskLoadsFilesWithCreds() async {
        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in Fixtures.creds }
            $0.githubClient.listContents = { _, _ in Fixtures.files }
        }

        await store.send(.task)
        await store.receive(.filesLoaded(Fixtures.files)) {
            // 디렉터리는 필터링됨
            $0.files = Fixtures.files.filter { !$0.isDirectory }
            $0.isLoading = false
            $0.credentialsMissing = false
            $0.config = Fixtures.creds.repoConfig
        }
    }

    @Test(".task는 creds 없으면 credentialsMissing을 발행한다")
    func taskEmitsCredentialsMissingWhenAbsent() async {
        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in nil }
        }

        await store.send(.task)
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
            $0.githubCredentialsClient.load = { _ in Fixtures.creds }
            $0.githubClient.listContents = { _, _ in throw GitHubError.unauthorized }
        }

        await store.send(.task)
        await store.receive(.loadFailed(String(localized: "memory.error.unauthorized"))) {
            $0.isLoading = false
            $0.listError = String(localized: "memory.error.unauthorized")
        }
    }

    @Test("deleteTapped 성공 시 files에서 제거된다")
    func deleteSucceededRemovesFromList() async {
        let fileToDelete = Fixtures.files[0]
        var state = MemoryListFeature.State()
        state.files = [fileToDelete, Fixtures.files[1]]
        state.isLoading = false

        let store = TestStore(initialState: state) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in Fixtures.creds }
            $0.githubClient.deleteFile = { _, _, _, _ in }
        }

        await store.send(.deleteTapped(fileToDelete))
        await store.receive(.deleteSucceeded(fileToDelete.path)) {
            $0.files = [Fixtures.files[1]]
        }
    }

    @Test("deleteTapped 실패 시 listError가 세팅되고 목록은 유지된다")
    func deleteFailureKeepsList() async {
        let file = Fixtures.files[0]
        var state = MemoryListFeature.State()
        state.files = [file]
        state.isLoading = false

        let store = TestStore(initialState: state) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in Fixtures.creds }
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

    @Test("서브디렉터리 404는 빈 상태로 해석된다")
    func subdirectoryNotFoundBecomesEmpty() async {
        let credsWithSubPath = GitHubCredentials(
            pat: "ghp_test",
            owner: "ty-kim",
            repo: "memory",
            path: "notes"
        )

        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in credsWithSubPath }
            $0.githubClient.listContents = { _, _ in throw GitHubError.notFound }
        }

        await store.send(.task)
        await store.receive(.filesLoaded([])) {
            $0.files = []
            $0.isLoading = false
            $0.credentialsMissing = false
            $0.config = credsWithSubPath.repoConfig
        }
    }

    @Test("repo 루트 404는 loadFailed로 에러 노출")
    func rootNotFoundBecomesError() async {
        let credsRootPath = GitHubCredentials(
            pat: "ghp_test",
            owner: "ty-kim",
            repo: "nonexistent",
            path: ""
        )

        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in credsRootPath }
            $0.githubClient.listContents = { _, _ in throw GitHubError.notFound }
        }

        await store.send(.task)
        await store.receive(.loadFailed(GitHubError.notFound.localizedMessage)) {
            $0.isLoading = false
            $0.listError = GitHubError.notFound.localizedMessage
        }
    }

    @Test("filesLoaded는 이름 알파벳 순으로 정렬한다 (numeric-aware)")
    func filesLoadedSortsByName() async {
        let unsorted = [
            GitHubFile(path: "z.md", sha: "1", content: "", isDirectory: false),
            GitHubFile(path: "a.md", sha: "2", content: "", isDirectory: false),
            GitHubFile(path: "note_2.md", sha: "3", content: "", isDirectory: false),
            GitHubFile(path: "note_10.md", sha: "4", content: "", isDirectory: false),
        ]

        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in Fixtures.creds }
            $0.githubClient.listContents = { _, _ in unsorted }
        }

        await store.send(.task)
        await store.receive(.filesLoaded(unsorted)) {
            $0.files = [
                GitHubFile(path: "a.md", sha: "2", content: "", isDirectory: false),
                GitHubFile(path: "note_2.md", sha: "3", content: "", isDirectory: false),
                GitHubFile(path: "note_10.md", sha: "4", content: "", isDirectory: false),
                GitHubFile(path: "z.md", sha: "1", content: "", isDirectory: false),
            ]
            $0.isLoading = false
            $0.credentialsMissing = false
            $0.config = Fixtures.creds.repoConfig
        }
    }

    @Test("fileAdded는 files에 낙관적으로 insert하고 이름순 정렬 유지")
    func fileAddedInsertsOptimistically() async {
        var state = MemoryListFeature.State()
        state.files = [
            GitHubFile(path: "a.md", sha: "1", content: "", isDirectory: false),
            GitHubFile(path: "c.md", sha: "2", content: "", isDirectory: false),
        ]
        state.isLoading = false

        let store = TestStore(initialState: state) { MemoryListFeature() }

        let newFile = GitHubFile(path: "b.md", sha: "3", content: "", isDirectory: false)
        await store.send(.fileAdded(newFile)) {
            $0.files = [
                GitHubFile(path: "a.md", sha: "1", content: "", isDirectory: false),
                newFile,
                GitHubFile(path: "c.md", sha: "2", content: "", isDirectory: false),
            ]
        }
    }

    @Test("fileAdded는 같은 path 기존 항목을 새 sha로 교체한다")
    func fileAddedReplacesExistingPath() async {
        var state = MemoryListFeature.State()
        state.files = [
            GitHubFile(path: "a.md", sha: "old-sha", content: "", isDirectory: false),
        ]
        state.isLoading = false

        let store = TestStore(initialState: state) { MemoryListFeature() }

        let updated = GitHubFile(path: "a.md", sha: "new-sha", content: "new content", isDirectory: false)
        await store.send(.fileAdded(updated)) {
            $0.files = [updated]
        }
    }

    @Test("fileSelected는 selectedFile을 업데이트한다")
    func fileSelectedUpdatesState() async {
        let file = Fixtures.files[0]
        let store = TestStore(initialState: MemoryListFeature.State()) {
            MemoryListFeature()
        }

        await store.send(.fileSelected(file)) {
            $0.selectedFile = file
        }
    }
}

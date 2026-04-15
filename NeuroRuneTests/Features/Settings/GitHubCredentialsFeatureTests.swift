//
//  GitHubCredentialsFeatureTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

@MainActor
struct GitHubCredentialsFeatureTests {

    @Test("필드 Changed 액션은 각 필드를 업데이트한다")
    func fieldChangedUpdatesState() async {
        let store = TestStore(initialState: GitHubCredentialsFeature.State()) {
            GitHubCredentialsFeature()
        }

        await store.send(.patChanged("ghp_abc")) { $0.pat = "ghp_abc" }
        await store.send(.ownerChanged("alice")) { $0.owner = "alice" }
        await store.send(.repoChanged("memory")) { $0.repo = "memory" }
        await store.send(.branchChanged("dev")) { $0.branch = "dev" }
    }

    @Test("isValid는 모든 필드가 non-empty일 때만 true")
    func isValidRequiresAllFields() {
        var state = GitHubCredentialsFeature.State()
        #expect(state.isValid == false)
        state.pat = "ghp_abc"
        state.owner = "alice"
        state.repo = "memory"
        #expect(state.isValid == true)
        state.branch = ""
        #expect(state.isValid == false)
    }

    @Test("saveTapped는 trim 후 Keychain에 저장하고 saveSucceeded를 발행한다")
    func saveTappedTrimsAndSaves() async {
        let savedCreds = LockIsolated<GitHubCredentials?>(nil)
        var state = GitHubCredentialsFeature.State()
        state.pat = "  ghp_abc\n"
        state.owner = "alice"
        state.repo = "memory"

        let store = TestStore(initialState: state) {
            GitHubCredentialsFeature()
        } withDependencies: {
            $0.githubCredentialsClient.save = { @Sendable creds in
                savedCreds.setValue(creds)
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.pat = ""
        }

        #expect(savedCreds.value?.pat == "ghp_abc")
        #expect(savedCreds.value?.owner == "alice")
        #expect(savedCreds.value?.repo == "memory")
        #expect(savedCreds.value?.branch == "main")
    }

    @Test("isValid false일 때 saveTapped는 no-op")
    func saveTappedNoOpWhenInvalid() async {
        let store = TestStore(initialState: GitHubCredentialsFeature.State()) {
            GitHubCredentialsFeature()
        }

        await store.send(.saveTapped)
    }

    @Test("saveFailed는 error 메시지를 세팅한다")
    func saveFailureSetsError() async {
        var state = GitHubCredentialsFeature.State()
        state.pat = "ghp_abc"
        state.owner = "alice"
        state.repo = "memory"

        let store = TestStore(initialState: state) {
            GitHubCredentialsFeature()
        } withDependencies: {
            $0.githubCredentialsClient.save = { @Sendable _ in
                throw KeychainError.unhandled(status: -25300)
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveFailed(KeychainError.unhandled(status: -25300).localizedDescription)) {
            $0.isSaving = false
            $0.error = KeychainError.unhandled(status: -25300).localizedDescription
        }
    }

    @Test("loadExisting은 기존 creds로 필드를 채운다 (PAT 제외 가능)")
    func loadExistingPopulatesFields() async {
        let existing = GitHubCredentials(
            pat: "ghp_existing",
            owner: "alice",
            repo: "memory",
            branch: "dev"
        )

        let store = TestStore(initialState: GitHubCredentialsFeature.State()) {
            GitHubCredentialsFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in existing }
        }

        await store.send(.loadExisting)
        await store.receive(.existingLoaded(existing)) {
            $0.pat = "ghp_existing"
            $0.owner = "alice"
            $0.repo = "memory"
            $0.branch = "dev"
        }
    }
}

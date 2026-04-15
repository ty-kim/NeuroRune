//
//  MemoryCreateFeatureTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

private nonisolated enum CreateFixtures {
    static let creds = GitHubCredentials(
        pat: "ghp_test",
        owner: "ty-kim",
        repo: "memory",
        path: "memory"
    )
}

@MainActor
struct MemoryCreateFeatureTests {

    @Test("filenameChanged는 filename을 업데이트하고 error를 지운다")
    func filenameChangedUpdates() async {
        var state = MemoryCreateFeature.State()
        state.error = "old"

        let store = TestStore(initialState: state) { MemoryCreateFeature() }

        await store.send(.filenameChanged("note")) {
            $0.filename = "note"
            $0.error = nil
        }
    }

    @Test("isValid는 filename이 non-empty일 때 true")
    func isValidRequiresFilename() {
        var state = MemoryCreateFeature.State()
        #expect(state.isValid == false)
        state.filename = "note"
        #expect(state.isValid == true)
        state.filename = "   "
        #expect(state.isValid == false)
    }

    @Test("isValid는 path traversal/escape/숨김파일을 거부한다")
    func isValidRejectsUnsafeFilenames() {
        var state = MemoryCreateFeature.State()
        let bad = [
            "../escape",
            "..",
            "foo/bar",
            "foo\\bar",
            "/leading",
            ".hidden",
            ".github/workflows",
            "a\u{00}b",
        ]
        for name in bad {
            state.filename = name
            #expect(state.isValid == false, "\(name)이 isValid==true로 통과")
        }
    }

    @Test("fullPath는 basePath + filename + .md 자동 부착")
    func fullPathComposition() {
        var state = MemoryCreateFeature.State(basePath: "memory")
        state.filename = "note"
        #expect(state.fullPath == "memory/note.md")

        state.filename = "note.md"
        #expect(state.fullPath == "memory/note.md")

        state = MemoryCreateFeature.State(basePath: "")
        state.filename = "root_note"
        #expect(state.fullPath == "root_note.md")
    }

    @Test("saveTapped는 saveFile을 sha=nil로 호출하고 Create 메시지를 넣는다")
    func saveTappedCreatesFile() async {
        let capturedSha = LockIsolated<String??>(nil)
        let capturedMessage = LockIsolated<String?>(nil)

        var state = MemoryCreateFeature.State(basePath: "memory")
        state.filename = "new_note"
        state.content = "# Hello"

        let store = TestStore(initialState: state) {
            MemoryCreateFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in CreateFixtures.creds }
            $0.githubClient.saveFile = { _, path, _, sha, message in
                capturedSha.setValue(sha)
                capturedMessage.setValue(message)
                return GitHubFile(
                    path: path,
                    sha: "new-sha",
                    content: "# Hello",
                    isDirectory: false
                )
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        let expectedFile = GitHubFile(
            path: "memory/new_note.md",
            sha: "new-sha",
            content: "# Hello",
            isDirectory: false
        )
        await store.receive(.saveSucceeded(expectedFile)) {
            $0.isSaving = false
            $0.createdFile = expectedFile
        }

        #expect(capturedSha.value == .some(nil))  // sha 명시적 nil
        #expect(capturedMessage.value == "Create new_note.md")
    }

    @Test("saveTapped는 isValid false일 때 no-op")
    func saveTappedNoOpWhenInvalid() async {
        let store = TestStore(initialState: MemoryCreateFeature.State()) {
            MemoryCreateFeature()
        }

        await store.send(.saveTapped)
    }

    @Test("save 실패 시 error 세팅 + isSaving=false")
    func saveFailureSetsError() async {
        var state = MemoryCreateFeature.State()
        state.filename = "note"

        let store = TestStore(initialState: state) {
            MemoryCreateFeature()
        } withDependencies: {
            $0.githubCredentialsClient.load = { _ in CreateFixtures.creds }
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
}

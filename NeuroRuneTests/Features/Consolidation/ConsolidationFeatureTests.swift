//
//  ConsolidationFeatureTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 23 Slice 4 — Consolidation reducer.
//

import Foundation
import Testing
import ComposableArchitecture
@testable import NeuroRune

@MainActor
struct ConsolidationFeatureTests {

    @Test("consolidateTapped: collect → generate → proposals + resultAt 채움")
    func consolidateFlowSuccess() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = ConsolidationProposal(
            action: .create, path: "memory/x.md", rationale: "r", content: "c", beforeContent: nil
        )

        let store = TestStore(initialState: ConsolidationFeature.State()) {
            ConsolidationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.consolidationCollector.collect = {
                ConsolidationInput(conversations: [], memoryIndex: "", memoryFiles: [])
            }
            $0.consolidationClient.generate = { _ in
                ConsolidationResult(proposals: [sample])
            }
        }

        await store.send(.consolidateTapped) {
            $0.isLoading = true
            $0.error = nil
        }
        await store.receive(.generateFinished(ConsolidationResult(proposals: [sample]))) {
            $0.isLoading = false
            $0.proposals = [sample]
            $0.resultAt = now
        }
    }

    @Test("consolidateTapped: generate 실패 → error 세팅, isLoading 해제")
    func consolidateFlowFailure() async {
        let store = TestStore(initialState: ConsolidationFeature.State()) {
            ConsolidationFeature()
        } withDependencies: {
            $0.consolidationCollector.collect = {
                ConsolidationInput(conversations: [], memoryIndex: "", memoryFiles: [])
            }
            $0.consolidationClient.generate = { _ in
                throw ConsolidationError.invalidJSON("bad")
            }
        }

        await store.send(.consolidateTapped) {
            $0.isLoading = true
            $0.error = nil
        }
        await store.receive(.generateFailed(.invalidJSON("bad"))) {
            $0.isLoading = false
            $0.error = .invalidJSON("bad")
        }
    }

    @Test("consolidateTapped: 로딩 중이면 no-op")
    func consolidateNoopWhileLoading() async {
        var initial = ConsolidationFeature.State()
        initial.isLoading = true
        let store = TestStore(initialState: initial) { ConsolidationFeature() }
        await store.send(.consolidateTapped)
    }

    @Test("proposalRejected: 해당 id 제거, 다른 건 유지")
    func proposalRejectedRemovesOnly() async {
        let p1 = ConsolidationProposal(action: .create, path: "a.md", rationale: "r1", content: "c1", beforeContent: nil)
        let p2 = ConsolidationProposal(action: .skip, path: "b.md", rationale: "r2", content: nil, beforeContent: nil)
        var initial = ConsolidationFeature.State()
        initial.proposals = [p1, p2]

        let store = TestStore(initialState: initial) { ConsolidationFeature() }
        await store.send(.proposalRejected(p1.id)) {
            $0.proposals = [p2]
        }
    }

    @Test("errorDismissed: error 해제")
    func errorDismiss() async {
        var initial = ConsolidationFeature.State()
        initial.error = .emptyResponse
        let store = TestStore(initialState: initial) { ConsolidationFeature() }
        await store.send(.errorDismissed) { $0.error = nil }
    }

    // MARK: - accept

    @Test("proposalAccepted create: saveFile(sha=nil) 호출 후 리스트에서 제거")
    func acceptCreateWritesNewFile() async {
        let p = ConsolidationProposal(
            action: .create, path: "memory/x.md", rationale: "r", content: "hello", beforeContent: nil
        )
        var initial = ConsolidationFeature.State()
        initial.proposals = [p]

        let recorded = LockIsolated<(path: String?, sha: String?, content: String?)>((nil, nil, nil))

        let store = TestStore(initialState: initial) {
            ConsolidationFeature()
        } withDependencies: {
            $0.githubClient.saveFile = { _, path, content, sha, _ in
                recorded.setValue((path, sha, content))
                return GitHubFile(path: path, sha: "new-sha", content: content, isDirectory: false)
            }
        }

        await store.send(.proposalAccepted(p.id)) {
            $0.acceptingId = p.id
        }
        await store.receive(.proposalAcceptCompleted(p.id)) {
            $0.acceptingId = nil
            $0.proposals = []
        }
        #expect(recorded.value.path == "memory/x.md")
        #expect(recorded.value.sha == nil)
        #expect(recorded.value.content == "hello")
    }

    @Test("proposalAccepted update: loadFile로 sha 취득 후 saveFile(sha)")
    func acceptUpdateUsesExistingSha() async {
        let p = ConsolidationProposal(
            action: .update, path: "memory/y.md", rationale: "r",
            content: "new", beforeContent: "old"
        )
        var initial = ConsolidationFeature.State()
        initial.proposals = [p]

        let savedSha = LockIsolated<String?>(nil)

        let store = TestStore(initialState: initial) {
            ConsolidationFeature()
        } withDependencies: {
            $0.githubClient.loadFile = { _, path in
                GitHubFile(path: path, sha: "existing-sha", content: "old", isDirectory: false)
            }
            $0.githubClient.saveFile = { _, path, content, sha, _ in
                savedSha.setValue(sha)
                return GitHubFile(path: path, sha: "new", content: content, isDirectory: false)
            }
        }

        await store.send(.proposalAccepted(p.id)) { $0.acceptingId = p.id }
        await store.receive(.proposalAcceptCompleted(p.id)) {
            $0.acceptingId = nil
            $0.proposals = []
        }
        #expect(savedSha.value == "existing-sha")
    }

    @Test("proposalAccepted delete: deleteFile 호출 후 리스트에서 제거")
    func acceptDeleteRemovesFile() async {
        let p = ConsolidationProposal(
            action: .delete, path: "memory/z.md", rationale: "r", content: nil, beforeContent: nil
        )
        var initial = ConsolidationFeature.State()
        initial.proposals = [p]

        let deleted = LockIsolated<(path: String?, sha: String?)>((nil, nil))

        let store = TestStore(initialState: initial) {
            ConsolidationFeature()
        } withDependencies: {
            $0.githubClient.loadFile = { _, path in
                GitHubFile(path: path, sha: "abc", content: "obsolete", isDirectory: false)
            }
            $0.githubClient.deleteFile = { _, path, sha, _ in
                deleted.setValue((path, sha))
            }
        }

        await store.send(.proposalAccepted(p.id)) { $0.acceptingId = p.id }
        await store.receive(.proposalAcceptCompleted(p.id)) {
            $0.acceptingId = nil
            $0.proposals = []
        }
        #expect(deleted.value.path == "memory/z.md")
        #expect(deleted.value.sha == "abc")
    }

    @Test("proposalAccepted 실패: error 세팅, 리스트 유지")
    func acceptFailureKeepsProposal() async {
        let p = ConsolidationProposal(
            action: .create, path: "x.md", rationale: "r", content: "c", beforeContent: nil
        )
        var initial = ConsolidationFeature.State()
        initial.proposals = [p]

        let store = TestStore(initialState: initial) {
            ConsolidationFeature()
        } withDependencies: {
            $0.githubClient.saveFile = { _, _, _, _, _ in
                throw ConsolidationError.llmFailed("network down")
            }
        }
        store.exhaustivity = .off

        await store.send(.proposalAccepted(p.id)) { $0.acceptingId = p.id }
        await store.receive(.proposalAcceptFailed(p.id, .llmFailed("network down"))) {
            $0.acceptingId = nil
            $0.error = .llmFailed("network down")
        }
        #expect(store.state.proposals.count == 1)
    }
}

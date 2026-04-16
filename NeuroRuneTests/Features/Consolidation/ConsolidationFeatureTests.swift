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
}

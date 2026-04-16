//
//  ConsolidationFeature.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 4 — "Consolidate now" 수동 트리거 + 제안 리스트 + accept/reject.
//

import Foundation
import ComposableArchitecture

nonisolated struct ConsolidationFeature: Reducer {

    struct State: Equatable {
        var isLoading: Bool = false
        var proposals: [ConsolidationProposal] = []
        var error: ConsolidationError?
        var resultAt: Date?
    }

    enum Action: Equatable {
        case consolidateTapped
        case generateFinished(ConsolidationResult)
        case generateFailed(ConsolidationError)
        case proposalRejected(UUID)
        case errorDismissed
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.consolidationCollector) var collector
        @Dependency(\.consolidationClient) var client
        @Dependency(\.date) var date

        switch action {
        case .consolidateTapped:
            guard !state.isLoading else { return .none }
            state.isLoading = true
            state.error = nil
            return .run { send in
                do {
                    let input = try await collector.collect()
                    let result = try await client.generate(input)
                    await send(.generateFinished(result))
                } catch let e as ConsolidationError {
                    await send(.generateFailed(e))
                } catch {
                    await send(.generateFailed(.llmFailed(error.localizedDescription)))
                }
            }

        case let .generateFinished(result):
            state.isLoading = false
            state.proposals = result.proposals
            state.resultAt = date.now
            return .none

        case let .generateFailed(error):
            state.isLoading = false
            state.error = error
            return .none

        case let .proposalRejected(id):
            state.proposals.removeAll { $0.id == id }
            return .none

        case .errorDismissed:
            state.error = nil
            return .none
        }
    }
}

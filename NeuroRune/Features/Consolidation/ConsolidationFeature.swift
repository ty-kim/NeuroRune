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
        /// accept/ reject 진행 중인 제안 id. UI에서 해당 카드에 스피너/비활성화 처리.
        var acceptingId: UUID?
    }

    enum Action: Equatable {
        case consolidateTapped
        case generateFinished(ConsolidationResult)
        case generateFailed(ConsolidationError)
        case proposalAccepted(UUID)
        case proposalAcceptCompleted(UUID)
        case proposalAcceptFailed(UUID, ConsolidationError)
        case proposalRejected(UUID)
        case errorDismissed
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.consolidationCollector) var collector
            @Dependency(\.consolidationClient) var client
            @Dependency(\.githubClient) var github
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

            case let .proposalAccepted(id):
                guard state.acceptingId == nil,
                      let proposal = state.proposals.first(where: { $0.id == id }) else {
                    return .none
                }
                state.acceptingId = id
                return .run { send in
                    do {
                        try await applyProposal(proposal, github: github)
                        await send(.proposalAcceptCompleted(id))
                    } catch let e as ConsolidationError {
                        await send(.proposalAcceptFailed(id, e))
                    } catch {
                        await send(.proposalAcceptFailed(id, .llmFailed(error.localizedDescription)))
                    }
                }

            case let .proposalAcceptCompleted(id):
                state.acceptingId = nil
                state.proposals.removeAll { $0.id == id }
                return .none

            case let .proposalAcceptFailed(_, error):
                state.acceptingId = nil
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

    /// Proposal의 action별로 GitHub 쓰기 수행. 실패 시 ConsolidationError throw.
    /// - create: saveFile(sha=nil)
    /// - update: loadFile로 sha 취득 → saveFile(sha)
    /// - delete: loadFile로 sha 취득 → deleteFile
    /// - skip: no-op
    private func applyProposal(_ p: ConsolidationProposal, github: GitHubClient) async throws {
        let message = "consolidate: \(p.action.rawValue) \(p.path)"
        switch p.action {
        case .create:
            guard let content = p.content else {
                throw ConsolidationError.invalidJSON("create requires content")
            }
            _ = try await github.saveFile(.local, p.path, content, nil, message)

        case .update:
            guard let content = p.content else {
                throw ConsolidationError.invalidJSON("update requires content")
            }
            let existing = try await github.loadFile(.local, p.path)
            _ = try await github.saveFile(.local, p.path, content, existing.sha, message)

        case .delete:
            let existing = try await github.loadFile(.local, p.path)
            try await github.deleteFile(.local, p.path, existing.sha, message)

        case .skip:
            return
        }
    }
}

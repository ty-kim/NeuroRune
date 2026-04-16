//
//  ConsolidationProposal.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 1 — Consolidation 제안 도메인 모델.
//

import Foundation

nonisolated enum ProposalAction: String, Codable, Sendable, Equatable {
    case create, update, delete, skip
}

nonisolated struct ConsolidationProposal: Codable, Sendable, Equatable, Identifiable {
    var id: UUID = UUID()
    let action: ProposalAction
    let path: String
    let rationale: String
    let content: String?
    let beforeContent: String?

    private enum CodingKeys: String, CodingKey {
        case action, path, rationale, content, beforeContent
    }
}

/// LLM 응답 전체 래퍼. `proposals`가 빈 배열이면 "정제할 것 없음" (정상).
nonisolated struct ConsolidationResult: Codable, Sendable, Equatable {
    let proposals: [ConsolidationProposal]
}

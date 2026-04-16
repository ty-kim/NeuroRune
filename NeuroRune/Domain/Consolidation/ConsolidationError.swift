//
//  ConsolidationError.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 3a — Consolidation 파이프라인 에러.
//

import Foundation

nonisolated enum ConsolidationError: Error, Equatable, Sendable {
    /// LLM 호출 실패(네트워크·모델·rate limit 등).
    case llmFailed(String)
    /// LLM 응답을 JSON으로 파싱 불가.
    case invalidJSON(String)
    /// 응답이 비었거나 공백뿐.
    case emptyResponse
}

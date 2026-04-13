//
//  LLMStreamEvent.swift
//  NeuroRune
//

import Foundation

/// LLMClient.streamMessage가 emit하는 단위 이벤트.
/// - textDelta: 일반 텍스트 chunk.
/// - toolUseRequest: Claude가 tool 호출을 요청 (멀티턴 루프 트리거).
nonisolated enum LLMStreamEvent: Sendable, Equatable {
    case textDelta(String)
    case toolUseRequest(id: String, name: String, inputJSON: String)
}

//
//  ConsolidationClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 3a — 대화·메모리 → LLM 호출 → 제안 리스트.
//  liveValue는 LLMClient 재사용(streamMessage 전체 누적 후 파싱).
//

import Foundation
import Dependencies

nonisolated struct ConsolidationClient: Sendable {
    /// 입력을 LLM에 보내고 제안 결과를 반환.
    var generate: @Sendable (ConsolidationInput) async throws -> ConsolidationResult
}

nonisolated extension ConsolidationClient {
    /// LLM raw 응답 → ConsolidationResult. 순수 함수.
    /// - 코드 펜스(```json / ```) 제거
    /// - preamble/postamble이 붙어있어도 첫 `{` ~ 마지막 `}` 구간 추출
    /// - 파싱 실패 시 `ConsolidationError.invalidJSON` throw
    static func parseResponse(_ raw: String) throws -> ConsolidationResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ConsolidationError.emptyResponse }

        let stripped = stripCodeFence(trimmed)
        let body = extractJSONObject(stripped) ?? stripped

        guard let data = body.data(using: .utf8) else {
            throw ConsolidationError.invalidJSON("utf8 encoding failed")
        }
        do {
            return try JSONDecoder().decode(ConsolidationResult.self, from: data)
        } catch {
            throw ConsolidationError.invalidJSON(error.localizedDescription)
        }
    }

    private static func stripCodeFence(_ s: String) -> String {
        var out = s
        if out.hasPrefix("```json") {
            out.removeFirst("```json".count)
        } else if out.hasPrefix("```") {
            out.removeFirst("```".count)
        }
        if out.hasSuffix("```") {
            out.removeLast("```".count)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 문자열에서 첫 `{`부터 마지막 `}`까지 추출. 없으면 nil.
    private static func extractJSONObject(_ s: String) -> String? {
        guard let first = s.firstIndex(of: "{"),
              let last = s.lastIndex(of: "}"),
              first < last else { return nil }
        return String(s[first...last])
    }
}

// MARK: - Dependency

nonisolated extension ConsolidationClient: DependencyKey {
    static let liveValue = ConsolidationClient(
        generate: { _ in
            // Slice 3b에서 LLMClient 연결. 현재는 미구현.
            throw ConsolidationError.llmFailed("not wired yet")
        }
    )

    static let testValue = ConsolidationClient(
        generate: unimplemented("ConsolidationClient.generate",
                                placeholder: ConsolidationResult(proposals: []))
    )

    static let previewValue = ConsolidationClient(
        generate: { _ in ConsolidationResult(proposals: []) }
    )
}

extension DependencyValues {
    nonisolated var consolidationClient: ConsolidationClient {
        get { self[ConsolidationClient.self] }
        set { self[ConsolidationClient.self] = newValue }
    }
}

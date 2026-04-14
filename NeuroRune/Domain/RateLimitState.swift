//
//  RateLimitState.swift
//  NeuroRune
//

import Foundation

/// Anthropic API 응답 헤더 `anthropic-ratelimit-*`에서 파싱한 쿼터 상태.
/// 성공/실패 모든 응답에 포함되어 UI에서 남은 한도를 실시간으로 보여준다.
nonisolated struct RateLimitState: Equatable, Sendable {
    var requests: Quota?
    var tokens: Quota?
    var inputTokens: Quota?
    var outputTokens: Quota?

    init(
        requests: Quota? = nil,
        tokens: Quota? = nil,
        inputTokens: Quota? = nil,
        outputTokens: Quota? = nil
    ) {
        self.requests = requests
        self.tokens = tokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    nonisolated struct Quota: Equatable, Sendable {
        let limit: Int
        let remaining: Int
        let resetsAt: Date

        init(limit: Int, remaining: Int, resetsAt: Date) {
            self.limit = limit
            self.remaining = remaining
            self.resetsAt = resetsAt
        }

        /// 0.0 ~ 1.0 범위의 남은 비율. limit == 0이면 0.0.
        var percentRemaining: Double {
            guard limit > 0 else { return 0.0 }
            return Double(remaining) / Double(limit)
        }
    }
}

nonisolated extension RateLimitState {
    /// HTTP 응답 헤더에서 4개 Quota를 추출한다.
    /// 누락·파싱 실패된 그룹의 Quota는 nil.
    static func parse(from response: HTTPURLResponse) -> RateLimitState {
        RateLimitState(
            requests: Quota.parse(
                from: response,
                limitKey: "anthropic-ratelimit-requests-limit",
                remainingKey: "anthropic-ratelimit-requests-remaining",
                resetKey: "anthropic-ratelimit-requests-reset"
            ),
            tokens: Quota.parse(
                from: response,
                limitKey: "anthropic-ratelimit-tokens-limit",
                remainingKey: "anthropic-ratelimit-tokens-remaining",
                resetKey: "anthropic-ratelimit-tokens-reset"
            ),
            inputTokens: Quota.parse(
                from: response,
                limitKey: "anthropic-ratelimit-input-tokens-limit",
                remainingKey: "anthropic-ratelimit-input-tokens-remaining",
                resetKey: "anthropic-ratelimit-input-tokens-reset"
            ),
            outputTokens: Quota.parse(
                from: response,
                limitKey: "anthropic-ratelimit-output-tokens-limit",
                remainingKey: "anthropic-ratelimit-output-tokens-remaining",
                resetKey: "anthropic-ratelimit-output-tokens-reset"
            )
        )
    }

    /// 4개 Quota가 모두 nil이면 true.
    var isEmpty: Bool {
        requests == nil && tokens == nil && inputTokens == nil && outputTokens == nil
    }
}

nonisolated extension RateLimitState.Quota {
    /// HTTP 응답 헤더 3개(limit / remaining / reset)를 읽어 Quota를 생성한다.
    /// - reset은 ISO8601 문자열로 온다 (예: `2026-04-14T14:00:00Z`).
    static func parse(
        from response: HTTPURLResponse,
        limitKey: String,
        remainingKey: String,
        resetKey: String
    ) -> RateLimitState.Quota? {
        guard
            let limitString = response.value(forHTTPHeaderField: limitKey),
            let remainingString = response.value(forHTTPHeaderField: remainingKey),
            let resetString = response.value(forHTTPHeaderField: resetKey),
            let limit = Int(limitString),
            let remaining = Int(remainingString),
            let resetsAt = try? Date(resetString, strategy: .iso8601)
        else {
            return nil
        }

        return RateLimitState.Quota(
            limit: limit,
            remaining: remaining,
            resetsAt: resetsAt
        )
    }
}

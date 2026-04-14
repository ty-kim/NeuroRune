//
//  LLMErrorTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
@testable import NeuroRune

struct LLMErrorTests {

    @Test("LLMError는 6개 케이스를 가진다: unauthorized, rateLimited, network, decoding, server, cancelled")
    func llmErrorHasSixCases() {
        let cases: [LLMError] = [
            .unauthorized,
            .rateLimited(retryAfter: nil, state: nil),
            .network("timeout"),
            .decoding("invalid json"),
            .server(status: 500, message: "Internal server error"),
            .cancelled
        ]

        #expect(cases.count == 6)
    }

    @Test("LLMError는 Equatable이다")
    func llmErrorIsEquatable() {
        #expect(LLMError.unauthorized == LLMError.unauthorized)
        #expect(LLMError.rateLimited(retryAfter: nil, state: nil)
                == LLMError.rateLimited(retryAfter: nil, state: nil))
        #expect(LLMError.network("timeout") == LLMError.network("timeout"))
        #expect(LLMError.network("timeout") != LLMError.network("offline"))
        #expect(LLMError.decoding("bad json") == LLMError.decoding("bad json"))
        #expect(LLMError.server(status: 500, message: "Internal server error") == LLMError.server(status: 500, message: "Internal server error"))
        #expect(LLMError.server(status: 500, message: "Internal server error") != LLMError.server(status: 503, message: "Service unavailable"))
        #expect(LLMError.unauthorized != LLMError.rateLimited(retryAfter: nil, state: nil))
        #expect(LLMError.cancelled == LLMError.cancelled)
    }

    @Test("rateLimited는 retryAfter/state가 다르면 동등하지 않다")
    func rateLimitedVariantsAreDistinct() {
        #expect(LLMError.rateLimited(retryAfter: 10, state: nil)
                != LLMError.rateLimited(retryAfter: 20, state: nil))
        #expect(LLMError.rateLimited(retryAfter: nil, state: nil)
                != LLMError.rateLimited(retryAfter: 10, state: nil))
    }

    // MARK: - isRetryable

    @Test("cancelled만 isRetryable == false")
    func onlyCancelledIsNotRetryable() {
        #expect(LLMError.cancelled.isRetryable == false)

        #expect(LLMError.unauthorized.isRetryable == true)
        #expect(LLMError.rateLimited(retryAfter: nil, state: nil).isRetryable == true)
        #expect(LLMError.network("x").isRetryable == true)
        #expect(LLMError.decoding("x").isRetryable == true)
        #expect(LLMError.server(status: 500, message: "x").isRetryable == true)
    }
}

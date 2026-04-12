//
//  LLMErrorTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
@testable import NeuroRune

struct LLMErrorTests {

    @Test("LLMError는 5개 케이스를 가진다: unauthorized, rateLimited, network, decoding, server")
    func llmErrorHasFiveCases() {
        let cases: [LLMError] = [
            .unauthorized,
            .rateLimited,
            .network("timeout"),
            .decoding("invalid json"),
            .server(status: 500, message: "Internal server error")
        ]

        #expect(cases.count == 5)
    }

    @Test("LLMError는 Equatable이다")
    func llmErrorIsEquatable() {
        #expect(LLMError.unauthorized == LLMError.unauthorized)
        #expect(LLMError.rateLimited == LLMError.rateLimited)
        #expect(LLMError.network("timeout") == LLMError.network("timeout"))
        #expect(LLMError.network("timeout") != LLMError.network("offline"))
        #expect(LLMError.decoding("bad json") == LLMError.decoding("bad json"))
        #expect(LLMError.server(status: 500, message: "Internal server error") == LLMError.server(status: 500, message: "Internal server error"))
        #expect(LLMError.server(status: 500, message: "Internal server error") != LLMError.server(status: 503, message: "Service unavailable"))
        #expect(LLMError.unauthorized != LLMError.rateLimited)
    }
}

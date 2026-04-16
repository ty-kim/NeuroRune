//
//  ConsolidationClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 23 Slice 3a — LLM 응답 파서 + generate 통합 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct ConsolidationClientTests {

    // MARK: - parseResponse (순수)

    @Test("parseResponse: 깨끗한 JSON 파싱")
    func parsesCleanJSON() throws {
        let raw = #"{"proposals":[]}"#
        let r = try ConsolidationClient.parseResponse(raw)
        #expect(r.proposals.isEmpty)
    }

    @Test("parseResponse: ```json 코드 펜스 제거")
    func stripsJSONFence() throws {
        let raw = """
        ```json
        {"proposals": [
          {"action":"create","path":"memory/a.md","rationale":"r","content":"c"}
        ]}
        ```
        """
        let r = try ConsolidationClient.parseResponse(raw)
        #expect(r.proposals.count == 1)
        #expect(r.proposals[0].action == .create)
    }

    @Test("parseResponse: 일반 ``` 코드 펜스 제거")
    func stripsGenericFence() throws {
        let raw = """
        ```
        {"proposals": []}
        ```
        """
        let r = try ConsolidationClient.parseResponse(raw)
        #expect(r.proposals.isEmpty)
    }

    @Test("parseResponse: preamble이 붙어있어도 { ... } 추출")
    func extractsFromPreamble() throws {
        let raw = "여기 결과입니다:\n{\"proposals\":[]}\n감사합니다."
        let r = try ConsolidationClient.parseResponse(raw)
        #expect(r.proposals.isEmpty)
    }

    @Test("parseResponse: 완전히 비JSON이면 invalidJSON throw")
    func throwsOnGarbage() {
        let raw = "죄송합니다, 도움이 어려워요."
        #expect(throws: ConsolidationError.self) {
            _ = try ConsolidationClient.parseResponse(raw)
        }
    }
}

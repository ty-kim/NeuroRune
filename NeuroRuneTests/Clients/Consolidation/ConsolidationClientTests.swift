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
import Dependencies
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

    // MARK: - liveValue.generate 통합

    @Test("generate: LLM 호출 시 system에 안티바디·user에 입력 전달, 응답 파싱")
    func generateWiresPromptAndParsesResult() async throws {
        let recorded = LockIsolated<(system: String?, user: String?, model: LLMModel?)>((nil, nil, nil))

        let fakeLLM = LLMClient(streamMessage: { msgs, model, _, sys, _ in
            let userText: String? = {
                guard let first = msgs.first else { return nil }
                if case let .text(text) = first.content { return text }
                return nil
            }()
            recorded.setValue((sys, userText, model))
            return AsyncThrowingStream { cont in
                cont.yield(.textDelta(#"{"proposals":[]}"#))
                cont.finish()
            }
        })

        let input = ConsolidationInput(
            conversations: [.init(title: "t", date: Date(timeIntervalSince1970: 0), text: "SWOT 먼저")],
            memoryIndex: "# Idx",
            memoryFiles: []
        )

        let result = try await withDependencies {
            $0.llmClient = fakeLLM
        } operation: {
            try await ConsolidationClient.liveValue.generate(input)
        }

        #expect(result.proposals.isEmpty)
        let call = recorded.value
        #expect(call.system?.contains("제안 없음") == true)
        #expect(call.user?.contains("SWOT 먼저") == true)
        #expect(call.model == .sonnet46)
    }

    @Test("generate: stream 에러면 llmFailed throw")
    func generatePropagatesStreamError() async {
        struct Boom: Error {}
        let fakeLLM = LLMClient(streamMessage: { _, _, _, _, _ in
            AsyncThrowingStream { cont in
                cont.finish(throwing: Boom())
            }
        })
        let input = ConsolidationInput(conversations: [], memoryIndex: "", memoryFiles: [])

        await #expect(throws: ConsolidationError.self) {
            try await withDependencies {
                $0.llmClient = fakeLLM
            } operation: {
                try await ConsolidationClient.liveValue.generate(input)
            }
        }
    }
}

//
//  ConsolidationProposalTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 23 Slice 1 — Consolidation 도메인 모델 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct ConsolidationProposalTests {

    @Test("JSON 한 건 디코딩: action=create + path + rationale + content")
    func decodesSingleCreateProposal() throws {
        let json = """
        {
          "action": "create",
          "path": "memory/rune_decision.md",
          "rationale": "Apr 13 대화에서 반복된 패턴",
          "content": "# Rune: Decision\\n결정 지연 시 SWOT..."
        }
        """.data(using: .utf8)!

        let p = try JSONDecoder().decode(ConsolidationProposal.self, from: json)
        #expect(p.action == .create)
        #expect(p.path == "memory/rune_decision.md")
        #expect(p.rationale.contains("Apr 13"))
        #expect(p.content?.hasPrefix("# Rune") == true)
        #expect(p.beforeContent == nil)
    }

    @Test("ConsolidationResult: 빈 proposals 배열 디코딩")
    func decodesEmptyResult() throws {
        let json = #"{"proposals":[]}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(ConsolidationResult.self, from: json)
        #expect(r.proposals.isEmpty)
    }

    @Test("ConsolidationResult: create + update 혼합 디코딩")
    func decodesMixedResult() throws {
        let json = """
        {
          "proposals": [
            { "action": "create", "path": "memory/a.md", "rationale": "r1", "content": "c1" },
            { "action": "update", "path": "memory/b.md", "rationale": "r2",
              "content": "new", "beforeContent": "old" },
            { "action": "skip", "path": "memory/c.md", "rationale": "r3" }
          ]
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(ConsolidationResult.self, from: json)
        #expect(r.proposals.count == 3)
        #expect(r.proposals[1].beforeContent == "old")
        #expect(r.proposals[2].action == .skip)
        #expect(r.proposals[2].content == nil)
    }
}

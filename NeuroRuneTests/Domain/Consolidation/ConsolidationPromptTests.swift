//
//  ConsolidationPromptTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 23 Slice 2 — 프롬프트 빌더. 핵심 불변식(안티바디/빈 결과 허용/JSON 스키마) 검증.
//

import Foundation
import Testing
@testable import NeuroRune

struct ConsolidationPromptTests {

    private func sampleInput() -> ConsolidationInput {
        ConsolidationInput(
            conversations: [
                .init(title: "결정 패턴", date: Date(timeIntervalSince1970: 0),
                      text: "user: 뭐부터 할까\nassistant: SWOT 먼저")
            ],
            memoryIndex: "# Index\n- [x](x.md)",
            memoryFiles: [
                .init(path: "feedback_ai_overpraise.md", content: "약장수 4패턴...")
            ]
        )
    }

    @Test("system 프롬프트: '제안 없음이 정상' 문구 포함 (억지 정제 방지)")
    func systemContainsNoProposalsNormal() {
        let (system, _) = ConsolidationPrompt.build(sampleInput())
        #expect(system.contains("제안 없음"))
    }

    @Test("system 프롬프트: JSON 출력 스키마 명시 (proposals 키)")
    func systemSpecifiesJSONSchema() {
        let (system, _) = ConsolidationPrompt.build(sampleInput())
        #expect(system.contains("\"proposals\""))
        #expect(system.contains("\"action\""))
    }

    @Test("user 프롬프트: 대화 본문 + 메모리 인덱스 + 파일 포함")
    func userEmbedsInputs() {
        let (_, user) = ConsolidationPrompt.build(sampleInput())
        #expect(user.contains("SWOT 먼저"))
        #expect(user.contains("# Index"))
        #expect(user.contains("feedback_ai_overpraise.md"))
        #expect(user.contains("약장수 4패턴"))
    }

    @Test("빈 입력도 유효한 프롬프트 반환 (크래시 X)")
    func emptyInputProducesValidPrompts() {
        let empty = ConsolidationInput(conversations: [], memoryIndex: "", memoryFiles: [])
        let (system, user) = ConsolidationPrompt.build(empty)
        #expect(!system.isEmpty)
        #expect(!user.isEmpty)
    }
}

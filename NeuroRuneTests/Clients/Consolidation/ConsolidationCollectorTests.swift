//
//  ConsolidationCollectorTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 23 Slice 3c — 대화·메모리 입력 수집 + 순수 helper.
//

import Foundation
import Testing
@testable import NeuroRune

struct ConsolidationCollectorTests {

    // MARK: - parseMemoryReferences

    @Test("parseMemoryReferences: 마크다운 링크에서 .md 파일 경로 추출")
    func extractsMDLinks() {
        let md = """
        # Index
        - [x](x.md) — 설명
        - [y](memory/y.md)
        - [z](https://example.com) — 외부 링크 제외
        - [w](w.txt) — 비 md 제외
        """
        let refs = ConsolidationCollector.parseMemoryReferences(md)
        #expect(refs == ["x.md", "memory/y.md"])
    }

    @Test("parseMemoryReferences: 앵커(#section) 제거하고 파일 경로만")
    func stripsAnchor() {
        let md = "- [sec](file.md#heading)"
        let refs = ConsolidationCollector.parseMemoryReferences(md)
        #expect(refs == ["file.md"])
    }

    @Test("parseMemoryReferences: 중복 제거")
    func dedupes() {
        let md = """
        - [a](x.md)
        - [b](x.md)
        """
        let refs = ConsolidationCollector.parseMemoryReferences(md)
        #expect(refs == ["x.md"])
    }

    @Test("parseMemoryReferences: 링크 없으면 빈 배열")
    func emptyWhenNoLinks() {
        #expect(ConsolidationCollector.parseMemoryReferences("# Just a header").isEmpty)
    }

    // MARK: - transcript 변환

    @Test("transcript: 각 메시지를 role: content 형식으로 직렬화")
    func buildsTranscript() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let conv = Conversation(
            id: UUID(),
            title: "결정 패턴",
            messages: [
                Message(role: .user, content: "뭐부터?", createdAt: now),
                Message(role: .assistant, content: "SWOT 먼저", createdAt: now),
            ],
            modelId: "claude-sonnet",
            createdAt: now
        )
        let t = ConsolidationCollector.makeTranscript(from: conv)
        #expect(t.title == "결정 패턴")
        #expect(t.text.contains("user: 뭐부터?"))
        #expect(t.text.contains("assistant: SWOT 먼저"))
    }

    // MARK: - recent 필터

    @Test("filterRecent: 지정 일수 내 대화만 남김")
    func filtersByRecency() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let eightDaysAgo = now.addingTimeInterval(-8 * 86_400)
        let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)

        let old = Conversation(id: UUID(), title: "o", messages: [], modelId: "m", createdAt: eightDaysAgo)
        let fresh = Conversation(id: UUID(), title: "f", messages: [], modelId: "m", createdAt: twoDaysAgo)

        let kept = ConsolidationCollector.filterRecent([old, fresh], now: now, days: 7)
        #expect(kept.count == 1)
        #expect(kept.first?.title == "f")
    }
}

//
//  RateLimitBadgeTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  RateLimitBadge의 순수 의사결정 함수(display, countdownText)를 검증.
//  View 렌더링은 Preview로 수동 검증.
//

import Foundation
import Testing
@testable import NeuroRune

struct RateLimitBadgeTests {

    // MARK: - display(for:) — level 결정

    @Test func remaining이_20퍼센트_이상이면_nil() {
        let state = RateLimitState(
            tokens: quota(limit: 1000, remaining: 300)  // 30%
        )
        #expect(RateLimitBadge.display(for: state) == nil)
    }

    @Test func remaining이_20퍼센트_미만_5퍼센트_이상이면_warning() {
        let state = RateLimitState(
            tokens: quota(limit: 1000, remaining: 150)  // 15%
        )
        let display = RateLimitBadge.display(for: state)
        #expect(display?.level == .warning)
    }

    @Test func remaining이_5퍼센트_미만이면_critical() {
        let state = RateLimitState(
            tokens: quota(limit: 1000, remaining: 30)  // 3%
        )
        let display = RateLimitBadge.display(for: state)
        #expect(display?.level == .critical)
    }

    @Test func remaining이_0이면_critical() {
        let state = RateLimitState(
            tokens: quota(limit: 1000, remaining: 0)
        )
        let display = RateLimitBadge.display(for: state)
        #expect(display?.level == .critical)
    }

    @Test func 경계값_정확히_20퍼센트면_숨김() {
        let state = RateLimitState(
            tokens: quota(limit: 1000, remaining: 200)  // 20%
        )
        #expect(RateLimitBadge.display(for: state) == nil)
    }

    @Test func 경계값_정확히_5퍼센트면_warning() {
        let state = RateLimitState(
            tokens: quota(limit: 1000, remaining: 50)  // 5%
        )
        let display = RateLimitBadge.display(for: state)
        #expect(display?.level == .warning)
    }

    // MARK: - display(for:) — 가장 여유 없는 Quota 선택

    @Test func 가장_여유_없는_Quota를_선택한다() {
        let state = RateLimitState(
            requests: quota(limit: 1000, remaining: 500),   // 50%
            tokens: quota(limit: 1000, remaining: 100),     // 10% ← 가장 여유 없음
            inputTokens: quota(limit: 1000, remaining: 800), // 80%
            outputTokens: quota(limit: 1000, remaining: 250) // 25%
        )
        let display = RateLimitBadge.display(for: state)
        #expect(display?.kind == .tokens)
        #expect(display?.level == .warning)
    }

    @Test func outputTokens가_가장_tight일_때_선택() {
        let state = RateLimitState(
            outputTokens: quota(limit: 8000, remaining: 100)  // 1.25%
        )
        let display = RateLimitBadge.display(for: state)
        #expect(display?.kind == .outputTokens)
        #expect(display?.level == .critical)
    }

    @Test func 동률일_때_우선순위는_output_tokens_inputTokens_requests() {
        // 모두 10% remaining
        let state = RateLimitState(
            requests: quota(limit: 1000, remaining: 100),
            tokens: quota(limit: 1000, remaining: 100),
            inputTokens: quota(limit: 1000, remaining: 100),
            outputTokens: quota(limit: 1000, remaining: 100)
        )
        let display = RateLimitBadge.display(for: state)
        // min(by:)는 첫 발견 minimum 유지, 배열 순서대로 output → tokens → input → requests
        #expect(display?.kind == .outputTokens)
    }

    @Test func 빈_RateLimitState는_nil() {
        let display = RateLimitBadge.display(for: RateLimitState())
        #expect(display == nil)
    }

    @Test func 여유_충분한_Quota들만_있으면_nil() {
        let state = RateLimitState(
            requests: quota(limit: 1000, remaining: 900),
            tokens: quota(limit: 1000, remaining: 800)
        )
        #expect(RateLimitBadge.display(for: state) == nil)
    }

    // MARK: - countdownText

    @Test func countdown은_1분_이내이면_mm_ss_포맷() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = now.addingTimeInterval(45)
        #expect(RateLimitBadge.countdownText(to: reset, at: now) == "00:45")
    }

    @Test func countdown은_분_단위면_mm_ss() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = now.addingTimeInterval(125)  // 2분 5초
        #expect(RateLimitBadge.countdownText(to: reset, at: now) == "02:05")
    }

    @Test func countdown은_1시간_넘으면_HH_mm_ss() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = now.addingTimeInterval(3725)  // 1:02:05
        #expect(RateLimitBadge.countdownText(to: reset, at: now) == "01:02:05")
    }

    @Test func countdown은_이미_지났으면_00_00() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = now.addingTimeInterval(-10)
        #expect(RateLimitBadge.countdownText(to: reset, at: now) == "00:00")
    }

    @Test func countdown은_정확히_0이면_00_00() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(RateLimitBadge.countdownText(to: now, at: now) == "00:00")
    }

    // MARK: - Helper

    private func quota(limit: Int, remaining: Int) -> RateLimitState.Quota {
        RateLimitState.Quota(
            limit: limit,
            remaining: remaining,
            resetsAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

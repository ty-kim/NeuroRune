//
//  RateLimitStateTests.swift
//  NeuroRuneTests
//

import Foundation
import Testing
@testable import NeuroRune

struct RateLimitStateTests {

    // MARK: - Quota 기본

    @Test func Quota는_limit_remaining_resetsAt을_가진다() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let quota = RateLimitState.Quota(limit: 1000, remaining: 800, resetsAt: date)
        #expect(quota.limit == 1000)
        #expect(quota.remaining == 800)
        #expect(quota.resetsAt == date)
    }

    @Test func percentRemaining은_remaining을_limit으로_나눈_값이다() {
        let quota = RateLimitState.Quota(limit: 1000, remaining: 250, resetsAt: .now)
        #expect(quota.percentRemaining == 0.25)
    }

    @Test func percentRemaining은_limit이_0이면_0() {
        let quota = RateLimitState.Quota(limit: 0, remaining: 0, resetsAt: .now)
        #expect(quota.percentRemaining == 0.0)
    }

    @Test func percentRemaining은_모두_소진일_때_0() {
        let quota = RateLimitState.Quota(limit: 1000, remaining: 0, resetsAt: .now)
        #expect(quota.percentRemaining == 0.0)
    }

    @Test func percentRemaining은_전부_남았을_때_1() {
        let quota = RateLimitState.Quota(limit: 1000, remaining: 1000, resetsAt: .now)
        #expect(quota.percentRemaining == 1.0)
    }

    // MARK: - RateLimitState 기본

    @Test func 기본_RateLimitState는_모든_Quota가_nil이다() {
        let state = RateLimitState()
        #expect(state.requests == nil)
        #expect(state.tokens == nil)
        #expect(state.inputTokens == nil)
        #expect(state.outputTokens == nil)
        #expect(state.isEmpty == true)
    }

    @Test func 하나라도_Quota가_있으면_isEmpty는_false() {
        let state = RateLimitState(
            tokens: .init(limit: 100, remaining: 50, resetsAt: .now)
        )
        #expect(state.isEmpty == false)
    }

    // MARK: - parse(from: HTTPURLResponse)

    @Test func parse는_4개_Quota를_모두_추출한다() throws {
        let headers = [
            "anthropic-ratelimit-requests-limit": "1000",
            "anthropic-ratelimit-requests-remaining": "942",
            "anthropic-ratelimit-requests-reset": "2026-04-14T14:00:00Z",
            "anthropic-ratelimit-tokens-limit": "80000",
            "anthropic-ratelimit-tokens-remaining": "62400",
            "anthropic-ratelimit-tokens-reset": "2026-04-14T14:00:00Z",
            "anthropic-ratelimit-input-tokens-limit": "40000",
            "anthropic-ratelimit-input-tokens-remaining": "38500",
            "anthropic-ratelimit-input-tokens-reset": "2026-04-14T14:00:00Z",
            "anthropic-ratelimit-output-tokens-limit": "8000",
            "anthropic-ratelimit-output-tokens-remaining": "7200",
            "anthropic-ratelimit-output-tokens-reset": "2026-04-14T14:00:00Z"
        ]
        let response = makeResponse(headers: headers)

        let state = RateLimitState.parse(from: response)

        #expect(state.requests?.limit == 1000)
        #expect(state.requests?.remaining == 942)
        #expect(state.tokens?.limit == 80000)
        #expect(state.tokens?.remaining == 62400)
        #expect(state.inputTokens?.limit == 40000)
        #expect(state.inputTokens?.remaining == 38500)
        #expect(state.outputTokens?.limit == 8000)
        #expect(state.outputTokens?.remaining == 7200)
    }

    @Test func parse는_헤더_누락된_Quota는_nil() throws {
        let headers = [
            "anthropic-ratelimit-tokens-limit": "80000",
            "anthropic-ratelimit-tokens-remaining": "62400",
            "anthropic-ratelimit-tokens-reset": "2026-04-14T14:00:00Z"
        ]
        let response = makeResponse(headers: headers)

        let state = RateLimitState.parse(from: response)

        #expect(state.tokens != nil)
        #expect(state.requests == nil)
        #expect(state.inputTokens == nil)
        #expect(state.outputTokens == nil)
    }

    @Test func parse는_limit만_있고_remaining_reset없으면_해당_Quota_nil() throws {
        let headers = [
            "anthropic-ratelimit-tokens-limit": "80000"
        ]
        let response = makeResponse(headers: headers)

        let state = RateLimitState.parse(from: response)

        #expect(state.tokens == nil)
    }

    @Test func parse는_limit이_숫자_아니면_해당_Quota_nil() throws {
        let headers = [
            "anthropic-ratelimit-tokens-limit": "not-a-number",
            "anthropic-ratelimit-tokens-remaining": "62400",
            "anthropic-ratelimit-tokens-reset": "2026-04-14T14:00:00Z"
        ]
        let response = makeResponse(headers: headers)

        let state = RateLimitState.parse(from: response)

        #expect(state.tokens == nil)
    }

    @Test func parse는_reset이_ISO8601이_아니면_해당_Quota_nil() throws {
        let headers = [
            "anthropic-ratelimit-tokens-limit": "80000",
            "anthropic-ratelimit-tokens-remaining": "62400",
            "anthropic-ratelimit-tokens-reset": "invalid-date"
        ]
        let response = makeResponse(headers: headers)

        let state = RateLimitState.parse(from: response)

        #expect(state.tokens == nil)
    }

    @Test func parse는_빈_응답에서_모든_Quota_nil() throws {
        let response = makeResponse(headers: [:])
        let state = RateLimitState.parse(from: response)
        #expect(state.isEmpty == true)
    }

    @Test func parse는_ISO8601_reset_문자열을_Date로_파싱한다() throws {
        let headers = [
            "anthropic-ratelimit-tokens-limit": "80000",
            "anthropic-ratelimit-tokens-remaining": "62400",
            "anthropic-ratelimit-tokens-reset": "2026-04-14T14:00:00Z"
        ]
        let response = makeResponse(headers: headers)

        let state = RateLimitState.parse(from: response)

        let expected = try Date("2026-04-14T14:00:00Z", strategy: .iso8601)
        #expect(state.tokens?.resetsAt == expected)
    }

    // MARK: - Helpers

    private func makeResponse(headers: [String: String]) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }
}

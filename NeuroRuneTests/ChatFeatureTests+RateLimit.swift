//
//  ChatFeatureTests+RateLimit.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 18 — rate limit 상태 도입/갱신 관련 ChatFeature 테스트.
//  (errorOccurred에서 rateLimit 추출은 +Errors.swift)
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

extension ChatFeatureTests {

    @Test("초기 state.rateLimit은 nil이다")
    func initialRateLimitIsNil() {
        let state = makeState()
        #expect(state.rateLimit == nil)
    }

    @Test("rateLimitUpdated는 state.rateLimit에 저장한다")
    func rateLimitUpdatedStoresState() async {
        let quota = RateLimitState.Quota(
            limit: 80000,
            remaining: 62400,
            resetsAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let rateLimit = RateLimitState(tokens: quota)
        let store = TestStore(initialState: makeState()) { ChatFeature() }

        await store.send(.rateLimitUpdated(rateLimit)) {
            $0.rateLimit = rateLimit
        }
    }

    @Test("rateLimitUpdated는 기존 값 덮어쓴다")
    func rateLimitUpdatedOverwritesPrevious() async {
        var state = makeState()
        state.rateLimit = RateLimitState(
            tokens: .init(limit: 80000, remaining: 50000, resetsAt: .now)
        )
        let newRateLimit = RateLimitState(
            tokens: .init(limit: 80000, remaining: 30000, resetsAt: .now)
        )
        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.rateLimitUpdated(newRateLimit)) {
            $0.rateLimit = newRateLimit
        }
    }
}

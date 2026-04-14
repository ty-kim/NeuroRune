//
//  ChatFeatureTests+Errors.swift
//  NeuroRuneTests
//
//  Phase 19에서 도입된 에러 복구 UX 관련 ChatFeature 테스트.
//  errorDismissed, errorOccurred(rateLimit 추출), retryTapped 변형 3개.
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

extension ChatFeatureTests {

    @Test("errorDismissed는 error를 nil로 만든다")
    func errorDismissedClearsError() async {
        var state = makeState()
        state.error = .network("offline")
        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.errorDismissed) {
            $0.error = nil
        }
    }

    @Test("errorOccurred(.rateLimited(_, state?))는 rateLimit 상태도 갱신한다")
    func errorOccurredExtractsRateLimit() async {
        let quota = RateLimitState.Quota(
            limit: 80000, remaining: 0,
            resetsAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let rateLimit = RateLimitState(tokens: quota)
        let llmError = LLMError.rateLimited(retryAfter: 25, state: rateLimit)

        let store = TestStore(initialState: makeState(isStreaming: true)) { ChatFeature() }

        await store.send(.errorOccurred(llmError)) {
            $0.error = llmError
            $0.isStreaming = false
            $0.rateLimit = rateLimit
        }
    }

    @Test("errorOccurred(.rateLimited(_, nil))는 rateLimit을 건드리지 않는다")
    func errorOccurredRateLimitedWithoutStateKeepsExisting() async {
        let existing = RateLimitState(
            tokens: .init(limit: 80000, remaining: 50000, resetsAt: .now)
        )
        var state = makeState(isStreaming: true)
        state.rateLimit = existing

        let store = TestStore(initialState: state) { ChatFeature() }
        let llmError = LLMError.rateLimited(retryAfter: nil, state: nil)

        await store.send(.errorOccurred(llmError)) {
            $0.error = llmError
            $0.isStreaming = false
            // rateLimit 기존 값 유지
        }
    }

    @Test("retryTapped는 마지막 user 메시지를 꺼내 inputText로 복원하고 error를 클리어한다")
    func retryTappedRedispatchesLastUserMessage() async {
        var state = makeState()
        state.conversation = state.conversation
            .appending(Message(role: .user, content: "hi again", createdAt: Self.fixedDate))
        state.error = .network("timeout")

        let store = TestStore(initialState: state) {
            ChatFeature()
        } withDependencies: {
            // retryTapped는 sendTapped effect를 즉시 발사. sendTapped가 llmClient를
            // 건드리므로, 빈 stream을 반환하는 mock으로 대체.
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, _, _, _ in
                AsyncThrowingStream { $0.finish() }
            }
            $0.conversationStore.save = { @Sendable _ in }
            $0.githubCredentialsClient.load = { @Sendable _ in nil }
        }
        store.exhaustivity = .off

        await store.send(.retryTapped) {
            $0.error = nil
            $0.conversation = $0.conversation.droppingLastMessage()
            $0.inputText = "hi again"
        }
        await store.finish()
    }

    @Test("retryTapped는 마지막이 user가 아니면 아무 동작 안 함")
    func retryTappedNoOpWhenLastIsNotUser() async {
        var state = makeState()
        state.conversation = state.conversation
            .appending(Message(role: .assistant, content: "hello", createdAt: Self.fixedDate))
        state.error = .network("timeout")

        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.retryTapped)  // no state change expected
    }

    @Test("retryTapped는 메시지가 없으면 아무 동작 안 함")
    func retryTappedNoOpWhenEmpty() async {
        let state = makeState()  // 메시지 없음
        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.retryTapped)
    }
}

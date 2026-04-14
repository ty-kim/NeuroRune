//
//  ChatFeatureTests+Cancel.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 20 — 스트리밍 중 취소 (Stop 버튼) 테스트.
//  stopTapped 액션이 CancelID.streaming 을 취소하고, effect가
//  streamFinished 경로로 partial 응답을 보존하는지 검증.
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

extension ChatFeatureTests {

    @Test("isStreaming == false 일 때 stopTapped는 no-op")
    func stopTappedNoOpWhenNotStreaming() async {
        let store = TestStore(initialState: makeState(isStreaming: false)) {
            ChatFeature()
        }
        await store.send(.stopTapped)
    }

    @Test("stopTapped는 streaming effect를 취소하고 partial 응답이 보존된 채 streamFinished로 귀결된다")
    func stopTappedCancelsStreamAndPreservesPartial() async {
        // 끝나지 않는 stream 준비: 한 chunk만 emit 후 suspend
        let store = TestStore(
            initialState: makeState(inputText: "hello")
        ) {
            ChatFeature()
        } withDependencies: {
            applyDefaultDependencies(&$0)
            $0.uuid = .incrementing
            // 기본 llmClient를 "끝나지 않는 stream"으로 덮어씀 — 취소 대상 만들기.
            $0.llmClient.streamMessage = { @Sendable _, _, _, _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(.textDelta("partial"))
                    continuation.onTermination = { _ in }
                }
            }
        }

        await store.send(.sendTapped) {
            $0.inputText = ""
            $0.isStreaming = true
            $0.conversation = $0.conversation
                .appending(Self.userMsg("hello"))
                .appending(Self.assistantMsg())
        }

        // stream 첫 chunk가 reducer state에 반영될 때까지 기다림.
        await store.receive(.streamChunkReceived("partial")) {
            var messages = $0.conversation.messages
            messages[messages.count - 1] = Self.assistantMsg("partial")
            $0.conversation.messages = messages
        }

        // 취소 — stopTapped로 effect cancel 후 streamFinished 경로로 종료.
        await store.send(.stopTapped)

        await store.receive(.streamFinished) {
            $0.isStreaming = false
        }

        await store.finish()

        // partial 응답 보존 — 마지막 assistant는 "partial"로 남아야 함.
        // isStreaming도 false로 정리.
        let last = store.state.conversation.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.content == "partial")
        #expect(store.state.isStreaming == false)
    }
}

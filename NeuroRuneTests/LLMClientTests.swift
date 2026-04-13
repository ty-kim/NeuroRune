//
//  LLMClientTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import Dependencies
@testable import NeuroRune

struct LLMClientTests {

    @Test("LLMClient는 streamMessage 클로저를 통해 chunk 시퀀스를 반환한다")
    func llmClientStreamMessageYieldsChunks() async throws {
        let stub = LLMClient(
            streamMessage: { _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield("hello ")
                    continuation.yield("world")
                    continuation.finish()
                }
            }
        )

        var collected = ""
        let stream = try await stub.streamMessage([], .opus46)
        for try await chunk in stream {
            collected += chunk
        }

        #expect(collected == "hello world")
    }

    @Test("LLMClient는 TCA DependencyKey로 등록되어 있다")
    func llmClientIsRegisteredAsDependency() async throws {
        let injected = LLMClient(
            streamMessage: { _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield("injected")
                    continuation.finish()
                }
            }
        )

        let collected = try await withDependencies {
            $0.llmClient = injected
        } operation: {
            @Dependency(\.llmClient) var client
            var text = ""
            let stream = try await client.streamMessage([], .sonnet46)
            for try await chunk in stream {
                text += chunk
            }
            return text
        }

        #expect(collected == "injected")
    }
}

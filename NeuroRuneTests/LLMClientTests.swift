//
//  LLMClientTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import Dependencies
@testable import NeuroRune

struct LLMClientTests {

    @Test("LLMClient는 sendMessage 클로저를 통해 Message를 반환할 수 있다")
    func llmClientSendMessageReturnsMessage() async throws {
        let stub = LLMClient(
            sendMessage: { _, _ in
                Message(role: .assistant, content: "stub response", createdAt: Date(timeIntervalSince1970: 1_000_000))
            },
            streamMessage: { _, _ in AsyncThrowingStream { $0.finish() } }
        )

        let result = try await stub.sendMessage([], .opus46)

        #expect(result.role == .assistant)
        #expect(result.content == "stub response")
    }

    @Test("LLMClient는 TCA DependencyKey로 등록되어 있다")
    func llmClientIsRegisteredAsDependency() async throws {
        let injected = LLMClient(
            sendMessage: { _, _ in
                Message(role: .assistant, content: "injected", createdAt: Date(timeIntervalSince1970: 2_000_000))
            },
            streamMessage: { _, _ in AsyncThrowingStream { $0.finish() } }
        )

        let result = try await withDependencies {
            $0.llmClient = injected
        } operation: {
            @Dependency(\.llmClient) var client
            return try await client.sendMessage([], .sonnet46)
        }

        #expect(result.content == "injected")
    }
}

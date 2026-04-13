//
//  LLMClient.swift
//  NeuroRune
//

import Foundation
import Dependencies
import os

nonisolated struct LLMClient: Sendable {
    var sendMessage: @Sendable ([Message], LLMModel) async throws -> Message
    var streamMessage: @Sendable ([Message], LLMModel) async throws -> AsyncThrowingStream<String, Error>
}

nonisolated extension LLMClient: DependencyKey {
    static let liveValue: LLMClient = {
        LLMClient(
            sendMessage: { messages, model in
                let apiKey = try loadAnthropicAPIKey()
                Logger.llm.info("send, model: \(model.id, privacy: .public), messages: \(messages.count)")
                let client = LLMClient.anthropic(session: .shared, apiKey: apiKey)
                let reply = try await client.sendMessage(messages, model)
                Logger.llm.info("received reply, length: \(reply.content.count)")
                return reply
            },
            streamMessage: { messages, model in
                let apiKey = try loadAnthropicAPIKey()
                Logger.llm.info("stream, model: \(model.id, privacy: .public), messages: \(messages.count)")
                let client = LLMClient.anthropic(session: .shared, apiKey: apiKey)
                return try await client.streamMessage(messages, model)
            }
        )
    }()

    private static func loadAnthropicAPIKey() throws -> String {
        guard let apiKey = try KeychainClient.liveValue.load(OnboardingFeature.anthropicKeyName) else {
            Logger.llm.error("api key not found")
            throw LLMError.unauthorized
        }
        return apiKey
    }

    static let testValue = LLMClient(
        sendMessage: unimplemented("LLMClient.sendMessage"),
        streamMessage: unimplemented("LLMClient.streamMessage")
    )

    static let previewValue = LLMClient(
        sendMessage: { _, _ in
            Message(
                role: .assistant,
                content: "Preview response from Claude.",
                createdAt: Date()
            )
        },
        streamMessage: { _, _ in
            AsyncThrowingStream { continuation in
                Task {
                    for chunk in ["Preview ", "response ", "from ", "Claude."] {
                        continuation.yield(chunk)
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    continuation.finish()
                }
            }
        }
    )
}

extension DependencyValues {
    nonisolated var llmClient: LLMClient {
        get { self[LLMClient.self] }
        set { self[LLMClient.self] = newValue }
    }
}

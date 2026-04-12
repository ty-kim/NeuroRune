//
//  LLMClient.swift
//  NeuroRune
//

import Foundation
import Dependencies
import os

nonisolated struct LLMClient: Sendable {
    var sendMessage: @Sendable ([Message], LLMModel) async throws -> Message
}

nonisolated extension LLMClient: DependencyKey {
    static let liveValue: LLMClient = {
        let keychainClient = KeychainClient.liveValue
        return LLMClient(
            sendMessage: { messages, model in
                guard let apiKey = try keychainClient.load(OnboardingFeature.anthropicKeyName) else {
                    Logger.llm.error("api key not found")
                    throw LLMError.unauthorized
                }
                Logger.llm.info("send, model: \(model.id, privacy: .public), messages: \(messages.count)")
                let client = LLMClient.anthropic(session: .shared, apiKey: apiKey)
                let reply = try await client.sendMessage(messages, model)
                Logger.llm.info("received reply, length: \(reply.content.count)")
                return reply
            }
        )
    }()

    static let testValue = LLMClient(
        sendMessage: unimplemented("LLMClient.sendMessage")
    )

    static let previewValue = LLMClient(
        sendMessage: { _, _ in
            Message(
                role: .assistant,
                content: "Preview response from Claude.",
                createdAt: Date()
            )
        }
    )
}

extension DependencyValues {
    nonisolated var llmClient: LLMClient {
        get { self[LLMClient.self] }
        set { self[LLMClient.self] = newValue }
    }
}

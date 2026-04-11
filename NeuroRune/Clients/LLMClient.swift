//
//  LLMClient.swift
//  NeuroRune
//

import Foundation
import Dependencies

nonisolated struct LLMClient: Sendable {
    var sendMessage: @Sendable ([Message], LLMModel) async throws -> Message
}

nonisolated extension LLMClient: DependencyKey {
    static let liveValue = LLMClient(
        sendMessage: { _, _ in
            // Phase 5에서 AnthropicClient로 교체
            throw LLMError.unauthorized
        }
    )

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

//
//  LLMClient.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation
import Dependencies
import os

nonisolated struct LLMClient: Sendable {
    var streamMessage: @Sendable ([APIMessage], LLMModel, EffortLevel?, String?, [LLMTool]?) async throws -> AsyncThrowingStream<LLMStreamEvent, Error>
}

nonisolated extension LLMClient: DependencyKey {
    static let liveValue: LLMClient = {
        LLMClient(
            streamMessage: { apiMessages, model, effort, system, tools in
                let apiKey = try loadAnthropicAPIKey()
                Logger.llm.info("stream, model: \(model.id, privacy: .public), messages: \(apiMessages.count), effort: \(effort?.rawValue ?? "default", privacy: .public), system: \(system != nil ? "yes(\(system!.count))" : "no", privacy: .public), tools: \(tools?.count ?? 0)")
                let client = LLMClient.anthropic(session: .shared, apiKey: apiKey)
                return try await client.streamMessage(apiMessages, model, effort, system, tools)
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
        streamMessage: unimplemented("LLMClient.streamMessage")
    )

    static let previewValue = LLMClient(
        streamMessage: { _, _, _, _, _ -> AsyncThrowingStream<LLMStreamEvent, Error> in
            AsyncThrowingStream { continuation in
                Task {
                    for chunk in ["Preview ", "response ", "from ", "Claude."] {
                        continuation.yield(.textDelta(chunk))
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

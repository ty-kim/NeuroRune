//
//  AnthropicRequestBuilder.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation

nonisolated enum AnthropicAPI {
    // swiftlint:disable:next force_unwrapping
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"
    static let defaultMaxTokens = 4096
}

nonisolated enum AnthropicRequestBuilder {

    static func build(
        messages: [Message],
        model: LLMModel,
        apiKey: String,
        stream: Bool = false,
        effort: EffortLevel? = nil,
        system: String? = nil,
        tools: [LLMTool]? = nil,
        apiMessages: [APIMessage]? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: AnthropicAPI.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicAPI.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Opus 4.7은 adaptive thinking only, Opus/Sonnet 4.6은 adaptive + output_config.effort 권장.
        // manual budget_tokens는 deprecated. 모델이 effort 미지원이면 둘 다 omit.
        let resolvedMessages: [APIMessage] = apiMessages
            ?? messages.map { APIMessage.text(role: $0.role.rawValue, content: $0.content) }
        let effortConfig: AnthropicRequestBody.OutputConfig? = {
            guard model.supportsEffort, let effort else { return nil }
            return AnthropicRequestBody.OutputConfig(effort: effort.rawValue)
        }()
        let body = AnthropicRequestBody(
            model: model.id,
            maxTokens: AnthropicAPI.defaultMaxTokens,
            messages: resolvedMessages,
            stream: stream ? true : nil,
            thinking: effortConfig != nil ? AnthropicRequestBody.Thinking(type: "adaptive") : nil,
            outputConfig: effortConfig,
            system: system,
            tools: tools
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        return request
    }
}

private nonisolated struct AnthropicRequestBody: Encodable {
    struct Thinking: Encodable {
        let type: String
    }
    struct OutputConfig: Encodable {
        let effort: String
    }
    let model: String
    let maxTokens: Int
    let messages: [APIMessage]
    let stream: Bool?
    let thinking: Thinking?
    let outputConfig: OutputConfig?
    let system: String?
    let tools: [LLMTool]?

    enum CodingKeys: String, CodingKey {
        case model, maxTokens, messages, stream, thinking, outputConfig, system, tools
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(stream, forKey: .stream)
        try container.encodeIfPresent(thinking, forKey: .thinking)
        try container.encodeIfPresent(outputConfig, forKey: .outputConfig)
        try container.encodeIfPresent(system, forKey: .system)
        try container.encodeIfPresent(tools, forKey: .tools)
    }
}

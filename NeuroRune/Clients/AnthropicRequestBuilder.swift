//
//  AnthropicRequestBuilder.swift
//  NeuroRune
//

import Foundation

nonisolated enum AnthropicAPI {
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
        thinkingBudgetTokens: Int? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: AnthropicAPI.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicAPI.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = AnthropicRequestBody(
            model: model.id,
            maxTokens: AnthropicAPI.defaultMaxTokens,
            messages: messages.map {
                AnthropicRequestBody.RequestMessage(
                    role: $0.role.rawValue,
                    content: $0.content
                )
            },
            stream: stream ? true : nil,
            thinking: thinkingBudgetTokens.map {
                AnthropicRequestBody.Thinking(type: "enabled", budgetTokens: $0)
            }
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        return request
    }
}

private nonisolated struct AnthropicRequestBody: Encodable {
    struct RequestMessage: Encodable {
        let role: String
        let content: String
    }
    struct Thinking: Encodable {
        let type: String
        let budgetTokens: Int
    }
    let model: String
    let maxTokens: Int
    let messages: [RequestMessage]
    let stream: Bool?
    let thinking: Thinking?

    enum CodingKeys: String, CodingKey {
        case model, maxTokens, messages, stream, thinking
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(stream, forKey: .stream)
        try container.encodeIfPresent(thinking, forKey: .thinking)
    }
}

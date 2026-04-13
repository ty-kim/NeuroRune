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
        apiKey: String
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
    let model: String
    let maxTokens: Int
    let messages: [RequestMessage]
}

//
//  AnthropicClient.swift
//  NeuroRune
//

import Foundation

extension LLMClient {

    static func anthropic(session: URLSession, apiKey: String) -> LLMClient {
        LLMClient(
            sendMessage: { messages, model in
                let request: URLRequest
                do {
                    request = try Self.buildRequest(messages: messages, model: model, apiKey: apiKey)
                } catch {
                    throw LLMError.decoding("request encoding failed: \(error)")
                }

                let data: Data
                let response: URLResponse
                do {
                    (data, response) = try await session.data(for: request)
                } catch let urlError as URLError {
                    throw LLMError.network(urlError.localizedDescription)
                } catch {
                    throw LLMError.network(error.localizedDescription)
                }

                guard let http = response as? HTTPURLResponse else {
                    throw LLMError.network("non-http response")
                }

                switch http.statusCode {
                case 200..<300:
                    return try Self.parseSuccessResponse(data: data)
                case 401:
                    throw LLMError.unauthorized
                case 429:
                    throw LLMError.rateLimited
                default:
                    throw LLMError.server(status: http.statusCode)
                }
            }
        )
    }

    private nonisolated static func parseSuccessResponse(data: Data) throws -> Message {
        struct AnthropicResponse: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String
            }
            let content: [Content]
        }

        let decoder = JSONDecoder()
        let decoded: AnthropicResponse
        do {
            decoded = try decoder.decode(AnthropicResponse.self, from: data)
        } catch {
            throw LLMError.decoding(String(describing: error))
        }

        let text = decoded.content.first?.text ?? ""
        return Message(role: .assistant, content: text, createdAt: Date())
    }

    private nonisolated static func buildRequest(
        messages: [Message],
        model: LLMModel,
        apiKey: String
    ) throws -> URLRequest {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = AnthropicRequestBody(
            model: model.id,
            maxTokens: 4096,
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

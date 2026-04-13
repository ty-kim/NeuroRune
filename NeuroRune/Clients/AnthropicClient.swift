//
//  AnthropicClient.swift
//  NeuroRune
//

import Foundation
import os

nonisolated extension LLMClient {

    static func anthropic(session: URLSession, apiKey: String) -> LLMClient {
        LLMClient(
            sendMessage: { messages, model in
                Logger.network.info("send request, model: \(model.id, privacy: .public), messages: \(messages.count)")

                let request: URLRequest
                do {
                    request = try AnthropicRequestBuilder.build(messages: messages, model: model, apiKey: apiKey)
                } catch {
                    Logger.network.error("request encoding failed: \(error.localizedDescription)")
                    throw LLMError.decoding("request encoding failed: \(error)")
                }

                let data: Data
                let response: URLResponse
                do {
                    (data, response) = try await session.data(for: request)
                } catch let urlError as URLError {
                    Logger.network.error("url error: \(urlError.localizedDescription)")
                    throw LLMError.network(urlError.localizedDescription)
                } catch {
                    Logger.network.error("network error: \(error.localizedDescription)")
                    throw LLMError.network(error.localizedDescription)
                }

                guard let http = response as? HTTPURLResponse else {
                    Logger.network.error("non-http response")
                    throw LLMError.network("non-http response")
                }

                Logger.network.info("received response, status: \(http.statusCode)")

                switch http.statusCode {
                case 200..<300:
                    return try AnthropicResponseParser.parseSuccess(data: data)
                case 401:
                    Logger.network.error("unauthorized (401)")
                    throw LLMError.unauthorized
                case 429:
                    Logger.network.error("rate limited (429)")
                    throw LLMError.rateLimited
                default:
                    let message = AnthropicResponseParser.parseErrorMessage(data: data)
                    Logger.network.error("server error, status: \(http.statusCode), message: \(message)")
                    throw LLMError.server(status: http.statusCode, message: message)
                }
            }
        )
    }
}

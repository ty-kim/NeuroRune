//
//  AnthropicClient.swift
//  NeuroRune
//

import Foundation
import os

nonisolated extension LLMClient {

    static func anthropic(session: URLSession, apiKey: String) -> LLMClient {
        LLMClient(
            streamMessage: { messages, model, effort, system in
                Logger.network.info("stream request, model: \(model.id, privacy: .public), messages: \(messages.count), effort: \(effort?.rawValue ?? "default", privacy: .public), system: \(system != nil ? "yes(\(system!.count))" : "no", privacy: .public)")

                let request: URLRequest
                do {
                    request = try AnthropicRequestBuilder.build(
                        messages: messages,
                        model: model,
                        apiKey: apiKey,
                        stream: true,
                        effort: effort,
                        system: system
                    )
                } catch {
                    Logger.network.error("stream request encoding failed: \(error.localizedDescription)")
                    throw LLMError.decoding("request encoding failed: \(error)")
                }

                let (bytes, response): (URLSession.AsyncBytes, URLResponse)
                do {
                    (bytes, response) = try await session.bytes(for: request)
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
                    break
                case 401:
                    throw LLMError.unauthorized
                case 429:
                    throw LLMError.rateLimited
                default:
                    throw LLMError.server(status: http.statusCode, message: "stream request failed")
                }

                return AsyncThrowingStream<String, Error> { continuation in
                    let task = Task {
                        do {
                            for try await line in bytes.lines {
                                guard line.hasPrefix("data:") else { continue }
                                let payload = String(line.dropFirst("data:".count))
                                switch AnthropicSSEParser.parseDataLine(payload) {
                                case .textDelta(let text):
                                    continuation.yield(text)
                                case .stop:
                                    continuation.finish()
                                    return
                                case .error(let message):
                                    continuation.finish(throwing: LLMError.server(status: 0, message: message))
                                    return
                                case .ignored:
                                    continue
                                }
                            }
                            // 바이트 스트림이 message_stop 없이 끝나면 부분 응답을
                            // 성공으로 저장하지 않도록 실패 처리.
                            continuation.finish(throwing: LLMError.decoding("stream ended without message_stop"))
                        } catch let urlError as URLError {
                            continuation.finish(throwing: LLMError.network(urlError.localizedDescription))
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }
        )
    }
}

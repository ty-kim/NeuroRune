//
//  AnthropicClient.swift
//  NeuroRune
//

import Foundation
import os

nonisolated extension LLMClient {

    static func anthropic(session: URLSession, apiKey: String) -> LLMClient {
        LLMClient(
            streamMessage: { apiMessages, model, effort, system, tools in
                Logger.network.info("stream request, model: \(model.id, privacy: .public), messages: \(apiMessages.count), effort: \(effort?.rawValue ?? "default", privacy: .public), system: \(system != nil ? "yes(\(system!.count))" : "no", privacy: .public), tools: \(tools?.count ?? 0)")

                let request: URLRequest
                do {
                    request = try AnthropicRequestBuilder.build(
                        messages: [],
                        model: model,
                        apiKey: apiKey,
                        stream: true,
                        effort: effort,
                        system: system,
                        tools: tools,
                        apiMessages: apiMessages
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

                // 상태 코드 분기 전에 rate limit·retry-after 먼저 파싱.
                // 429일 때도 헤더는 같이 오므로 에러에 담아 UI에 쿼터 상태를 전달.
                let rateLimit = RateLimitState.parse(from: http)
                let retryAfter: TimeInterval? = http.value(forHTTPHeaderField: "retry-after")
                    .flatMap { TimeInterval($0) }

                switch http.statusCode {
                case 200..<300:
                    break
                case 401:
                    throw LLMError.unauthorized
                case 429:
                    throw LLMError.rateLimited(
                        retryAfter: retryAfter,
                        state: rateLimit.isEmpty ? nil : rateLimit
                    )
                default:
                    throw LLMError.server(status: http.statusCode, message: "stream request failed")
                }

                return AsyncThrowingStream<LLMStreamEvent, Error> { continuation in
                    // 스트림 시작 직후 응답 헤더에서 파싱한 쿼터를 1회 emit.
                    // Quota 하나라도 있으면 UI가 업데이트할 가치가 있음.
                    if !rateLimit.isEmpty {
                        continuation.yield(.rateLimitUpdate(rateLimit))
                    }

                    let task = Task {
                        do {
                            // tool_use 블록 조립 상태: index → (id, name, partialJSON)
                            var pendingToolUses: [Int: (id: String, name: String, partial: String)] = [:]
                            for try await line in bytes.lines {
                                guard line.hasPrefix("data:") else { continue }
                                let payload = String(line.dropFirst("data:".count))
                                switch AnthropicSSEParser.parseDataLine(payload) {
                                case .textDelta(let text):
                                    continuation.yield(.textDelta(text))
                                case let .toolUseStart(index, id, name):
                                    pendingToolUses[index] = (id, name, "")
                                case let .toolUseInputDelta(index, partial):
                                    if var tool = pendingToolUses[index] {
                                        tool.partial += partial
                                        pendingToolUses[index] = tool
                                    }
                                case let .contentBlockStop(index):
                                    if let tool = pendingToolUses.removeValue(forKey: index) {
                                        continuation.yield(.toolUseRequest(id: tool.id, name: tool.name, inputJSON: tool.partial))
                                    }
                                case .messageDelta:
                                    continue
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

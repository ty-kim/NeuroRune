//
//  AnthropicSSEParser.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation

nonisolated enum AnthropicSSEEvent: Equatable {
    case textDelta(String)
    case toolUseStart(index: Int, id: String, name: String)
    case toolUseInputDelta(index: Int, partialJSON: String)
    case contentBlockStop(index: Int)
    case messageStart(model: String)
    case messageDelta(stopReason: String?)
    case stop
    case error(message: String)
    case ignored
}

nonisolated enum AnthropicSSEParser {

    /// SSE 한 "data:" 라인의 JSON payload를 파싱한다.
    /// 입력은 "data: " 프리픽스가 제거된 JSON 문자열.
    static func parseDataLine(_ line: String) -> AnthropicSSEEvent {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return .ignored
        }

        struct Envelope: Decodable {
            struct Delta: Decodable {
                let type: String?
                let text: String?
                let partialJSON: String?
                let stopReason: String?

                enum CodingKeys: String, CodingKey {
                    case type, text
                    case partialJSON = "partial_json"
                    case stopReason = "stop_reason"
                }
            }
            struct ContentBlock: Decodable {
                let type: String?
                let id: String?
                let name: String?
            }
            struct MessageInfo: Decodable {
                let model: String?
            }
            struct ErrorDetail: Decodable {
                let message: String?
            }
            let type: String?
            let index: Int?
            let delta: Delta?
            let contentBlock: ContentBlock?
            let message: MessageInfo?
            let error: ErrorDetail?

            enum CodingKeys: String, CodingKey {
                case type, index, delta, error, message
                case contentBlock = "content_block"
            }
        }

        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return .ignored
        }

        switch env.type {
        case "message_start":
            guard let model = env.message?.model else { return .ignored }
            return .messageStart(model: model)
        case "content_block_start":
            guard env.contentBlock?.type == "tool_use",
                  let index = env.index,
                  let id = env.contentBlock?.id,
                  let name = env.contentBlock?.name
            else { return .ignored }
            return .toolUseStart(index: index, id: id, name: name)
        case "content_block_delta":
            if env.delta?.type == "text_delta", let text = env.delta?.text {
                return .textDelta(text)
            }
            if env.delta?.type == "input_json_delta",
               let partial = env.delta?.partialJSON,
               let index = env.index {
                return .toolUseInputDelta(index: index, partialJSON: partial)
            }
            return .ignored
        case "content_block_stop":
            guard let index = env.index else { return .ignored }
            return .contentBlockStop(index: index)
        case "message_delta":
            return .messageDelta(stopReason: env.delta?.stopReason)
        case "message_stop":
            return .stop
        case "error":
            return .error(message: env.error?.message ?? "unknown error")
        default:
            return .ignored
        }
    }
}

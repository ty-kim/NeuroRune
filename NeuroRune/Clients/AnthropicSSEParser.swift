//
//  AnthropicSSEParser.swift
//  NeuroRune
//

import Foundation

nonisolated enum AnthropicSSEEvent: Equatable {
    case textDelta(String)
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
            }
            struct ErrorDetail: Decodable {
                let message: String?
            }
            let type: String?
            let delta: Delta?
            let error: ErrorDetail?
        }

        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return .ignored
        }

        switch env.type {
        case "content_block_delta":
            if env.delta?.type == "text_delta", let text = env.delta?.text {
                return .textDelta(text)
            }
            return .ignored
        case "message_stop":
            return .stop
        case "error":
            return .error(message: env.error?.message ?? "unknown error")
        default:
            return .ignored
        }
    }
}

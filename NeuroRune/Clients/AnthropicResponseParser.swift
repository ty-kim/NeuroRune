//
//  AnthropicResponseParser.swift
//  NeuroRune
//

import Foundation

nonisolated enum AnthropicResponseParser {

    static func parseSuccess(data: Data) throws -> Message {
        struct AnthropicResponse: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
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

        let textBlocks = decoded.content.compactMap { block -> String? in
            guard block.type == "text" else { return nil }
            return block.text
        }

        guard !textBlocks.isEmpty else {
            throw LLMError.decoding("response contained no text blocks")
        }

        return Message(
            role: .assistant,
            content: textBlocks.joined(),
            createdAt: Date()
        )
    }

    static func parseErrorMessage(data: Data) -> String {
        struct ErrorResponse: Decodable {
            struct ErrorDetail: Decodable {
                let message: String
            }
            let error: ErrorDetail
        }
        if let parsed = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return parsed.error.message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

//
//  APIContentBlock.swift
//  NeuroRune
//

import Foundation

/// Anthropic Messages API의 multi-block content용 type.
/// 일반 텍스트 채팅은 String content 그대로 쓰고, tool_use 멀티턴 라운드에서만 사용.
nonisolated enum APIContentBlock: Sendable, Equatable, Encodable {
    case text(String)
    /// Claude가 보낸 tool_use를 round 2에서 echo back할 때.
    case toolUse(id: String, name: String, input: [String: String])
    /// 사용자(앱) 측에서 tool 실행 결과를 돌려줄 때.
    case toolResult(toolUseID: String, content: String)

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
        case toolUseID = "tool_use_id"
        case content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .toolUse(id, name, input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case let .toolResult(toolUseID, content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseID, forKey: .toolUseID)
            try container.encode(content, forKey: .content)
        }
    }
}

/// API 요청의 단일 메시지. content는 String(단순) 또는 blocks(멀티) 어느 쪽이든 가능.
nonisolated struct APIMessage: Sendable, Equatable, Encodable {
    let role: String
    let content: Content

    nonisolated enum Content: Sendable, Equatable, Encodable {
        case text(String)
        case blocks([APIContentBlock])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let s):
                try container.encode(s)
            case .blocks(let bs):
                try container.encode(bs)
            }
        }
    }

    /// 평범한 텍스트 메시지(domain Message 기반)에서 변환.
    static func text(role: String, content: String) -> APIMessage {
        APIMessage(role: role, content: .text(content))
    }
}

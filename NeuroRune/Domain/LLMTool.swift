//
//  LLMTool.swift
//  NeuroRune
//

import Foundation

/// Anthropic Messages API의 tools 항목.
/// 현재는 string 타입 properties만 가지는 평면 object 스키마에 한정 (read_memory 용).
nonisolated struct LLMTool: Sendable, Equatable, Encodable {
    let name: String
    let description: String
    let inputSchema: InputSchema

    nonisolated struct InputSchema: Sendable, Equatable, Encodable {
        let type: String
        let properties: [String: Property]
        let required: [String]

        init(properties: [String: Property], required: [String]) {
            self.type = "object"
            self.properties = properties
            self.required = required
        }
    }

    nonisolated struct Property: Sendable, Equatable, Encodable {
        let type: String
        let description: String?
    }
}

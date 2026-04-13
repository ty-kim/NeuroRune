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

nonisolated extension LLMTool {
    /// Claude가 GitHub 메모리 파일을 동적으로 가져오는 tool.
    /// MEMORY.md 인덱스를 보고 Claude가 필요한 파일을 직접 요청.
    static let readMemory = LLMTool(
        name: "read_memory",
        description: "Load a memory file from the user's GitHub repository. Use this when the MEMORY.md index references a file you need to examine.",
        inputSchema: LLMTool.InputSchema(
            properties: [
                "role": LLMTool.Property(
                    type: "string",
                    description: "Memory repository role: 'global' or 'local'."
                ),
                "path": LLMTool.Property(
                    type: "string",
                    description: "File path within the repository, e.g. 'runes/profile.md'."
                ),
            ],
            required: ["role", "path"]
        )
    )
}

//
//  LLMModel.swift
//  NeuroRune
//

nonisolated struct LLMModel: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String

    static let opus46 = LLMModel(id: "claude-opus-4-6", displayName: "Claude Opus 4.6")
    static let sonnet46 = LLMModel(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6")
    static let haiku45 = LLMModel(id: "claude-haiku-4-5", displayName: "Claude Haiku 4.5")

    static let allSupported: [LLMModel] = [.opus46, .sonnet46, .haiku45]

    static func resolve(id: String) -> LLMModel {
        allSupported.first { $0.id == id } ?? LLMModel(id: id, displayName: id)
    }
}

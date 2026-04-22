//
//  LLMModel.swift
//  NeuroRune
//
//  Created by tykim
//

nonisolated struct LLMModel: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    /// Anthropic `output_config.effort` 파라미터를 지원하는지 여부.
    /// Opus 4.7 / Opus 4.6 / Sonnet 4.6 지원. Haiku 4.5 미지원.
    let supportsEffort: Bool

    init(id: String, displayName: String, supportsEffort: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.supportsEffort = supportsEffort
    }

    static let opus47 = LLMModel(
        id: "claude-opus-4-7",
        displayName: "Claude Opus 4.7",
        supportsEffort: true
    )
    static let opus46 = LLMModel(
        id: "claude-opus-4-6",
        displayName: "Claude Opus 4.6",
        supportsEffort: true
    )
    static let sonnet46 = LLMModel(
        id: "claude-sonnet-4-6",
        displayName: "Claude Sonnet 4.6",
        supportsEffort: true
    )
    static let haiku45 = LLMModel(
        id: "claude-haiku-4-5",
        displayName: "Claude Haiku 4.5",
        supportsEffort: false
    )

    static let allSupported: [LLMModel] = [.opus47, .opus46, .sonnet46, .haiku45]

    static func resolve(id: String) -> LLMModel {
        allSupported.first { $0.id == id } ?? LLMModel(id: id, displayName: id)
    }
}

//
//  LLMModel.swift
//  NeuroRune
//
//  Created by tykim
//

nonisolated struct LLMModel: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    /// Anthropic `output_config.effort`가 수용하는 값 목록.
    /// 비어있으면 effort 미지원 (Haiku 4.5). xhigh는 Opus 4.7 전용.
    let supportedEffortLevels: [EffortLevel]

    init(id: String, displayName: String, supportedEffortLevels: [EffortLevel] = []) {
        self.id = id
        self.displayName = displayName
        self.supportedEffortLevels = supportedEffortLevels
    }

    static let opus47 = LLMModel(
        id: "claude-opus-4-7",
        displayName: "Claude Opus 4.7",
        supportedEffortLevels: [.low, .medium, .high, .xhigh, .max]
    )
    static let opus46 = LLMModel(
        id: "claude-opus-4-6",
        displayName: "Claude Opus 4.6",
        supportedEffortLevels: [.low, .medium, .high, .max]
    )
    static let sonnet46 = LLMModel(
        id: "claude-sonnet-4-6",
        displayName: "Claude Sonnet 4.6",
        supportedEffortLevels: [.low, .medium, .high, .max]
    )
    static let haiku45 = LLMModel(
        id: "claude-haiku-4-5",
        displayName: "Claude Haiku 4.5"
    )

    static let allSupported: [LLMModel] = [.opus47, .opus46, .sonnet46, .haiku45]

    static func resolve(id: String) -> LLMModel {
        allSupported.first { $0.id == id } ?? LLMModel(id: id, displayName: id)
    }
}

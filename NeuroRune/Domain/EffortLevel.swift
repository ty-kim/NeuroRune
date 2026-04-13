//
//  EffortLevel.swift
//  NeuroRune
//

import Foundation

/// Anthropic `output_config.effort` 파라미터.
/// Claude 4.5/4.6 에서 응답 토큰 사용량(thinking 깊이 + 텍스트 분량)을 제어.
nonisolated enum EffortLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case max

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

//
//  EffortLevel.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation

/// Anthropic `output_config.effort` 파라미터.
/// Opus 4.7 / Opus 4.6 / Sonnet 4.6 에서 응답 토큰 사용량(thinking 깊이 + 텍스트 분량)을 제어.
/// Haiku 4.5 미지원.
nonisolated enum EffortLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    /// Opus 4.7 전용. 다른 모델에서 선택되면 무시(effort=nil) 처리.
    /// 단계: high < xhigh < max.
    case xhigh
    case max

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

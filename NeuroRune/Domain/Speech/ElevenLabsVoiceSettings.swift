//
//  ElevenLabsVoiceSettings.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs `voice_settings` 객체. 모든 값 0.0~1.0 범위.
//

import Foundation

nonisolated struct ElevenLabsVoiceSettings: Equatable, Sendable {
    /// 0에 가까울수록 표현 다양성↑, 1에 가까울수록 일관성↑. 기본 0.5.
    var stability: Double = 0.5
    /// 원본 음성과의 유사도. 높을수록 원본 가까움. 기본 0.75.
    var similarityBoost: Double = 0.75
    /// style 감정 표현 강도. 높이면 latency↑, 품질 저하 가능. 기본 0.
    var style: Double = 0.0
    /// speaker boost 효과. 명료도↑.
    var useSpeakerBoost: Bool = true
}

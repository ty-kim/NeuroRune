//
//  SpeechSettings.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs TTS 사용자 설정. voice_id + voice_settings(stability/similarity/style/speakerBoost) + autoSpeak.
//

import Foundation

nonisolated struct SpeechSettings: Equatable, Sendable {
    /// ElevenLabs voice_id (UUID-like 20~30자 문자열). 빈 문자열이면 "미선택".
    var voiceId: String
    /// 표시용 voice 이름. API에서 받아온 name 캐시. UI가 voiceId만으로는 뭔지 모름.
    var voiceName: String
    /// 0~1. 0에 가까울수록 표현 다양, 1에 가까울수록 일관성. 기본 0.5.
    var stability: Double
    /// 0~1. 원본 음성 유사도. 기본 0.75.
    var similarityBoost: Double
    /// 0~1. 감정 표현 강도. 기본 0. 높이면 latency↑.
    var style: Double
    /// speaker boost 효과. 명료도↑.
    var useSpeakerBoost: Bool
    /// 스트리밍 완료 시 자동 재생 여부.
    var autoSpeak: Bool

    init(
        voiceId: String = "",
        voiceName: String = "",
        stability: Double = 0.5,
        similarityBoost: Double = 0.75,
        style: Double = 0.0,
        useSpeakerBoost: Bool = true,
        autoSpeak: Bool = false
    ) {
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style
        self.useSpeakerBoost = useSpeakerBoost
        self.autoSpeak = autoSpeak
    }

    /// ElevenLabs voice_settings payload로 변환.
    var voiceSettings: ElevenLabsVoiceSettings {
        ElevenLabsVoiceSettings(
            stability: stability,
            similarityBoost: similarityBoost,
            style: style,
            useSpeakerBoost: useSpeakerBoost
        )
    }
}

nonisolated extension SpeechSettings {
    nonisolated enum DefaultsKey {
        nonisolated static let voiceId = "tts.voiceId"
        nonisolated static let voiceName = "tts.voiceName"
        nonisolated static let stability = "tts.stability"
        nonisolated static let similarityBoost = "tts.similarityBoost"
        nonisolated static let style = "tts.style"
        nonisolated static let useSpeakerBoost = "tts.useSpeakerBoost"
        nonisolated static let autoSpeak = "tts.autoSpeak"
    }

    /// Azure 기반 이전 키 잔재 제거. 앱 시작 시 1회 호출.
    /// 새 스키마(voice_settings)로 전환하면서 tts.voice/tts.rate/tts.pitch는 무의미.
    static func removeLegacyDefaults(from defaults: UserDefaults) {
        for key in ["tts.voice", "tts.rate", "tts.pitch"] {
            defaults.removeObject(forKey: key)
        }
    }
}

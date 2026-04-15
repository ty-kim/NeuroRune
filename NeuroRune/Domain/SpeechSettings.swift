//
//  SpeechSettings.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 Slice 7 — TTS 사용자 설정 (voice·rate·pitch·autoSpeak).
//

import Foundation

nonisolated struct SpeechSettings: Equatable, Sendable {
    var voiceName: String
    /// 0.5(느림) ~ 1.5(빠름). 1.0 기본.
    var rate: Double
    /// 0.5(낮음) ~ 1.5(높음). 1.0 기본 = ±0%.
    var pitch: Double
    /// 스트리밍 완료 시 자동 재생 여부.
    var autoSpeak: Bool

    init(
        voiceName: String = "ko-KR-SunHiNeural",
        rate: Double = 1.0,
        pitch: Double = 1.0,
        autoSpeak: Bool = false
    ) {
        self.voiceName = voiceName
        self.rate = rate
        self.pitch = pitch
        self.autoSpeak = autoSpeak
    }

    /// voice 이름에서 BCP-47 언어 추출. `ko-KR-SunHiNeural` → `ko-KR`.
    var bcp47Language: String {
        let parts = voiceName.split(separator: "-")
        guard parts.count >= 2 else { return "ko-KR" }
        return "\(parts[0])-\(parts[1])"
    }
}

nonisolated extension SpeechSettings {
    nonisolated enum DefaultsKey {
        nonisolated static let voice = "tts.voice"
        nonisolated static let rate = "tts.rate"
        nonisolated static let pitch = "tts.pitch"
        nonisolated static let autoSpeak = "tts.autoSpeak"
    }
}

/// Azure Neural voice 프리셋. Menu·picker에 노출되는 목록.
nonisolated struct AzureVoice: Equatable, Sendable, Identifiable {
    let name: String
    let displayName: String
    let language: String

    var id: String { name }
}

nonisolated extension AzureVoice {
    static let presets: [AzureVoice] = [
        AzureVoice(name: "ko-KR-SunHiNeural",    displayName: "선희 (여)",      language: "ko-KR"),
        AzureVoice(name: "ko-KR-InJoonNeural",   displayName: "인준 (남)",      language: "ko-KR"),
        AzureVoice(name: "ko-KR-JiMinNeural",    displayName: "지민 (여·감정)", language: "ko-KR"),
        AzureVoice(name: "ko-KR-SeoHyeonNeural", displayName: "서현 (여)",      language: "ko-KR"),
        AzureVoice(name: "ko-KR-SoonBokNeural",  displayName: "순복 (여·시니어)", language: "ko-KR"),
        AzureVoice(name: "en-US-JennyNeural",    displayName: "Jenny (F)",      language: "en-US"),
        AzureVoice(name: "en-US-GuyNeural",      displayName: "Guy (M)",        language: "en-US"),
    ]
}

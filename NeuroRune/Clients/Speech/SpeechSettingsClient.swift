//
//  SpeechSettingsClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 Slice 7 — SpeechSettings UserDefaults 영속화.
//

import Foundation
import Dependencies

nonisolated struct SpeechSettingsClient: Sendable {
    var load: @Sendable () -> SpeechSettings
    var save: @Sendable (SpeechSettings) -> Void
}

nonisolated extension SpeechSettingsClient: DependencyKey {
    static let liveValue = SpeechSettingsClient(
        load: {
            let defaults = UserDefaults.standard
            let voice = defaults.string(forKey: SpeechSettings.DefaultsKey.voice)
                ?? SpeechSettings().voiceName
            let rate = (defaults.object(forKey: SpeechSettings.DefaultsKey.rate) as? Double) ?? 1.0
            let pitch = (defaults.object(forKey: SpeechSettings.DefaultsKey.pitch) as? Double) ?? 1.0
            let autoSpeak = defaults.bool(forKey: SpeechSettings.DefaultsKey.autoSpeak)
            return SpeechSettings(voiceName: voice, rate: rate, pitch: pitch, autoSpeak: autoSpeak)
        },
        save: { settings in
            let defaults = UserDefaults.standard
            defaults.set(settings.voiceName, forKey: SpeechSettings.DefaultsKey.voice)
            defaults.set(settings.rate, forKey: SpeechSettings.DefaultsKey.rate)
            defaults.set(settings.pitch, forKey: SpeechSettings.DefaultsKey.pitch)
            defaults.set(settings.autoSpeak, forKey: SpeechSettings.DefaultsKey.autoSpeak)
        }
    )

    static let testValue = SpeechSettingsClient(
        load: unimplemented("SpeechSettingsClient.load", placeholder: SpeechSettings()),
        save: unimplemented("SpeechSettingsClient.save")
    )

    static let previewValue = SpeechSettingsClient(
        load: { SpeechSettings() },
        save: { _ in }
    )
}

extension DependencyValues {
    nonisolated var speechSettingsClient: SpeechSettingsClient {
        get { self[SpeechSettingsClient.self] }
        set { self[SpeechSettingsClient.self] = newValue }
    }
}

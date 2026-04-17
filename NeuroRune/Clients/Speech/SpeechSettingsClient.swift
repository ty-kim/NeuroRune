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
            let defaultSettings = SpeechSettings()
            let stability = (defaults.object(forKey: SpeechSettings.DefaultsKey.stability) as? Double)
                ?? defaultSettings.stability
            let similarityBoost = (defaults.object(forKey: SpeechSettings.DefaultsKey.similarityBoost) as? Double)
                ?? defaultSettings.similarityBoost
            let style = (defaults.object(forKey: SpeechSettings.DefaultsKey.style) as? Double)
                ?? defaultSettings.style
            let useSpeakerBoost = (defaults.object(forKey: SpeechSettings.DefaultsKey.useSpeakerBoost) as? Bool)
                ?? defaultSettings.useSpeakerBoost
            return SpeechSettings(
                voiceId: defaults.string(forKey: SpeechSettings.DefaultsKey.voiceId) ?? "",
                voiceName: defaults.string(forKey: SpeechSettings.DefaultsKey.voiceName) ?? "",
                stability: stability,
                similarityBoost: similarityBoost,
                style: style,
                useSpeakerBoost: useSpeakerBoost,
                autoSpeak: defaults.bool(forKey: SpeechSettings.DefaultsKey.autoSpeak)
            )
        },
        save: { settings in
            let defaults = UserDefaults.standard
            defaults.set(settings.voiceId, forKey: SpeechSettings.DefaultsKey.voiceId)
            defaults.set(settings.voiceName, forKey: SpeechSettings.DefaultsKey.voiceName)
            defaults.set(settings.stability, forKey: SpeechSettings.DefaultsKey.stability)
            defaults.set(settings.similarityBoost, forKey: SpeechSettings.DefaultsKey.similarityBoost)
            defaults.set(settings.style, forKey: SpeechSettings.DefaultsKey.style)
            defaults.set(settings.useSpeakerBoost, forKey: SpeechSettings.DefaultsKey.useSpeakerBoost)
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

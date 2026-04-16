//
//  ElevenLabsCredentials.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs TTS BYOK. region 없고 apiKey 하나만.
//

import Foundation

nonisolated struct ElevenLabsCredentials: Equatable, Sendable {
    let apiKey: String

    var isValid: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Keychain 저장 키. 단일 사용자 기준.
    static let keychainKey = "elevenlabs.apiKey"
}

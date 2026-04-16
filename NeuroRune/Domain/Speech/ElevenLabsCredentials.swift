//
//  ElevenLabsCredentials.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs TTS BYOK. Azure와 달리 region이 없어서 apiKey 하나만.
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

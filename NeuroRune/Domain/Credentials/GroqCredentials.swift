//
//  GroqCredentials.swift
//  NeuroRune
//
//  Created by tykim
//
//  Groq API 단일 키. Whisper(STT)·LLM 등 Groq 제공 서비스 공용.
//

import Foundation

nonisolated struct GroqCredentials: Equatable, Sendable {
    /// `Authorization: Bearer <apiKey>` 헤더값.
    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// 공백 제외 비어있지 않은지.
    var isValid: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

nonisolated extension GroqCredentials {
    /// Keychain 저장 키. 변경 시 기존 사용자 데이터 마이그레이션 고려.
    nonisolated enum KeychainKey {
        nonisolated static let apiKey = "groq.apiKey"
    }
}

//
//  ElevenLabsCredentialsTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  ElevenLabs TTS BYOK — API 키 도메인 모델 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct ElevenLabsCredentialsTests {

    @Test("빈 apiKey면 isValid=false")
    func emptyKeyInvalid() {
        let c = ElevenLabsCredentials(apiKey: "")
        #expect(!c.isValid)
    }

    @Test("공백만인 apiKey도 isValid=false")
    func whitespaceKeyInvalid() {
        let c = ElevenLabsCredentials(apiKey: "   \n  ")
        #expect(!c.isValid)
    }

    @Test("내용 있는 apiKey면 isValid=true")
    func nonEmptyKeyValid() {
        let c = ElevenLabsCredentials(apiKey: "sk_abc123")
        #expect(c.isValid)
    }

    @Test("Keychain 키 상수")
    func keychainKeyExists() {
        #expect(ElevenLabsCredentials.keychainKey == "elevenlabs.apiKey")
    }
}

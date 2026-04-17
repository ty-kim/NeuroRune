//
//  SpeechSettingsLegacyTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Azure 전환 전 UserDefaults 키 일괄 삭제 검증.
//

import Foundation
import Testing
@testable import NeuroRune

struct SpeechSettingsLegacyTests {

    @Test("removeLegacyDefaults: tts.voice / tts.rate / tts.pitch 삭제")
    func removesLegacyKeys() {
        let suiteName = "com.neurorune.tests.speechLegacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("ko-KR-SunHi", forKey: "tts.voice")
        defaults.set(1.2, forKey: "tts.rate")
        defaults.set(0.9, forKey: "tts.pitch")
        defaults.set(true, forKey: "tts.autoSpeak")  // 신규 키 — 유지돼야 함

        SpeechSettings.removeLegacyDefaults(from: defaults)

        #expect(defaults.object(forKey: "tts.voice") == nil)
        #expect(defaults.object(forKey: "tts.rate") == nil)
        #expect(defaults.object(forKey: "tts.pitch") == nil)
        #expect(defaults.bool(forKey: "tts.autoSpeak") == true)
    }
}

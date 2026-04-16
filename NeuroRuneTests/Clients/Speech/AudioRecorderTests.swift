//
//  AudioRecorderTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 21 Step 3 — previewValue 경로만 유닛으로 검증.
//  liveValue는 AVAudioSession/마이크 권한/하드웨어 의존이라 실기기 dogfooding으로 커버한다.
//

import Foundation
import Testing
@testable import NeuroRune

struct AudioRecorderTests {

    @Test("previewValue는 권한 true, 빈 WAV 헤더 반환")
    func previewStub() async throws {
        let recorder = AudioRecorder.previewValue
        #expect(await recorder.requestPermission() == true)
        try await recorder.start()
        let data = try await recorder.stop()
        #expect(data.count == 44)  // WAV header 크기
        #expect(await recorder.isRecording() == false)
    }

    @Test("cleanupOrphans: neurorune-stt-*.wav만 삭제, 다른 파일 보존")
    func cleanupRemovesOnlyMatching() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("nr-cleanup-test-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let keep = dir.appendingPathComponent("other.wav")
        let keep2 = dir.appendingPathComponent("neurorune-stt.txt")
        let drop1 = dir.appendingPathComponent("neurorune-stt-\(UUID().uuidString).wav")
        let drop2 = dir.appendingPathComponent("neurorune-stt-abc.wav")
        for url in [keep, keep2, drop1, drop2] {
            try Data([0]).write(to: url)
        }

        let removed = AudioRecorder.cleanupOrphans(in: dir, fileManager: fm)
        #expect(removed == 2)
        #expect(fm.fileExists(atPath: keep.path))
        #expect(fm.fileExists(atPath: keep2.path))
        #expect(!fm.fileExists(atPath: drop1.path))
        #expect(!fm.fileExists(atPath: drop2.path))
    }
}

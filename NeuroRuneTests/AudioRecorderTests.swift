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
}

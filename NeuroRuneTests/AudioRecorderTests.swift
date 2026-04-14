//
//  AudioRecorderTests.swift
//  NeuroRuneTests
//
//  Phase 21 Step 3 스캐폴드 테스트.
//  실제 AVAudioRecorder 구현은 다음 세션. 지금은 previewValue/liveValue 시그니처·스텁 검증만.
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

    @Test("liveValue는 미구현 상태 — start/stop 호출 시 STTError.recordingFailed")
    func liveValueThrowsUntilImplemented() async throws {
        let recorder = AudioRecorder.liveValue
        await #expect(throws: STTError.self) {
            try await recorder.start()
        }
        await #expect(throws: STTError.self) {
            _ = try await recorder.stop()
        }
    }

    @Test("liveValue 권한은 현재 false 기본값 (TODO: iOS 17 requestRecordPermission)")
    func liveValueDefaultPermission() async {
        #expect(await AudioRecorder.liveValue.requestPermission() == false)
    }
}

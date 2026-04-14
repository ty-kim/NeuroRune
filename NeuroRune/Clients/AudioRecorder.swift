//
//  AudioRecorder.swift
//  NeuroRune
//
//  Phase 21 Step 3 — 마이크에서 녹음해 Clova CSR에 보낼 WAV 바이트를 반환.
//  오늘은 스캐폴드만. `liveValue` 실제 구현은 다음 세션(AVAudioRecorder + 16kHz mono 16-bit PCM).
//

import Foundation
import Dependencies

nonisolated struct AudioRecorder: Sendable {
    /// 마이크 권한 요청. 이미 승인된 경우에도 즉시 true 반환.
    var requestPermission: @Sendable () async -> Bool
    /// 녹음 시작. 권한 없거나 엔진 실패 시 `STTError` throw.
    var start: @Sendable () async throws -> Void
    /// 녹음 종료 후 WAV 바이트(16kHz mono 16-bit PCM, Clova CSR 호환) 반환.
    /// - 시작 전 호출되면 `STTError.recordingFailed`.
    /// - 60초 초과 감지 시 내부적으로 stop 후 `STTError.audioTooLong` throw를 `start` 쪽에서 관리 권장.
    var stop: @Sendable () async throws -> Data
    /// 현재 녹음 중인지.
    var isRecording: @Sendable () async -> Bool
}

// MARK: - Dependency

nonisolated extension AudioRecorder: DependencyKey {
    /// 실제 AVAudioRecorder 연결은 다음 세션 작업. 지금 호출되면 명시적으로 unimplemented.
    static let liveValue = AudioRecorder(
        requestPermission: {
            // TODO: AVAudioApplication.requestRecordPermission (iOS 17+)
            false
        },
        start: {
            throw STTError.recordingFailed("AudioRecorder.liveValue not wired — Step 3 implementation pending")
        },
        stop: {
            throw STTError.recordingFailed("AudioRecorder.liveValue not wired — Step 3 implementation pending")
        },
        isRecording: { false }
    )

    static let testValue = AudioRecorder(
        requestPermission: unimplemented("AudioRecorder.requestPermission", placeholder: false),
        start: unimplemented("AudioRecorder.start"),
        stop: unimplemented("AudioRecorder.stop", placeholder: Data()),
        isRecording: unimplemented("AudioRecorder.isRecording", placeholder: false)
    )

    /// Preview/테스트용 — 짧은 fake WAV 헤더만 반환.
    static let previewValue = AudioRecorder(
        requestPermission: { true },
        start: { },
        stop: {
            // Minimal WAV stub: 44-byte header + 0 samples. Clova CSR은 거부하겠지만
            // UI 경로 테스트용으로만 쓰인다.
            Data(count: 44)
        },
        isRecording: { false }
    )
}

extension DependencyValues {
    nonisolated var audioRecorder: AudioRecorder {
        get { self[AudioRecorder.self] }
        set { self[AudioRecorder.self] = newValue }
    }
}

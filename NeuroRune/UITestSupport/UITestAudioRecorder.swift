//
//  UITestAudioRecorder.swift
//  NeuroRune
//
//  Created by tykim
//

#if DEBUG
import Foundation

extension AudioRecorder {
    /// UI 테스트 전용 AudioRecorder stub.
    /// `--ui-test-mock-stt` 플래그로 활성화 (STT와 한 세트).
    /// 실제 마이크 녹음 없이 recording 상태만 내부 flag로 토글.
    /// stop()은 빈 Data 반환 — STT mock이 입력을 무시하므로 무관.
    static let uiTestMock: AudioRecorder = {
        let state = UITestAudioState()
        return AudioRecorder(
            requestPermission: { true },
            start: { state.setRecording(true) },
            stop: {
                state.setRecording(false)
                return Data()
            },
            isRecording: { state.isRecording() },
            cleanupOrphanedFiles: { }
        )
    }()
}

nonisolated private final class UITestAudioState: @unchecked Sendable {
    private let lock = NSLock()
    private var recording = false

    func setRecording(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        recording = value
    }

    func isRecording() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return recording
    }
}
#endif

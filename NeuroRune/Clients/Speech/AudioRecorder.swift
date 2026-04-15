//
//  AudioRecorder.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 Step 3 — 마이크에서 녹음해 STT 백엔드(Groq Whisper)에 보낼 WAV 바이트를 반환.
//  포맷: 16kHz mono 16-bit Linear PCM (.wav) — Whisper 권장 입력 규격.
//

import Foundation
import AVFAudio
import Dependencies

nonisolated struct AudioRecorder: Sendable {
    /// 마이크 권한 요청. 이미 승인된 경우에도 즉시 true 반환.
    var requestPermission: @Sendable () async -> Bool
    /// 녹음 시작. 권한 없거나 엔진 실패 시 `STTError` throw.
    var start: @Sendable () async throws -> Void
    /// 녹음 종료 후 WAV 바이트(16kHz mono 16-bit PCM, Whisper 권장 포맷) 반환.
    var stop: @Sendable () async throws -> Data
    /// 현재 녹음 중인지.
    var isRecording: @Sendable () async -> Bool
    /// 앱 시작 시 호출. 이전 crash/kill로 tmp에 남은 `neurorune-stt-*.wav` 일괄 삭제.
    var cleanupOrphanedFiles: @Sendable () -> Void
}

nonisolated extension AudioRecorder {
    /// 순수 함수. 지정된 디렉토리에서 `neurorune-stt-*.wav` prefix/suffix 패턴 파일만 삭제.
    /// 반환: 삭제된 파일 수. 읽기 실패나 삭제 실패는 조용히 건너뜀.
    @discardableResult
    static func cleanupOrphans(in directory: URL, fileManager: FileManager) -> Int {
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return 0 }

        var removed = 0
        for url in items {
            let name = url.lastPathComponent
            guard name.hasPrefix("neurorune-stt-"), name.hasSuffix(".wav") else { continue }
            if (try? fileManager.removeItem(at: url)) != nil {
                removed += 1
            }
        }
        return removed
    }
}

// MARK: - Live actor

/// AVAudioRecorder 기반 실제 구현. 단일 인스턴스만 사용 (동시 녹음 금지).
private actor LiveAudioRecorder {
    static let shared = LiveAudioRecorder()

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    private static let maxDuration: TimeInterval = 60

    private func recorderSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        guard recorder == nil else {
            throw STTError.recordingFailed("already recording")
        }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw STTError.microphonePermissionDenied
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: [])
        } catch {
            throw STTError.recordingFailed("session: \(error.localizedDescription)")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("neurorune-stt-\(UUID().uuidString).wav")

        do {
            let rec = try AVAudioRecorder(url: url, settings: recorderSettings())
            guard rec.record(forDuration: Self.maxDuration) else {
                throw STTError.recordingFailed("record() returned false")
            }
            self.recorder = rec
            self.fileURL = url
        } catch let error as STTError {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            throw error
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            throw STTError.recordingFailed(error.localizedDescription)
        }
    }

    func stop() throws -> Data {
        guard let rec = recorder, let url = fileURL else {
            throw STTError.recordingFailed("stop called before start")
        }

        let duration = rec.currentTime
        rec.stop()
        self.recorder = nil
        self.fileURL = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        defer { try? FileManager.default.removeItem(at: url) }

        if duration >= Self.maxDuration {
            throw STTError.audioTooLong
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw STTError.recordingFailed("read wav: \(error.localizedDescription)")
        }
    }

    func isRecording() -> Bool {
        recorder?.isRecording ?? false
    }
}

// MARK: - Dependency

nonisolated extension AudioRecorder: DependencyKey {
    static let liveValue = AudioRecorder(
        requestPermission: { await LiveAudioRecorder.shared.requestPermission() },
        start: { try await LiveAudioRecorder.shared.start() },
        stop: { try await LiveAudioRecorder.shared.stop() },
        isRecording: { await LiveAudioRecorder.shared.isRecording() },
        cleanupOrphanedFiles: {
            AudioRecorder.cleanupOrphans(
                in: FileManager.default.temporaryDirectory,
                fileManager: .default
            )
        }
    )

    static let testValue = AudioRecorder(
        requestPermission: unimplemented("AudioRecorder.requestPermission", placeholder: false),
        start: unimplemented("AudioRecorder.start"),
        stop: unimplemented("AudioRecorder.stop", placeholder: Data()),
        isRecording: unimplemented("AudioRecorder.isRecording", placeholder: false),
        cleanupOrphanedFiles: unimplemented("AudioRecorder.cleanupOrphanedFiles")
    )

    /// Preview/테스트용 — 짧은 fake WAV 헤더만 반환.
    static let previewValue = AudioRecorder(
        requestPermission: { true },
        start: { },
        stop: {
            // Minimal WAV stub: 44-byte header + 0 samples. 실제 API는 거부하겠지만
            // UI 경로 테스트용으로만 쓰인다.
            Data(count: 44)
        },
        isRecording: { false },
        cleanupOrphanedFiles: { }
    )
}

extension DependencyValues {
    nonisolated var audioRecorder: AudioRecorder {
        get { self[AudioRecorder.self] }
        set { self[AudioRecorder.self] = newValue }
    }
}

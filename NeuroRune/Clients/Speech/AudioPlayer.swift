//
//  AudioPlayer.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 Slice 3 — MP3 바이트를 받아 재생. AVAudioPlayer 기반.
//  play는 재생 완료까지 await. stop 호출 시 `SpeechError.cancelled` throw.
//

import Foundation
import AVFAudio
import Dependencies

nonisolated struct AudioPlayer: Sendable {
    /// 재생 시작. 완료까지 await. 실패 시 `SpeechError` throw.
    var play: @Sendable (_ data: Data) async throws -> Void
    /// 재생 중이면 중단. 중단된 play는 `SpeechError.cancelled` throw.
    var stop: @Sendable () async -> Void
    /// 현재 재생 중인지.
    var isPlaying: @Sendable () async -> Bool
}

// MARK: - Live actor

/// AVAudioPlayer delegate 어댑터. 델리게이트는 NSObject여야 해 actor 외부에 둠.
private final class PlayerDelegateAdapter: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private let onFinished: @Sendable (Bool) -> Void

    nonisolated init(onFinished: @escaping @Sendable (Bool) -> Void) {
        self.onFinished = onFinished
        super.init()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinished(flag)
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onFinished(false)
    }
}

private actor LiveAudioPlayer {
    static let shared = LiveAudioPlayer()

    private var player: AVAudioPlayer?
    private var delegate: PlayerDelegateAdapter?
    private var continuation: CheckedContinuation<Void, Error>?

    func play(_ data: Data) async throws {
        // 기존 재생 중이면 먼저 정리
        await stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            throw SpeechError.playbackFailed("session: \(error.localizedDescription)")
        }

        let p: AVAudioPlayer
        do {
            p = try AVAudioPlayer(data: data)
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            throw SpeechError.decoding(error.localizedDescription)
        }

        let del = PlayerDelegateAdapter { [weak self] success in
            Task { await self?.finish(success: success) }
        }
        p.delegate = del
        p.prepareToPlay()

        guard p.play() else {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            throw SpeechError.playbackFailed("AVAudioPlayer.play() returned false")
        }

        self.player = p
        self.delegate = del

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
        }
    }

    private func finish(success: Bool) {
        let cont = continuation
        continuation = nil
        cleanup()
        if success {
            cont?.resume(returning: ())
        } else {
            cont?.resume(throwing: SpeechError.playbackFailed("playback did not finish successfully"))
        }
    }

    func stop() {
        guard player != nil else { return }
        let cont = continuation
        continuation = nil
        player?.stop()
        cleanup()
        cont?.resume(throwing: SpeechError.cancelled)
    }

    func isPlaying() -> Bool {
        player?.isPlaying ?? false
    }

    private func cleanup() {
        player = nil
        delegate = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

// MARK: - Dependency

nonisolated extension AudioPlayer: DependencyKey {
    static let liveValue = AudioPlayer(
        play: { try await LiveAudioPlayer.shared.play($0) },
        stop: { await LiveAudioPlayer.shared.stop() },
        isPlaying: { await LiveAudioPlayer.shared.isPlaying() }
    )

    static let testValue = AudioPlayer(
        play: unimplemented("AudioPlayer.play"),
        stop: unimplemented("AudioPlayer.stop"),
        isPlaying: unimplemented("AudioPlayer.isPlaying", placeholder: false)
    )

    static let previewValue = AudioPlayer(
        play: { _ in },
        stop: { },
        isPlaying: { false }
    )
}

extension DependencyValues {
    nonisolated var audioPlayer: AudioPlayer {
        get { self[AudioPlayer.self] }
        set { self[AudioPlayer.self] = newValue }
    }
}

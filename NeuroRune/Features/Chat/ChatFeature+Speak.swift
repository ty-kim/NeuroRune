//
//  ChatFeature+Speak.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — TTS 재생 관련 action 처리.
//

import Foundation
import ComposableArchitecture

nonisolated extension ChatFeature {

    /// TTS 관련 action 전담 reducer. main `reduce`에서 위임받음.
    /// 크게 세 영역: Manual playback / Sentence queue / Speech settings.
    func reduceSpeak(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        // MARK: - Manual playback (사용자가 버블 🔊 탭)

        case let .speakTapped(id):
            // 스트리밍 중엔 재생 X (응답 완료 후만)
            guard !state.isStreaming else { return .none }

            // 같은 메시지 다시 탭 → 토글 off
            if state.speakingMessageID == id {
                return .send(.stopSpeakTapped)
            }

            // assistant 메시지만 재생 대상
            guard let message = state.conversation.messages.first(where: { $0.id == id }),
                  message.role == .assistant,
                  !message.content.isEmpty else {
                return .none
            }

            let text = speechPlainText(from: message.content)
            guard !text.isEmpty else { return .none }
            state.speakError = nil
            // 수동 재생은 문장 큐를 덮어씀
            state.speakQueue = []
            state.isSpeakingQueue = false

            let settings = state.speechSettings

            return .run { send in
                @Dependency(\.speakerClient) var speaker
                @Dependency(\.audioPlayer) var player

                let voice = settings.voiceName
                let bcp47 = settings.bcp47Language

                // 기존 재생 중단 (cancelled throw, stopSpeakTapped가 이미 처리)
                await player.stop()

                do {
                    let audio = try await speaker.synthesize(text, voice, bcp47, settings.rate, settings.pitch)
                    await send(.speakingStarted(id))
                    try await player.play(audio)
                    await send(.speakingFinished)
                } catch SpeechError.cancelled {
                    // 정상 취소 — stop 또는 새 탭에 의한 교체. 에러 표시 X.
                } catch let e as SpeechError {
                    await send(.speakErrorOccurred(e))
                } catch {
                    await send(.speakErrorOccurred(.network(error.localizedDescription)))
                }
            }
            .cancellable(id: CancelID.speaking, cancelInFlight: true)

        case let .speakingStarted(id):
            state.speakingMessageID = id
            state.speakError = nil
            return .none

        case .speakingFinished:
            state.speakingMessageID = nil
            return .none

        case .stopSpeakTapped:
            state.speakingMessageID = nil
            state.speakQueue = []
            state.isSpeakingQueue = false
            state.speakBuffer = ""
            return .merge(
                .cancel(id: CancelID.speaking),
                .run { _ in
                    @Dependency(\.audioPlayer) var player
                    await player.stop()
                }
            )

        case let .speakErrorOccurred(error):
            state.speakingMessageID = nil
            state.isSpeakingQueue = false
            state.speakQueue = []
            state.speakBuffer = ""
            state.speakError = error
            return .none

        case .speakErrorDismissed:
            state.speakError = nil
            return .none

        // MARK: - Sentence queue (autoSpeak 스트리밍 모드, Phase 22.5)

        case let .speakSentenceEnqueued(sentence):
            let cleaned = speechPlainText(from: sentence)
            guard !cleaned.isEmpty else { return .none }
            state.speakQueue.append(cleaned)
            if !state.isSpeakingQueue {
                return .send(.processSpeakQueue)
            }
            return .none

        case .processSpeakQueue:
            guard !state.speakQueue.isEmpty else {
                state.isSpeakingQueue = false
                return .none
            }
            state.isSpeakingQueue = true
            let sentence = state.speakQueue.removeFirst()
            let settings = state.speechSettings
            return .run { send in
                @Dependency(\.speakerClient) var speaker
                @Dependency(\.audioPlayer) var player
                do {
                    let audio = try await speaker.synthesize(
                        sentence,
                        settings.voiceName,
                        settings.bcp47Language,
                        settings.rate,
                        settings.pitch
                    )
                    try await player.play(audio)
                    await send(.sentencePlaybackCompleted)
                } catch SpeechError.cancelled {
                    // stop 또는 새 탭에 의한 취소 — 완료로 처리하고 큐 진행
                    await send(.sentencePlaybackCompleted)
                } catch let e as SpeechError {
                    await send(.speakErrorOccurred(e))
                } catch {
                    await send(.speakErrorOccurred(.network(error.localizedDescription)))
                }
            }
            .cancellable(id: CancelID.speaking, cancelInFlight: false)

        case .sentencePlaybackCompleted:
            state.isSpeakingQueue = false
            if !state.speakQueue.isEmpty {
                return .send(.processSpeakQueue)
            }
            return .none

        // MARK: - Speech settings (voice / rate / pitch / autoSpeak)

        case .loadSpeechSettings:
            return .run { send in
                @Dependency(\.speechSettingsClient) var client
                let settings = client.load()
                await send(.speechSettingsLoaded(settings))
            }

        case let .speechSettingsLoaded(settings):
            state.speechSettings = settings
            return .none

        case let .speechVoiceSelected(name):
            state.speechSettings.voiceName = name
            return persistSettings(state.speechSettings)

        case let .autoSpeakToggled(on):
            state.speechSettings.autoSpeak = on
            return persistSettings(state.speechSettings)

        case let .speechRateChanged(rate):
            state.speechSettings.rate = rate
            return persistSettings(state.speechSettings)

        case let .speechPitchChanged(pitch):
            state.speechSettings.pitch = pitch
            return persistSettings(state.speechSettings)

        case .speechSettingsTapped:
            state.showSpeechSettings = true
            return .none

        case .speechSettingsDismissed:
            state.showSpeechSettings = false
            return .none

        default:
            return .none
        }
    }

    private func persistSettings(_ settings: SpeechSettings) -> Effect<Action> {
        .run { _ in
            @Dependency(\.speechSettingsClient) var client
            client.save(settings)
        }
    }
}

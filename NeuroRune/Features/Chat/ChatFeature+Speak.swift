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
    func reduceSpeak(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
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

            return .run { send in
                @Dependency(\.speakerClient) var speaker
                @Dependency(\.audioPlayer) var player
                @Dependency(\.locale) var locale

                let languageCode = locale.language.languageCode?.identifier ?? "ko"
                let (voice, bcp47) = defaultVoice(for: languageCode)

                // 기존 재생 중단 (cancelled throw, stopSpeakTapped가 이미 처리)
                await player.stop()

                do {
                    let audio = try await speaker.synthesize(text, voice, bcp47, 1.0, 1.0)
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
            return .merge(
                .cancel(id: CancelID.speaking),
                .run { _ in
                    @Dependency(\.audioPlayer) var player
                    await player.stop()
                }
            )

        case let .speakErrorOccurred(error):
            state.speakingMessageID = nil
            state.speakError = error
            return .none

        case .speakErrorDismissed:
            state.speakError = nil
            return .none

        default:
            return .none
        }
    }
}

/// 언어 코드 기반 기본 Azure voice 매핑. Slice 7에서 사용자 선택으로 대체.
nonisolated private func defaultVoice(for languageCode: String) -> (voice: String, bcp47: String) {
    switch languageCode {
    case "en": return ("en-US-JennyNeural", "en-US")
    case "ja": return ("ja-JP-NanamiNeural", "ja-JP")
    case "zh": return ("zh-CN-XiaoxiaoNeural", "zh-CN")
    default:   return ("ko-KR-SunHiNeural", "ko-KR")
    }
}

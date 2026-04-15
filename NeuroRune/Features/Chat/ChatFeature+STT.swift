//
//  ChatFeature+STT.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — STT 관련 action 처리를 main reducer에서 분리.
//  구조적 분할 (behavior 동일). 테스트 파일 `ChatFeatureTests+STT.swift`와 대칭.
//

import Foundation
import ComposableArchitecture

nonisolated extension ChatFeature {

    /// STT 관련 action 전담 reducer. main `reduce`에서 위임받음.
    func reduceSTT(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .micTapped:
            @Dependency(\.audioRecorder) var recorder
            if state.isRecording {
                // 중단 → stop → transcribe 파이프라인
                return .run { send in
                    do {
                        let data = try await recorder.stop()
                        await send(.recordingStopped(data))
                    } catch let e as STTError {
                        await send(.sttErrorOccurred(e))
                    } catch {
                        await send(.sttErrorOccurred(.recordingFailed(error.localizedDescription)))
                    }
                }
            } else {
                // 권한 → 시작
                return .run { send in
                    let granted = await recorder.requestPermission()
                    guard granted else {
                        await send(.sttErrorOccurred(.microphonePermissionDenied))
                        return
                    }
                    do {
                        try await recorder.start()
                        await send(.recordingStarted)
                    } catch let e as STTError {
                        await send(.sttErrorOccurred(e))
                    } catch {
                        await send(.sttErrorOccurred(.recordingFailed(error.localizedDescription)))
                    }
                }
            }

        case .recordingStarted:
            state.isRecording = true
            state.sttError = nil
            return .none

        case let .recordingStopped(audio):
            state.isRecording = false
            @Dependency(\.locale) var locale
            // BCP-47 언어 부분만. zh-Hans/zh-Hant는 "zh"로 축약 → Whisper 간체/번체 구분 안 함.
            let language = locale.language.languageCode?.identifier ?? "ko"
            return .run { send in
                @Dependency(\.sttClient) var stt
                do {
                    let result = try await stt.transcribe(audio, language)
                    await send(.transcribed(result))
                } catch let e as STTError {
                    await send(.sttErrorOccurred(e))
                } catch {
                    await send(.sttErrorOccurred(.network(error.localizedDescription)))
                }
            }

        case let .transcribed(result):
            // 전사 텍스트를 inputText에 삽입. 기존 내용이 있으면 공백 구분자로 이어붙임.
            if state.inputText.isEmpty {
                state.inputText = result.text
            } else {
                state.inputText += " " + result.text
            }
            return .none

        case let .sttErrorOccurred(error):
            state.isRecording = false
            state.sttError = error
            return .none

        case .sttErrorDismissed:
            state.sttError = nil
            return .none

        default:
            // STT 외 action은 main reducer에서 처리.
            return .none
        }
    }
}

//
//  ChatFeatureTests+STT.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 21 Step C — 마이크 버튼 / 녹음 / 전사 파이프라인 테스트.
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

extension ChatFeatureTests {

    // MARK: - State 초기값

    @Test("초기 state.isRecording == false, sttError == nil")
    func initialSTTState() {
        let s = makeState()
        #expect(s.isRecording == false)
        #expect(s.sttError == nil)
    }

    // MARK: - 권한 거부

    @Test("권한 거부 시 micTapped → sttError.microphonePermissionDenied")
    func micPermissionDenied() async {
        let store = TestStore(initialState: makeState()) { ChatFeature() } withDependencies: {
            $0.audioRecorder = AudioRecorder(
                requestPermission: { false },
                start: { Issue.record("start should not be called"); return },
                stop: { Data() },
                isRecording: { false }
            )
        }
        store.exhaustivity = .off

        await store.send(.micTapped)
        await store.receive(.sttErrorOccurred(.microphonePermissionDenied)) {
            $0.sttError = .microphonePermissionDenied
        }
    }

    // MARK: - 녹음 시작

    @Test("권한 OK + 녹음 시작 성공 → isRecording = true")
    func micTappedStartsRecording() async {
        let store = TestStore(initialState: makeState()) { ChatFeature() } withDependencies: {
            $0.audioRecorder = AudioRecorder(
                requestPermission: { true },
                start: { },
                stop: { Data() },
                isRecording: { false }
            )
        }
        store.exhaustivity = .off

        await store.send(.micTapped)
        await store.receive(.recordingStarted) {
            $0.isRecording = true
            $0.sttError = nil
        }
    }

    @Test("녹음 시작 실패 → sttError.recordingFailed")
    func micStartThrows() async {
        let store = TestStore(initialState: makeState()) { ChatFeature() } withDependencies: {
            $0.audioRecorder = AudioRecorder(
                requestPermission: { true },
                start: { throw STTError.recordingFailed("engine down") },
                stop: { Data() },
                isRecording: { false }
            )
        }
        store.exhaustivity = .off

        await store.send(.micTapped)
        await store.receive(.sttErrorOccurred(.recordingFailed("engine down"))) {
            $0.sttError = .recordingFailed("engine down")
        }
    }

    // MARK: - 녹음 종료 + 전사

    @Test("녹음 중 micTapped → stop → transcribed → inputText 삽입")
    func micTappedStopsAndTranscribes() async {
        var state = makeState()
        state.isRecording = true

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            $0.locale = Locale(identifier: "ko_KR")
            $0.audioRecorder = AudioRecorder(
                requestPermission: { true },
                start: { },
                stop: { Data([0xAB, 0xCD]) },
                isRecording: { true }
            )
            $0.sttClient = STTClient(
                transcribe: { audio, lang in
                    #expect(audio == Data([0xAB, 0xCD]))
                    #expect(lang == "ko")
                    return STTResult(text: "변환된 텍스트")
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.micTapped)
        await store.receive(.recordingStopped(Data([0xAB, 0xCD]))) {
            $0.isRecording = false
        }
        await store.receive(.transcribed(STTResult(text: "변환된 텍스트"))) {
            $0.inputText = "변환된 텍스트"
        }
    }

    @Test("기존 inputText가 있으면 공백 + 전사 텍스트 이어붙임")
    func transcribedAppendsToExistingText() async {
        var state = makeState(inputText: "안녕")
        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.transcribed(STTResult(text: "반가워요"))) {
            $0.inputText = "안녕 반가워요"
        }
    }

    @Test("빈 inputText면 공백 없이 전사 텍스트가 그대로")
    func transcribedOnEmptyText() async {
        let store = TestStore(initialState: makeState()) { ChatFeature() }

        await store.send(.transcribed(STTResult(text: "처음 텍스트"))) {
            $0.inputText = "처음 텍스트"
        }
    }

    @Test("STT 전사 실패 → sttError")
    func transcribeFailure() async {
        var state = makeState()
        state.isRecording = true

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            $0.locale = Locale(identifier: "ko_KR")
            $0.audioRecorder = AudioRecorder(
                requestPermission: { true },
                start: { },
                stop: { Data() },
                isRecording: { true }
            )
            $0.sttClient = STTClient(
                transcribe: { _, _ in
                    throw STTError.unauthorized
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.micTapped)
        await store.receive(.recordingStopped(Data())) {
            $0.isRecording = false
        }
        await store.receive(.sttErrorOccurred(.unauthorized)) {
            $0.sttError = .unauthorized
        }
    }

    // MARK: - 에러 해제

    @Test("sttErrorDismissed는 sttError를 nil로 만든다")
    func sttErrorDismissed() async {
        var state = makeState()
        state.sttError = .rateLimited
        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.sttErrorDismissed) {
            $0.sttError = nil
        }
    }

    // MARK: - 직접 액션

    @Test("recordingStarted 단독 액션은 isRecording=true + sttError 클리어")
    func recordingStartedDirectly() async {
        var state = makeState()
        state.sttError = .network("prev")
        let store = TestStore(initialState: state) { ChatFeature() }

        await store.send(.recordingStarted) {
            $0.isRecording = true
            $0.sttError = nil
        }
    }
}

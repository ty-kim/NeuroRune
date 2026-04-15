//
//  ChatFeatureTests+Speak.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Phase 22 Slice 8 — autoSpeak + streamFinished 분기 테스트.
//

import Foundation
import Testing
import ComposableArchitecture
@testable import NeuroRune

@MainActor
extension ChatFeatureTests {

    @Test("streamFinished: autoSpeak=false면 speakTapped 발행 X")
    func streamFinishedNoAutoSpeak() async {
        var state = makeState()
        state.isStreaming = true
        state.speechSettings.autoSpeak = false
        state.conversation = state.conversation.appending(Self.assistantMsg("응답 완료"))

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.streamFinished) {
            $0.isStreaming = false
        }
        // save는 불리지만 .speakTapped는 발행되지 않아야 함 → 수신 안 함
    }

    @Test("streamFinished: autoSpeak=true + assistant 메시지면 speakTapped 자동 발행")
    func streamFinishedAutoSpeakTriggers() async {
        var state = makeState()
        state.isStreaming = true
        state.speechSettings.autoSpeak = true
        let assistant = Self.assistantMsg("응답 내용")
        state.conversation = state.conversation.appending(assistant)

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
            // speakTapped effect가 speakerClient/audioPlayer 호출 → test-unimplemented 회피 stub
            $0.speakerClient.synthesize = { @Sendable _, _, _, _, _ in Data() }
            $0.audioPlayer.stop = { @Sendable in }
            $0.audioPlayer.play = { @Sendable _ in }
            $0.audioPlayer.isPlaying = { @Sendable in false }
        }
        store.exhaustivity = .off

        await store.send(.streamFinished) {
            $0.isStreaming = false
        }
        await store.receive(.speakTapped(assistant.id))
    }

    @Test("streamFinished: autoSpeak=true이지만 마지막이 user면 speakTapped X")
    func streamFinishedAutoSpeakSkipsUserLast() async {
        var state = makeState()
        state.isStreaming = true
        state.speechSettings.autoSpeak = true
        state.conversation = state.conversation.appending(Self.userMsg("질문만"))

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.streamFinished) {
            $0.isStreaming = false
        }
        // speakTapped 수신 없음
    }

    @Test("streamFinished: autoSpeak=true이지만 assistant 내용이 빈 문자열이면 speakTapped X")
    func streamFinishedAutoSpeakSkipsEmptyAssistant() async {
        var state = makeState()
        state.isStreaming = true
        state.speechSettings.autoSpeak = true
        state.conversation = state.conversation.appending(Self.assistantMsg(""))

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.streamFinished) {
            $0.isStreaming = false
        }
    }

    @Test("speakTapped: isStreaming이면 no-op")
    func speakTappedNoOpWhenStreaming() async {
        var state = makeState()
        state.isStreaming = true
        let assistant = Self.assistantMsg("abc")
        state.conversation = state.conversation.appending(assistant)

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
        }

        await store.send(.speakTapped(assistant.id))
        // effect 없음, state 변경 없음
    }

    @Test("speakTapped 같은 id 재탭 → stopSpeakTapped로 토글 off")
    func speakTappedSameIdTogglesOff() async {
        var state = makeState()
        let assistant = Self.assistantMsg("abc")
        state.conversation = state.conversation.appending(assistant)
        state.speakingMessageID = assistant.id

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
            $0.audioPlayer.stop = { @Sendable in }
        }
        store.exhaustivity = .off

        await store.send(.speakTapped(assistant.id))
        await store.receive(.stopSpeakTapped) {
            $0.speakingMessageID = nil
        }
    }

    @Test("loadSpeechSettings → speechSettingsLoaded 로 state 반영")
    func loadSpeechSettingsRoundtrip() async {
        let store = TestStore(initialState: makeState()) { ChatFeature() } withDependencies: {
            $0.speechSettingsClient.load = {
                SpeechSettings(voiceName: "en-US-JennyNeural", rate: 1.2, pitch: 1.1, autoSpeak: true)
            }
        }

        await store.send(.loadSpeechSettings)
        await store.receive(.speechSettingsLoaded(SpeechSettings(
            voiceName: "en-US-JennyNeural", rate: 1.2, pitch: 1.1, autoSpeak: true
        ))) {
            $0.speechSettings = SpeechSettings(
                voiceName: "en-US-JennyNeural", rate: 1.2, pitch: 1.1, autoSpeak: true
            )
        }
    }
}

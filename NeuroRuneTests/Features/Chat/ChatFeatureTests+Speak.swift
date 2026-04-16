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

    @Test("autoSpeak + streamChunkReceived: 완성된 문장이 큐에 enqueue")
    func autoSpeakEnqueuesSentenceFromChunk() async {
        var state = makeState()
        state.isStreaming = true
        state.speechSettings.autoSpeak = true
        state.conversation = state.conversation.appending(Self.assistantMsg(""))

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
            $0.speakerClient.synthesize = { @Sendable _, _, _, _, _ in Data() }
            $0.audioPlayer.stop = { @Sendable in }
            $0.audioPlayer.play = { @Sendable _ in }
            $0.audioPlayer.isPlaying = { @Sendable in false }
        }
        store.exhaustivity = .off

        await store.send(.streamChunkReceived("안녕하세요. "))
        await store.receive(.speakSentenceEnqueued("안녕하세요."))
    }

    @Test("streamFinished: autoSpeak + 버퍼 잔여 → 마지막 문장 flush")
    func streamFinishedFlushesBuffer() async {
        var state = makeState()
        state.isStreaming = true
        state.speechSettings.autoSpeak = true
        state.speakBuffer = "마지막 문장"
        state.conversation = state.conversation.appending(Self.assistantMsg("마지막 문장"))

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
            $0.speakerClient.synthesize = { @Sendable _, _, _, _, _ in Data() }
            $0.audioPlayer.stop = { @Sendable in }
            $0.audioPlayer.play = { @Sendable _ in }
            $0.audioPlayer.isPlaying = { @Sendable in false }
        }
        store.exhaustivity = .off

        await store.send(.streamFinished) {
            $0.isStreaming = false
            $0.speakBuffer = ""
        }
        await store.receive(.speakSentenceEnqueued("마지막 문장"))
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
    
    @Test("speakSentenceEnqueued: 문장이 최대 길이 초과면 drop")
    func enqueueDropsOversizedSentence() async {
        var state = makeState()
        state.speechSettings.autoSpeak = true

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
        }
        store.exhaustivity = .off

        let huge = String(repeating: "가", count: SpeechBudget.maxSentenceChars + 1)
        await store.send(.speakSentenceEnqueued(huge))
        // speakQueue는 비어 있어야 함 (상태 변화 없음)
        #expect(store.state.speakQueue.isEmpty)
    }
    
    @Test("speakSentenceEnqueued: 큐가 가득 차면 신규 drop")
    func enqueueDropsWhenQueueFull() async {
        var state = makeState()
        state.speechSettings.autoSpeak = true
        state.isSpeakingQueue = true  // 자동 processSpeakQueue 억제
        state.speakQueue = Array(repeating: "채움", count: SpeechBudget.maxQueueCount)

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.speakSentenceEnqueued("새 문장"))
        #expect(store.state.speakQueue.count == SpeechBudget.maxQueueCount)
    }
    
    @Test("speakSentenceEnqueued: 누적 문자 cap 초과분 drop")
    func enqueueDropsWhenTotalCharsCapped() async {
        var state = makeState()
        state.speechSettings.autoSpeak = true
        state.isSpeakingQueue = true
        state.speakTotalChars = SpeechBudget.maxTotalCharsPerResponse - 10

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
          applyDefaultDependencies(&$0)
        }
        store.exhaustivity = .off

        let sentence = String(repeating: "가", count: 20)  // cap 넘김
        await store.send(.speakSentenceEnqueued(sentence))
        #expect(store.state.speakQueue.isEmpty)
        #expect(store.state.speakTotalChars == SpeechBudget.maxTotalCharsPerResponse - 10)
    }
    
    @Test("sendTapped: speakTotalChars 리셋")
    func sendTappedResetsTotalChars() async {
        var state = makeState()
        state.inputText = "hi"
        state.speakTotalChars = 1234

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
            // 네트워크 차단하고 싶으면 llmClient.streamMessage stub
        }
        store.exhaustivity = .off

        await store.send(.sendTapped)
        #expect(store.state.speakTotalChars == 0)
    }

    @Test("speakTapped: text가 응답당 cap 초과면 tooLong 에러")
    func speakTappedTooLong() async {
        let huge = String(repeating: "가", count: SpeechBudget.maxTotalCharsPerResponse + 1)
        var state = makeState()
        state.conversation = state.conversation.appending(Self.assistantMsg(huge))
        let id = state.conversation.messages.last!.id

        let store = TestStore(initialState: state) { ChatFeature() } withDependencies: {
            applyDefaultDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.speakTapped(id)) {
            $0.speakError = .tooLong
        }
        #expect(store.state.speakQueue.isEmpty)
        #expect(store.state.speakingMessageID == nil)
    }
}

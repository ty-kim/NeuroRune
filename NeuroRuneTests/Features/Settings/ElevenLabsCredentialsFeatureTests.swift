//
//  ElevenLabsCredentialsFeatureTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Foundation
import Testing
import ComposableArchitecture
@testable import NeuroRune

@MainActor
struct ElevenLabsCredentialsFeatureTests {

    @Test("apiKeyChanged: 값 반영 + error 해제")
    func apiKeyChanged() async {
        var state = ElevenLabsCredentialsFeature.State()
        state.error = "prev"
        let store = TestStore(initialState: state) { ElevenLabsCredentialsFeature() }

        await store.send(.apiKeyChanged("sk_abc")) {
            $0.apiKey = "sk_abc"
            $0.error = nil
        }
    }

    @Test("유효한 apiKey면 isValid=true")
    func isValidCheck() {
        var s = ElevenLabsCredentialsFeature.State()
        s.apiKey = "  "
        #expect(!s.isValid)
        s.apiKey = "sk"
        #expect(s.isValid)
    }

    @Test("saveTapped: client.save 호출 + saveSucceeded")
    func saveSuccess() async {
        var state = ElevenLabsCredentialsFeature.State()
        state.apiKey = "sk_abc"

        let saved = LockIsolated<ElevenLabsCredentials?>(nil)
        let store = TestStore(initialState: state) { ElevenLabsCredentialsFeature() } withDependencies: {
            $0.elevenLabsCredentialsClient = ElevenLabsCredentialsClient(
                load: { nil },
                save: { c in saved.setValue(c) },
                clear: { }
            )
        }
        store.exhaustivity = .off

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.apiKey = ""
        }
        #expect(saved.value == ElevenLabsCredentials(apiKey: "sk_abc"))
    }

    @Test("saveTapped 실패 → saveFailed 에러 메시지")
    func saveFailure() async {
        struct Boom: LocalizedError { var errorDescription: String? { "disk full" } }
        var state = ElevenLabsCredentialsFeature.State()
        state.apiKey = "sk"

        let store = TestStore(initialState: state) { ElevenLabsCredentialsFeature() } withDependencies: {
            $0.elevenLabsCredentialsClient = ElevenLabsCredentialsClient(
                load: { nil },
                save: { _ in throw Boom() },
                clear: { }
            )
        }
        store.exhaustivity = .off

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(.saveFailed("disk full")) {
            $0.isSaving = false
            $0.error = "disk full"
        }
    }

    @Test("clearTapped: client.clear + apiKey 리셋")
    func clearFlow() async {
        var state = ElevenLabsCredentialsFeature.State()
        state.apiKey = "sk_abc"

        let cleared = LockIsolated<Bool>(false)
        let store = TestStore(initialState: state) { ElevenLabsCredentialsFeature() } withDependencies: {
            $0.elevenLabsCredentialsClient = ElevenLabsCredentialsClient(
                load: { nil },
                save: { _ in },
                clear: { cleared.setValue(true) }
            )
        }
        store.exhaustivity = .off

        await store.send(.clearTapped)
        await store.receive(.cleared) { $0.apiKey = "" }
        #expect(cleared.value)
    }

    @Test("loadExisting → existingLoaded: apiKey 복원")
    func loadExisting() async {
        let store = TestStore(initialState: ElevenLabsCredentialsFeature.State()) {
            ElevenLabsCredentialsFeature()
        } withDependencies: {
            $0.elevenLabsCredentialsClient = ElevenLabsCredentialsClient(
                load: { ElevenLabsCredentials(apiKey: "sk_saved") },
                save: { _ in },
                clear: { }
            )
        }
        store.exhaustivity = .off

        await store.send(.loadExisting)
        await store.receive(.existingLoaded(ElevenLabsCredentials(apiKey: "sk_saved"))) {
            $0.apiKey = "sk_saved"
        }
    }
}

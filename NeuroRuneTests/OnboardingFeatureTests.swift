//
//  OnboardingFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

@Suite(.serialized)
@MainActor
struct OnboardingFeatureTests {

    @Test("초기 State: apiKeyInput 빈 문자열, isValid false, error nil")
    func initialStateDefaults() {
        let state = OnboardingFeature.State()
        #expect(state.apiKeyInput == "")
        #expect(state.isValid == false)
        #expect(state.error == nil)
        #expect(state.isSaving == false)
    }

    @Test("apiKeyChanged는 apiKeyInput을 업데이트한다")
    func apiKeyChangedUpdatesInput() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.apiKeyChanged("sk-ant-test")) {
            $0.apiKeyInput = "sk-ant-test"
        }
    }

    @Test("빈 문자열 input은 isValid false")
    func emptyInputIsInvalid() {
        let state = OnboardingFeature.State(apiKeyInput: "")
        #expect(state.isValid == false)
    }

    @Test("sk-ant-로 시작하는 input은 isValid true")
    func validPrefixMakesStateValid() {
        let state = OnboardingFeature.State(apiKeyInput: "sk-ant-abc123")
        #expect(state.isValid == true)
    }

    @Test("saveTapped는 anthropic_api_key 키로 Keychain에 저장한다")
    func saveTappedCallsKeychainSave() async {
        let savedKey = LockIsolated<String?>(nil)
        let savedValue = LockIsolated<String?>(nil)

        let store = TestStore(
            initialState: OnboardingFeature.State(apiKeyInput: "sk-ant-valid")
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.keychainClient.save = { @Sendable key, value in
                savedKey.setValue(key)
                savedValue.setValue(value)
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
        }

        #expect(savedKey.value == "anthropic_api_key")
        #expect(savedValue.value == "sk-ant-valid")
    }

    @Test("Keychain save 실패 시 state.error에 메시지가 세팅된다")
    func saveFailureSetsError() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(apiKeyInput: "sk-ant-valid")
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.keychainClient.save = { @Sendable _, _ in
                throw KeychainError.unhandled(status: -25300)
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveFailed(KeychainError.unhandled(status: -25300).localizedDescription)) {
            $0.isSaving = false
            $0.error = KeychainError.unhandled(status: -25300).localizedDescription
        }
    }

    @Test("isValid false일 때 saveTapped는 아무 효과 없음")
    func saveTappedNoOpWhenInvalid() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(apiKeyInput: "")
        ) {
            OnboardingFeature()
        }

        await store.send(.saveTapped)
        // State 변화 없음, Effect 없음
    }
}

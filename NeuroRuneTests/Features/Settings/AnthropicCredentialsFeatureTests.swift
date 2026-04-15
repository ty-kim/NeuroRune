//
//  AnthropicCredentialsFeatureTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

@Suite(.serialized)
@MainActor
struct AnthropicCredentialsFeatureTests {

    @Test("초기 State: apiKey 빈 문자열, isValid false, error nil")
    func initialStateDefaults() {
        let state = AnthropicCredentialsFeature.State()
        #expect(state.apiKey == "")
        #expect(state.isValid == false)
        #expect(state.error == nil)
        #expect(state.isSaving == false)
    }

    @Test("apiKeyChanged는 apiKey을 업데이트한다")
    func apiKeyChangedUpdatesInput() async {
        let store = TestStore(initialState: AnthropicCredentialsFeature.State()) {
            AnthropicCredentialsFeature()
        }

        await store.send(.apiKeyChanged("sk-ant-test")) {
            $0.apiKey = "sk-ant-test"
        }
    }

    @Test("빈 문자열 input은 isValid false")
    func emptyInputIsInvalid() {
        let state = AnthropicCredentialsFeature.State(apiKey: "")
        #expect(state.isValid == false)
    }

    @Test("sk-ant-로 시작하는 input은 isValid true")
    func validPrefixMakesStateValid() {
        let state = AnthropicCredentialsFeature.State(apiKey: "sk-ant-abc123")
        #expect(state.isValid == true)
    }

    @Test("saveTapped는 anthropic_api_key 키로 Keychain에 저장한다")
    func saveTappedCallsKeychainSave() async {
        let savedKey = LockIsolated<String?>(nil)
        let savedValue = LockIsolated<String?>(nil)

        let store = TestStore(
            initialState: AnthropicCredentialsFeature.State(apiKey: "sk-ant-valid")
        ) {
            AnthropicCredentialsFeature()
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
            $0.apiKey = ""
        }

        #expect(savedKey.value == "anthropic_api_key")
        #expect(savedValue.value == "sk-ant-valid")
    }

    @Test("Keychain save 실패 시 state.error에 메시지가 세팅된다")
    func saveFailureSetsError() async {
        let store = TestStore(
            initialState: AnthropicCredentialsFeature.State(apiKey: "sk-ant-valid")
        ) {
            AnthropicCredentialsFeature()
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

    @Test("saveTapped는 앞뒤 공백/개행을 trim하고 저장한다")
    func saveTappedTrimsWhitespace() async {
        let savedValue = LockIsolated<String?>(nil)

        let store = TestStore(
            initialState: AnthropicCredentialsFeature.State(apiKey: "  sk-ant-valid\n")
        ) {
            AnthropicCredentialsFeature()
        } withDependencies: {
            $0.keychainClient.save = { @Sendable _, value in
                savedValue.setValue(value)
            }
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.apiKey = ""
        }

        #expect(savedValue.value == "sk-ant-valid")
    }

    @Test("saveSucceeded는 apiKey을 clear한다")
    func saveSucceededClearsInput() async {
        let store = TestStore(
            initialState: AnthropicCredentialsFeature.State(apiKey: "sk-ant-abc")
        ) {
            AnthropicCredentialsFeature()
        }

        await store.send(.saveSucceeded) {
            $0.apiKey = ""
        }
    }

    @Test("isValid false일 때 saveTapped는 아무 효과 없음")
    func saveTappedNoOpWhenInvalid() async {
        let store = TestStore(
            initialState: AnthropicCredentialsFeature.State(apiKey: "")
        ) {
            AnthropicCredentialsFeature()
        }

        await store.send(.saveTapped)
    }
}

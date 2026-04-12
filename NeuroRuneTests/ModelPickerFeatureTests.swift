//
//  ModelPickerFeatureTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

@MainActor
struct ModelPickerFeatureTests {

    @Test("State는 availableModels와 selectedModel을 가진다")
    func stateHasRequiredFields() {
        let state = ModelPickerFeature.State(
            availableModels: LLMModel.allSupported,
            selectedModel: .opus46
        )

        #expect(state.availableModels == LLMModel.allSupported)
        #expect(state.selectedModel == .opus46)
    }

    @Test("availableModels는 opus46, sonnet46, haiku45 3개를 포함한다")
    func availableModelsContainsAllSupported() {
        let state = ModelPickerFeature.State(selectedModel: .opus46)

        #expect(state.availableModels.count == 3)
        #expect(state.availableModels.contains(.opus46))
        #expect(state.availableModels.contains(.sonnet46))
        #expect(state.availableModels.contains(.haiku45))
    }

    @Test(".modelSelected는 selectedModel을 업데이트한다")
    func modelSelectedUpdatesSelectedModel() async {
        let store = TestStore(
            initialState: ModelPickerFeature.State(selectedModel: .opus46)
        ) {
            ModelPickerFeature()
        }

        await store.send(.modelSelected(.haiku45)) {
            $0.selectedModel = .haiku45
        }
    }
}

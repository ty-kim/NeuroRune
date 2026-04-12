//
//  ModelPickerFeature.swift
//  NeuroRune
//

import Foundation
import ComposableArchitecture

nonisolated struct ModelPickerFeature: Reducer {

    struct State: Equatable {
        var availableModels: [LLMModel] = LLMModel.allSupported
        var selectedModel: LLMModel
    }

    enum Action: Equatable {
        case modelSelected(LLMModel)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .modelSelected(model):
            state.selectedModel = model
            return .none
        }
    }
}

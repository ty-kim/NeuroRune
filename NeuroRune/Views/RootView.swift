//
//  RootView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    @State private var hasApiKey = false
    @State private var isChecking = true

    var body: some View {
        Group {
            if isChecking {
                Color("DarkNavy")
                    .ignoresSafeArea()
            } else if hasApiKey {
                ConversationListView(
                    onApiKeyReset: { hasApiKey = false }
                )
            } else {
                OnboardingView(
                    store: Store(initialState: OnboardingFeature.State()) {
                        OnboardingFeature()
                    },
                    onComplete: { hasApiKey = true }
                )
            }
        }
        .task {
            let client = KeychainClient.liveValue
            let key = try? client.load(OnboardingFeature.anthropicKeyName)
            hasApiKey = key != nil
            isChecking = false
        }
    }
}

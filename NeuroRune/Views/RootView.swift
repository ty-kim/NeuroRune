//
//  RootView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    @State private var hasApiKey = false
    @State private var isChecking = true
    @State private var storageHealthy = true

    var body: some View {
        Group {
            if isChecking {
                Color("DarkNavy")
                    .ignoresSafeArea()
            } else if !storageHealthy {
                StorageErrorView()
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
            storageHealthy = await probeStorageHealth()

            let client = KeychainClient.liveValue
            let key = try? client.load(OnboardingFeature.anthropicKeyName)
            hasApiKey = key != nil
            isChecking = false
        }
    }

    private func probeStorageHealth() async -> Bool {
        do {
            _ = try await ConversationStore.liveValue.loadAll()
            return true
        } catch {
            return false
        }
    }
}

//
//  RootView.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    @State private var isChecking = true
    @State private var storageHealthy = true

    var body: some View {
        Group {
            if isChecking {
                Color("DarkNavy")
                    .ignoresSafeArea()
            } else if !storageHealthy {
                StorageErrorView()
            } else {
                ConversationListView(
                    store: Store(initialState: ConversationListFeature.State()) {
                        ConversationListFeature()
                    }
                )
            }
        }
        .task {
            storageHealthy = await probeStorageHealth()
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

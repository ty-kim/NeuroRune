//
//  MemoryHubView.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import ComposableArchitecture

struct MemoryHubView: View {

    @State private var globalStore = Store(
        initialState: MemoryListFeature.State(role: .global)
    ) {
        MemoryListFeature()
    }

    @State private var localStore = Store(
        initialState: MemoryListFeature.State(role: .local)
    ) {
        MemoryListFeature()
    }

    @State private var selectedRole: CredentialsRole = .global

    var body: some View {
        TabView(selection: $selectedRole) {
            MemoryListView(store: globalStore)
                .tabItem {
                    Label(
                        String(localized: "memory.tab.global"),
                        systemImage: "globe"
                    )
                }
                .tag(CredentialsRole.global)

            MemoryListView(store: localStore)
                .tabItem {
                    Label(
                        String(localized: "memory.tab.local"),
                        systemImage: "folder"
                    )
                }
                .tag(CredentialsRole.local)
        }
    }
}

#Preview {
    MemoryHubView()
}

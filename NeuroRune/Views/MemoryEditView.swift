//
//  MemoryEditView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct MemoryEditView: View {
    let store: StoreOf<MemoryEditFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if viewStore.isLoading {
                    ProgressView()
                } else {
                    TextEditor(text: viewStore.binding(
                        get: \.content,
                        send: MemoryEditFeature.Action.contentChanged
                    ))
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 4)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(viewStore.file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "onboarding.save")) {
                        viewStore.send(.saveTapped)
                    }
                    .disabled(!viewStore.hasUnsavedChanges || viewStore.isSaving)
                }
            }
            .task {
                await viewStore.send(.task).finish()
            }
            .alert(
                String(localized: "error.prefix"),
                isPresented: .init(
                    get: { viewStore.error != nil },
                    set: { if !$0 { viewStore.send(.errorDismissed) } }
                ),
                presenting: viewStore.error
            ) { _ in
                Button(String(localized: "error.cancel"), role: .cancel) {
                    viewStore.send(.errorDismissed)
                }
            } message: { message in
                Text(message)
            }
        }
    }
}

#Preview("Loading") {
    NavigationStack {
        MemoryEditView(
            store: Store(
                initialState: MemoryEditFeature.State(
                    file: GitHubFile(path: "memory/a.md", sha: "1", content: "", isDirectory: false)
                )
            ) {
                MemoryEditFeature()
            }
        )
    }
}

//
//  MemoryEditView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct MemoryEditView: View {
    let store: StoreOf<MemoryEditFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirm = false

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
            .navigationTitle(viewStore.hasUnsavedChanges ? "• \(viewStore.file.name)" : viewStore.file.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(viewStore.hasUnsavedChanges)
            .toolbar {
                if viewStore.hasUnsavedChanges {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showDiscardConfirm = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.backward")
                                Text(String(localized: "memory.title"))
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "onboarding.save")) {
                        viewStore.send(.saveTapped)
                    }
                    .disabled(!viewStore.hasUnsavedChanges || viewStore.isSaving)
                }
            }
            .confirmationDialog(
                String(localized: "memory.edit.discardTitle"),
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "memory.edit.discardConfirm"), role: .destructive) {
                    dismiss()
                }
                Button(String(localized: "error.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "memory.edit.discardMessage"))
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

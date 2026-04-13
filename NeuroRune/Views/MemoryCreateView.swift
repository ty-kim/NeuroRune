//
//  MemoryCreateView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct MemoryCreateView: View {
    let store: StoreOf<MemoryCreateFeature>
    var onCreated: (GitHubFile) -> Void = { _ in }
    var onCancel: () -> Void = {}

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        TextField(
                            String(localized: "memory.create.filename.placeholder"),
                            text: viewStore.binding(
                                get: \.filename,
                                send: MemoryCreateFeature.Action.filenameChanged
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    } header: {
                        Text(String(localized: "memory.create.filename"))
                    } footer: {
                        Text(String(localized: "memory.create.filename.footer"))
                    }

                    Section {
                        TextEditor(text: viewStore.binding(
                            get: \.content,
                            send: MemoryCreateFeature.Action.contentChanged
                        ))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    } header: {
                        Text(String(localized: "memory.create.content"))
                    }

                    if let error = viewStore.error {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle(String(localized: "memory.create.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "error.cancel")) {
                            onCancel()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "memory.create.save")) {
                            viewStore.send(.saveTapped)
                        }
                        .disabled(!viewStore.isValid || viewStore.isSaving)
                    }
                }
                .onChange(of: viewStore.createdFile) { _, file in
                    if let file {
                        onCreated(file)
                    }
                }
            }
        }
    }
}

#Preview {
    MemoryCreateView(
        store: Store(initialState: MemoryCreateFeature.State(basePath: "memory")) {
            MemoryCreateFeature()
        }
    )
}

//
//  GroqCredentialsView.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — Groq API 키 입력 화면. Whisper(STT)·향후 다른 Groq 서비스 공용.
//

import SwiftUI
import ComposableArchitecture

struct GroqCredentialsView: View {
    let store: StoreOf<GroqCredentialsFeature>
    var onSaved: () -> Void = {}

    @State private var isKeyRevealed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        HStack(spacing: 8) {
                            Group {
                                if isKeyRevealed {
                                    TextField(
                                        String(localized: "groq.apiKey.placeholder"),
                                        text: viewStore.binding(
                                            get: \.apiKey,
                                            send: GroqCredentialsFeature.Action.apiKeyChanged
                                        )
                                    )
                                } else {
                                    SecureField(
                                        String(localized: "groq.apiKey.placeholder"),
                                        text: viewStore.binding(
                                            get: \.apiKey,
                                            send: GroqCredentialsFeature.Action.apiKeyChanged
                                        )
                                    )
                                }
                            }
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                            Button {
                                isKeyRevealed.toggle()
                            } label: {
                                Image(systemName: isKeyRevealed ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(String(localized: "groq.apiKey"))
                    } footer: {
                        Text(String(localized: "groq.footer"))
                    }

                    if let error = viewStore.error {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if !viewStore.apiKey.isEmpty {
                        Section {
                            Button(role: .destructive) {
                                viewStore.send(.clearTapped)
                            } label: {
                                Text(String(localized: "groq.clear"))
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "groq.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "error.cancel")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "onboarding.save")) {
                            viewStore.send(.saveTapped)
                        }
                        .disabled(!viewStore.isValid || viewStore.isSaving)
                    }
                }
                .task {
                    await viewStore.send(.loadExisting).finish()
                }
                .onChange(of: viewStore.isSaving) { wasSaving, isSaving in
                    if wasSaving && !isSaving && viewStore.error == nil {
                        onSaved()
                    }
                }
            }
        }
    }
}

#Preview {
    GroqCredentialsView(
        store: Store(initialState: GroqCredentialsFeature.State()) {
            GroqCredentialsFeature()
        }
    )
}

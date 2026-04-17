//
//  ElevenLabsCredentialsView.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs TTS API 키 입력 화면. region 없고 apiKey만.
//

import SwiftUI
import ComposableArchitecture

struct ElevenLabsCredentialsView: View {
    let store: StoreOf<ElevenLabsCredentialsFeature>
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        SecureFieldWithReveal(
                            placeholder: String(localized: "elevenlabs.apiKey.placeholder"),
                            text: viewStore.binding(
                                get: \.apiKey,
                                send: ElevenLabsCredentialsFeature.Action.apiKeyChanged
                            )
                        )
                    } header: {
                        Text(String(localized: "elevenlabs.apiKey"))
                    } footer: {
                        Text(String(localized: "elevenlabs.footer"))
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
                                Text(String(localized: "elevenlabs.clear"))
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "elevenlabs.title"))
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
    ElevenLabsCredentialsView(
        store: Store(initialState: ElevenLabsCredentialsFeature.State()) {
            ElevenLabsCredentialsFeature()
        }
    )
}

//
//  AnthropicCredentialsView.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import ComposableArchitecture

struct AnthropicCredentialsView: View {
    let store: StoreOf<AnthropicCredentialsFeature>
    var onComplete: () -> Void = {}

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
                                    TextField("sk-ant-...", text: viewStore.binding(
                                        get: \.apiKey,
                                        send: AnthropicCredentialsFeature.Action.apiKeyChanged
                                    ))
                                } else {
                                    SecureField("sk-ant-...", text: viewStore.binding(
                                        get: \.apiKey,
                                        send: AnthropicCredentialsFeature.Action.apiKeyChanged
                                    ))
                                }
                            }
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityLabel(String(localized: "a11y.onboarding.apiKeyField"))
                            .accessibilityHint(String(localized: "a11y.onboarding.apiKeyHint"))

                            Button {
                                isKeyRevealed.toggle()
                            } label: {
                                Image(systemName: isKeyRevealed ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel(String(localized: isKeyRevealed ? "a11y.onboarding.hideKey" : "a11y.onboarding.revealKey"))
                        }
                    } header: {
                        Text("Anthropic API Key")
                    } footer: {
                        Text(String(localized: "onboarding.description"))
                    }

                    if let error = viewStore.error {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            viewStore.send(.clearTapped)
                        } label: {
                            Text(String(localized: "chat.resetApiKey"))
                        }
                    }
                }
                .navigationTitle(String(localized: "settings.anthropicKey"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "error.cancel")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if viewStore.isSaving {
                            ProgressView()
                        } else {
                            Button(String(localized: "onboarding.save")) {
                                viewStore.send(.saveTapped)
                            }
                            .disabled(!viewStore.isValid)
                        }
                    }
                }
                .task {
                    await viewStore.send(.loadExisting).finish()
                }
                .onChange(of: viewStore.isSaving) { wasSaving, isSaving in
                    if wasSaving && !isSaving && viewStore.error == nil {
                        onComplete()
                    }
                }
            }
        }
    }
}

#Preview {
    AnthropicCredentialsView(
        store: Store(initialState: AnthropicCredentialsFeature.State()) {
            AnthropicCredentialsFeature()
        }
    )
}

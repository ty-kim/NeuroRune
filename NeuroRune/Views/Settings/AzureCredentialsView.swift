//
//  AzureCredentialsView.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — Azure Speech Service API 키 입력 화면. TTS·향후 다른 Azure 음성 서비스 공용.
//

import SwiftUI
import ComposableArchitecture

struct AzureCredentialsView: View {
    let store: StoreOf<AzureCredentialsFeature>
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        SecureFieldWithReveal(
                            placeholder: String(localized: "azure.apiKey.placeholder"),
                            text: viewStore.binding(
                                get: \.apiKey,
                                send: AzureCredentialsFeature.Action.apiKeyChanged
                            )
                        )
                    } header: {
                        Text(String(localized: "azure.apiKey"))
                    }

                    Section {
                        TextField(
                            String(localized: "azure.region.placeholder"),
                            text: viewStore.binding(
                                get: \.region,
                                send: AzureCredentialsFeature.Action.regionChanged
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    } header: {
                        Text(String(localized: "azure.region"))
                    } footer: {
                        Text(String(localized: "azure.footer"))
                    }

                    if let error = viewStore.error {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if !viewStore.apiKey.isEmpty || !viewStore.region.isEmpty {
                        Section {
                            Button(role: .destructive) {
                                viewStore.send(.clearTapped)
                            } label: {
                                Text(String(localized: "azure.clear"))
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "azure.title"))
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
    AzureCredentialsView(
        store: Store(initialState: AzureCredentialsFeature.State()) {
            AzureCredentialsFeature()
        }
    )
}

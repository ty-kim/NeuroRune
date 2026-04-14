//
//  NCPCredentialsView.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — Naver Cloud Platform API 자격 증명 입력 화면.
//  STT(Clova CSR)·향후 다른 NCP 서비스 공용 키.
//

import SwiftUI
import ComposableArchitecture

struct NCPCredentialsView: View {
    let store: StoreOf<NCPCredentialsFeature>
    var onSaved: () -> Void = {}

    @State private var isKeyRevealed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        TextField(
                            String(localized: "ncp.apiKeyID.placeholder"),
                            text: viewStore.binding(
                                get: \.apiKeyID,
                                send: NCPCredentialsFeature.Action.apiKeyIDChanged
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                    } header: {
                        Text(String(localized: "ncp.apiKeyID"))
                    }

                    Section {
                        HStack(spacing: 8) {
                            Group {
                                if isKeyRevealed {
                                    TextField(
                                        String(localized: "ncp.apiKey.placeholder"),
                                        text: viewStore.binding(
                                            get: \.apiKey,
                                            send: NCPCredentialsFeature.Action.apiKeyChanged
                                        )
                                    )
                                } else {
                                    SecureField(
                                        String(localized: "ncp.apiKey.placeholder"),
                                        text: viewStore.binding(
                                            get: \.apiKey,
                                            send: NCPCredentialsFeature.Action.apiKeyChanged
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
                        Text(String(localized: "ncp.apiKey"))
                    } footer: {
                        Text(String(localized: "ncp.footer"))
                    }

                    if let error = viewStore.error {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if !viewStore.apiKeyID.isEmpty || !viewStore.apiKey.isEmpty {
                        Section {
                            Button(role: .destructive) {
                                viewStore.send(.clearTapped)
                            } label: {
                                Text(String(localized: "ncp.clear"))
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "ncp.title"))
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
    NCPCredentialsView(
        store: Store(initialState: NCPCredentialsFeature.State()) {
            NCPCredentialsFeature()
        }
    )
}

//
//  GitHubCredentialsView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct GitHubCredentialsView: View {
    let store: StoreOf<GitHubCredentialsFeature>
    var onSaved: () -> Void = {}

    @State private var isPATRevealed = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        HStack(spacing: 8) {
                            Group {
                                if isPATRevealed {
                                    TextField("ghp_...", text: viewStore.binding(
                                        get: \.pat,
                                        send: GitHubCredentialsFeature.Action.patChanged
                                    ))
                                } else {
                                    SecureField("ghp_...", text: viewStore.binding(
                                        get: \.pat,
                                        send: GitHubCredentialsFeature.Action.patChanged
                                    ))
                                }
                            }
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                            Button {
                                isPATRevealed.toggle()
                            } label: {
                                Image(systemName: isPATRevealed ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(String(localized: "credentials.pat"))
                    } footer: {
                        Text(String(localized: "credentials.pat.footer"))
                    }

                    Section {
                        TextField(
                            String(localized: "credentials.owner.placeholder"),
                            text: viewStore.binding(
                                get: \.owner,
                                send: GitHubCredentialsFeature.Action.ownerChanged
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        TextField(
                            String(localized: "credentials.repo.placeholder"),
                            text: viewStore.binding(
                                get: \.repo,
                                send: GitHubCredentialsFeature.Action.repoChanged
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        TextField(
                            "main",
                            text: viewStore.binding(
                                get: \.branch,
                                send: GitHubCredentialsFeature.Action.branchChanged
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    } header: {
                        Text(String(localized: "credentials.repo"))
                    }

                    if let error = viewStore.error {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle(String(localized: "credentials.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
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
    GitHubCredentialsView(
        store: Store(initialState: GitHubCredentialsFeature.State()) {
            GitHubCredentialsFeature()
        }
    )
}

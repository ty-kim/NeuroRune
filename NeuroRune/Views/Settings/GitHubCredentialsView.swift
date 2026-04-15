//
//  GitHubCredentialsView.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import ComposableArchitecture

struct GitHubCredentialsView: View {
    let store: StoreOf<GitHubCredentialsFeature>
    var onSaved: () -> Void = {}

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        SecureFieldWithReveal(
                            placeholder: "ghp_...",
                            text: viewStore.binding(
                                get: \.pat,
                                send: GitHubCredentialsFeature.Action.patChanged
                            )
                        )
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

                    Section {
                        TextField(
                            String(localized: "credentials.path.placeholder"),
                            text: viewStore.binding(
                                get: \.path,
                                send: GitHubCredentialsFeature.Action.pathChanged
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    } header: {
                        Text(String(localized: "credentials.path"))
                    } footer: {
                        Text(String(localized: "credentials.path.footer"))
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
                            Text(String(localized: "credentials.clear"))
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

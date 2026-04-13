//
//  MemoryListView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct MemoryListView: View {
    let store: StoreOf<MemoryListFeature>

    @State private var showCredentialsSheet = false
    @State private var showCreateSheet = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Group {
                    if viewStore.isLoading {
                        ProgressView()
                    } else if viewStore.credentialsMissing {
                        credentialsMissingState
                    } else if viewStore.files.isEmpty {
                        emptyState
                    } else {
                        fileList(viewStore)
                    }
                }
                .navigationTitle(String(localized: "memory.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showCredentialsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(String(localized: "credentials.title"))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .disabled(viewStore.credentialsMissing)
                        .accessibilityLabel(String(localized: "memory.create.title"))
                    }
                }
                .refreshable {
                    await viewStore.send(.refresh).finish()
                }
                .task {
                    await viewStore.send(.task).finish()
                }
                .alert(
                    String(localized: "error.prefix"),
                    isPresented: .init(
                        get: { viewStore.listError != nil },
                        set: { if !$0 { viewStore.send(.errorDismissed) } }
                    ),
                    presenting: viewStore.listError
                ) { _ in
                    Button(String(localized: "error.cancel"), role: .cancel) {
                        viewStore.send(.errorDismissed)
                    }
                } message: { message in
                    Text(message)
                }
                .sheet(isPresented: $showCredentialsSheet) {
                    GitHubCredentialsView(
                        store: Store(initialState: GitHubCredentialsFeature.State()) {
                            GitHubCredentialsFeature()
                        },
                        onSaved: {
                            showCredentialsSheet = false
                            viewStore.send(.task)
                        }
                    )
                }
                .sheet(isPresented: $showCreateSheet) {
                    let basePath: String = (try? GitHubCredentialsClient.liveValue.load()).flatMap { $0?.path } ?? ""
                    MemoryCreateView(
                        store: Store(
                            initialState: MemoryCreateFeature.State(basePath: basePath)
                        ) {
                            MemoryCreateFeature()
                        },
                        onCreated: { file in
                            // 낙관적 insert — GitHub eventual consistency 감안해서
                            // 서버 재조회 없이 즉시 목록에 반영.
                            viewStore.send(.fileAdded(file))
                            showCreateSheet = false
                        },
                        onCancel: { showCreateSheet = false }
                    )
                }
            }
        }
    }

    private var credentialsMissingState: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "memory.empty.noCredentials"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(String(localized: "memory.setupGitHub")) {
                showCredentialsSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "memory.empty.noFiles"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func fileList(_ viewStore: ViewStoreOf<MemoryListFeature>) -> some View {
        List {
            ForEach(viewStore.files) { file in
                NavigationLink {
                    MemoryEditView(
                        store: Store(initialState: MemoryEditFeature.State(file: file)) {
                            MemoryEditFeature()
                        }
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.body)
                        if file.path != file.name {
                            Text(file.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewStore.send(.deleteTapped(file))
                    } label: {
                        Label(String(localized: "list.delete"), systemImage: "trash")
                    }
                }
            }
        }
    }
}

#Preview("With files") {
    MemoryListView(
        store: Store(
            initialState: MemoryListFeature.State(
                files: [
                    GitHubFile(path: "memory/user_profile.md", sha: "1", content: "", isDirectory: false),
                    GitHubFile(path: "memory/project_neurorune.md", sha: "2", content: "", isDirectory: false),
                ],
                isLoading: false
            )
        ) {
            MemoryListFeature()
        }
    )
}

#Preview("No credentials") {
    MemoryListView(
        store: Store(
            initialState: MemoryListFeature.State(
                isLoading: false,
                credentialsMissing: true
            )
        ) {
            MemoryListFeature()
        }
    )
}

#Preview("Empty") {
    MemoryListView(
        store: Store(
            initialState: MemoryListFeature.State(
                isLoading: false
            )
        ) {
            MemoryListFeature()
        }
    )
}

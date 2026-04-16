//
//  ConversationListView.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import ComposableArchitecture

struct ConversationListView: View {
    let store: StoreOf<ConversationListFeature>
    var onApiKeyReset: () -> Void = {}

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Group {
                    if viewStore.isLoading {
                        ProgressView()
                    } else if viewStore.conversations.isEmpty {
                        emptyState(viewStore)
                    } else {
                        conversationList(viewStore)
                    }
                }
                .navigationTitle(String(localized: "list.title"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button {
                                viewStore.send(.onboardingTapped)
                            } label: {
                                Label(
                                    String(localized: "settings.anthropicKey"),
                                    systemImage: "key"
                                )
                            }
                            Button {
                                viewStore.send(.memoryListTapped)
                            } label: {
                                Label(
                                    String(localized: "a11y.list.memory"),
                                    systemImage: "book.closed"
                                )
                            }
                            Button {
                                viewStore.send(.elevenLabsCredentialsTapped)
                            } label: {
                                Label(
                                    String(localized: "settings.elevenLabsKey"),
                                    systemImage: "speaker.wave.2"
                                )
                            }
                            Button {
                                viewStore.send(.groqCredentialsTapped)
                            } label: {
                                Label(
                                    String(localized: "settings.groqKey"),
                                    systemImage: "waveform"
                                )
                            }
                            Divider()
                            Button {
                                viewStore.send(.consolidationTapped)
                            } label: {
                                Label(
                                    String(localized: "consolidation.runNow"),
                                    systemImage: "sparkles"
                                )
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                        }
                        .accessibilityLabel(String(localized: "a11y.chat.menuButton"))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewStore.send(.newConversationTapped)
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                        }
                        .accessibilityLabel(String(localized: "a11y.list.newChat"))
                    }
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.showOnboarding,
                        send: ConversationListFeature.Action.onboardingDismissed
                    )
                ) {
                    AnthropicCredentialsView(
                        store: Store(initialState: AnthropicCredentialsFeature.State()) {
                            AnthropicCredentialsFeature()
                        },
                        onComplete: {
                            viewStore.send(.onboardingDismissed)
                        }
                    )
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.showModelPicker,
                        send: ConversationListFeature.Action.modelPickerDismissed
                    )
                ) {
                    modelPickerSheet(viewStore)
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.showMemoryList,
                        send: ConversationListFeature.Action.memoryListDismissed
                    )
                ) {
                    MemoryHubView()
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.showGroqCredentials,
                        send: ConversationListFeature.Action.groqCredentialsDismissed
                    )
                ) {
                    GroqCredentialsView(
                        store: Store(initialState: GroqCredentialsFeature.State()) {
                            GroqCredentialsFeature()
                        },
                        onSaved: {
                            viewStore.send(.groqCredentialsDismissed)
                        }
                    )
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.showElevenLabsCredentials,
                        send: ConversationListFeature.Action.elevenLabsCredentialsDismissed
                    )
                ) {
                    ElevenLabsCredentialsView(
                        store: Store(initialState: ElevenLabsCredentialsFeature.State()) {
                            ElevenLabsCredentialsFeature()
                        },
                        onSaved: {
                            viewStore.send(.elevenLabsCredentialsDismissed)
                        }
                    )
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.showConsolidation,
                        send: ConversationListFeature.Action.consolidationDismissed
                    )
                ) {
                    ConsolidationView(
                        store: Store(initialState: ConsolidationFeature.State()) {
                            ConsolidationFeature()
                        },
                        onDismiss: {
                            viewStore.send(.consolidationDismissed)
                        }
                    )
                }
                .navigationDestination(
                    item: viewStore.binding(
                        get: \.selectedConversation,
                        send: ConversationListFeature.Action.conversationSelected
                    )
                ) { conversation in
                    ChatView(
                        store: Store(
                            initialState: ChatFeature.State(
                                conversation: conversation,
                                inputText: "",
                                isStreaming: false,
                                error: nil
                            )
                        ) {
                            ChatFeature()
                        },
                        onApiKeyReset: onApiKeyReset
                    )
                }
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
        }
    }

    private func emptyState(_ viewStore: ViewStoreOf<ConversationListFeature>) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.primary.opacity(0.6))
            Text(String(localized: "list.empty"))
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.6))
            Button(String(localized: "list.newChat")) {
                viewStore.send(.newConversationTapped)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func conversationList(_ viewStore: ViewStoreOf<ConversationListFeature>) -> some View {
        List {
            ForEach(viewStore.conversations) { conversation in
                Button {
                    viewStore.send(.conversationSelected(conversation))
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        viewStore.send(.deleteTapped(conversation))
                    } label: {
                        Label(String(localized: "list.delete"), systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewStore.send(.deleteTapped(conversation))
                    } label: {
                        Label(String(localized: "list.delete"), systemImage: "trash")
                    }
                }
            }
        }
    }

    private func modelPickerSheet(_ viewStore: ViewStoreOf<ConversationListFeature>) -> some View {
        NavigationStack {
            List {
                Section {
                    Picker(
                        selection: viewStore.binding(
                            get: \.selectedEffort,
                            send: ConversationListFeature.Action.effortSelected
                        )
                    ) {
                        Text(String(localized: "modelPicker.effort.default"))
                            .tag(EffortLevel?.none)
                        ForEach(EffortLevel.allCases) { level in
                            Text(level.displayName).tag(EffortLevel?.some(level))
                        }
                    } label: {
                        Label {
                            Text(String(localized: "modelPicker.effort.label"))
                        } icon: {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .foregroundStyle(.purple)
                        }
                    }
                } footer: {
                    Text(String(localized: "modelPicker.effort.footer"))
                }

                Section {
                    ForEach(LLMModel.allSupported) { model in
                        Button {
                            viewStore.send(.modelSelected(model))
                        } label: {
                            HStack {
                                Text(model.displayName)
                                    .foregroundStyle(Color("BrandTitle"))
                                Spacer()
                                if model.supportsEffort {
                                    Image(systemName: "gauge.with.dots.needle.67percent")
                                        .foregroundStyle(.purple.opacity(0.7))
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(Rectangle())
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                model.supportsEffort
                                    ? "\(model.displayName), \(String(localized: "a11y.modelPicker.effortSupported"))"
                                    : model.displayName
                            )
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "modelPicker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "error.cancel")) {
                        viewStore.send(.modelPickerDismissed)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - ConversationRow

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(conversationTitle)
                .font(.body)
                .foregroundStyle(Color("BrandTitle"))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(LLMModel.resolve(id: conversation.modelId).displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.6))
                if let effort = conversation.effort {
                    Text("·")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.6))
                    Text(effort.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                }
                Spacer()
                Text(lastActivityAt.formatted(.relative(presentation: .named)))
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.6))
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    /// 마지막 메시지 내용(최대 50자). 메시지가 없으면 untitled.
    private var conversationTitle: String {
        if let lastMessage = conversation.messages.last {
            return String(lastMessage.content.prefix(50))
        }
        return String(localized: "list.untitled")
    }

    /// 마지막 메시지 시각. 메시지 없으면 대화 생성 시각.
    private var lastActivityAt: Date {
        conversation.messages.last?.createdAt ?? conversation.createdAt
    }
}

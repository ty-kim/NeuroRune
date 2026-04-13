//
//  ConversationListView.swift
//  NeuroRune
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
                .navigationTitle("NeuroRune")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewStore.send(.resetApiKeyTapped)
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
                        get: \.showModelPicker,
                        send: ConversationListFeature.Action.modelPickerDismissed
                    )
                ) {
                    modelPickerSheet(viewStore)
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
            .confirmationDialog(
                String(localized: "chat.menu.title"),
                isPresented: viewStore.binding(
                    get: \.showResetConfirmation,
                    send: ConversationListFeature.Action.resetConfirmationDismissed
                ),
                titleVisibility: .hidden
            ) {
                Button(String(localized: "chat.resetApiKey"), role: .destructive) {
                    viewStore.send(.resetApiKeyConfirmed)
                    onApiKeyReset()
                }
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
                    Toggle(
                        isOn: viewStore.binding(
                            get: \.thinkingEnabled,
                            send: ConversationListFeature.Action.thinkingToggled
                        )
                    ) {
                        Label {
                            Text(String(localized: "modelPicker.thinking.label"))
                        } icon: {
                            Image(systemName: "brain")
                                .foregroundStyle(.purple)
                        }
                    }
                } footer: {
                    Text(String(localized: "modelPicker.thinking.footer"))
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
                                if model.thinkingBudgetTokens != nil {
                                    Image(systemName: "brain")
                                        .foregroundStyle(.purple.opacity(0.7))
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(Rectangle())
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                model.thinkingBudgetTokens != nil
                                    ? "\(model.displayName), \(String(localized: "a11y.modelPicker.thinkingSupported"))"
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
            HStack {
                Text(LLMModel.resolve(id: conversation.modelId).displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.6))
                Spacer()
                Text(conversation.createdAt.formatted(.relative(presentation: .named)))
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.6))
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var conversationTitle: String {
        if let firstMessage = conversation.messages.first {
            return String(firstMessage.content.prefix(50))
        }
        return String(localized: "list.untitled")
    }
}

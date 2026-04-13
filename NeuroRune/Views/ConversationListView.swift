//
//  ConversationListView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct ConversationListView: View {
    var onApiKeyReset: () -> Void = {}

    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @State private var selectedConversation: Conversation?
    @State private var showModelPicker = false
    @State private var selectedModel: LLMModel = .sonnet46
    @State private var showResetConfirmation = false
    @State private var listError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("NeuroRune")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showResetConfirmation = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                    .accessibilityLabel(String(localized: "a11y.chat.menuButton"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showModelPicker = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel(String(localized: "a11y.list.newChat"))
                }
            }
            .sheet(isPresented: $showModelPicker) {
                modelPickerSheet
            }
            .navigationDestination(item: $selectedConversation) { conversation in
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
        .task(id: selectedConversation) {
            await loadConversations()
        }
        .alert(
            String(localized: "error.prefix"),
            isPresented: .init(
                get: { listError != nil },
                set: { if !$0 { listError = nil } }
            ),
            presenting: listError
        ) { _ in
            Button(String(localized: "error.cancel"), role: .cancel) {
                listError = nil
            }
        } message: { message in
            Text(message)
        }
        .confirmationDialog(
            String(localized: "chat.menu.title"),
            isPresented: $showResetConfirmation,
            titleVisibility: .hidden
        ) {
            Button(String(localized: "chat.resetApiKey"), role: .destructive) {
                let client = KeychainClient.liveValue
                try? client.delete(OnboardingFeature.anthropicKeyName)
                onApiKeyReset()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.primary.opacity(0.6))
            Text(String(localized: "list.empty"))
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.6))
            Button(String(localized: "list.newChat")) {
                showModelPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var conversationList: some View {
        List {
            ForEach(conversations) { conversation in
                Button {
                    selectedConversation = conversation
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deleteConversation(conversation)
                    } label: {
                        Label(String(localized: "list.delete"), systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteConversation(conversation)
                    } label: {
                        Label(String(localized: "list.delete"), systemImage: "trash")
                    }
                }
            }
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        Task {
            let store = ConversationStore.liveValue
            do {
                try await store.delete(conversation.id)
                conversations.removeAll { $0.id == conversation.id }
            } catch {
                listError = String(localized: "list.deleteFailed")
            }
        }
    }

    private var modelPickerSheet: some View {
        NavigationStack {
            List(LLMModel.allSupported) { model in
                Button {
                    showModelPicker = false
                    startNewConversation(model: model)
                } label: {
                    HStack {
                        Text(model.displayName)
                            .foregroundStyle(Color("BrandTitle"))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
            }
            .navigationTitle(String(localized: "modelPicker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "error.cancel")) {
                        showModelPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func loadConversations() async {
        let store = ConversationStore.liveValue
        do {
            let loaded = try await store.loadAll()
            conversations = loaded
        } catch {
            // 기존 목록 유지, 사용자에게 실패 알림
            listError = String(localized: "list.loadFailed")
        }
        if isLoading { isLoading = false }
    }

    private func startNewConversation(model: LLMModel) {
        let conversation = Conversation.empty(modelId: model.id)
        selectedConversation = conversation
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

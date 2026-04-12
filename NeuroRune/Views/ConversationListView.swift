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
        .task {
            await loadConversations()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "list.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            conversations = try await store.loadAll()
        } catch {
            conversations = []
        }
        isLoading = false
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
        VStack(alignment: .leading, spacing: 4) {
            Text(conversationTitle)
                .font(.body)
                .lineLimit(1)
            HStack {
                Text(LLMModel.resolve(id: conversation.modelId).displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(conversation.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var conversationTitle: String {
        if let firstMessage = conversation.messages.first {
            return String(firstMessage.content.prefix(50))
        }
        return String(localized: "list.untitled")
    }
}

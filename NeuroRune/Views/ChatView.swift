//
//  ChatView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct ChatView: View {
    let store: StoreOf<ChatFeature>
    var onApiKeyReset: () -> Void = {}

    @State private var showResetConfirmation = false
    @State private var showUnauthorizedAlert = false
    @State private var errorShakeTrigger = 0

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 0) {
                    messageList(viewStore)
                    if let error = viewStore.error {
                        errorBanner(error)
                            .offset(y: errorShakeTrigger % 2 == 0 ? 0 : -4)
                            .animation(.default.repeatCount(3, autoreverses: true).speed(6), value: errorShakeTrigger)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: viewStore.error)
                    }
                    inputBar(viewStore)
                }
                .navigationTitle(String(localized: "chat.title"))
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: viewStore.error) { _, newError in
                    if let error = newError {
                        errorShakeTrigger += 1
                        if error == .unauthorized {
                            showUnauthorizedAlert = true
                        }
                    }
                }
                .alert(
                    String(localized: "error.unauthorized"),
                    isPresented: $showUnauthorizedAlert
                ) {
                    Button(String(localized: "chat.resetApiKey"), role: .destructive) {
                        let client = KeychainClient.liveValue
                        try? client.delete(OnboardingFeature.anthropicKeyName)
                        onApiKeyReset()
                    }
                    Button(String(localized: "error.cancel"), role: .cancel) {}
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showResetConfirmation = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
            }
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

    private func messageList(_ viewStore: ViewStoreOf<ChatFeature>) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(
                        Array(viewStore.conversation.messages.enumerated()),
                        id: \.offset
                    ) { index, message in
                        MessageView(message: message)
                            .id(index)
                    }

                    if viewStore.isStreaming {
                        HStack {
                            ProgressView()
                                .padding(.leading, 16)
                            Spacer()
                        }
                        .id("streaming")
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewStore.conversation.messages.count) {
                withAnimation {
                    let lastIndex = viewStore.conversation.messages.count - 1
                    if lastIndex >= 0 {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func errorBanner(_ error: LLMError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(String(localized: "error.prefix") + " " + error.userMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func inputBar(_ viewStore: ViewStoreOf<ChatFeature>) -> some View {
        HStack(spacing: 8) {
            TextField(String(localized: "chat.inputPlaceholder"), text: viewStore.binding(
                get: \.inputText,
                send: ChatFeature.Action.inputChanged
            ))
            .textFieldStyle(.roundedBorder)
            .submitLabel(.send)
            .onSubmit {
                viewStore.send(.sendTapped)
            }

            Button {
                viewStore.send(.sendTapped)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(viewStore.inputText.isEmpty || viewStore.isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview("Empty") {
    ChatView(
        store: Store(
            initialState: ChatFeature.State(
                conversation: Conversation.empty(modelId: LLMModel.opus46.id),
                inputText: "",
                isStreaming: false,
                error: nil
            )
        ) {
            ChatFeature()
        }
    )
}

#Preview("With Messages") {
    let messages: [Message] = [
        Message(role: .user, content: "Swift에서 actor는 뭐야?", createdAt: .now),
        Message(role: .assistant, content: """
        **Actor**는 Swift의 동시성 모델에서 데이터 격리를 제공합니다.

        - 내부 상태에 대한 직렬화된 접근 보장
        - `await`로 외부에서 접근

        ```swift
        actor Counter {
            var count = 0
            func increment() { count += 1 }
        }
        ```
        """, createdAt: .now),
    ]
    var conversation = Conversation.empty(modelId: LLMModel.opus46.id)
    for msg in messages {
        conversation = conversation.appending(msg)
    }

    return ChatView(
        store: Store(
            initialState: ChatFeature.State(
                conversation: conversation,
                inputText: "",
                isStreaming: false,
                error: nil
            )
        ) {
            ChatFeature()
        }
    )
}

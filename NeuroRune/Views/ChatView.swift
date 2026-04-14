//
//  ChatView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

private struct ToolCallChips: View {
    let calls: [ChatFeature.ToolCallStatus]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(calls) { call in
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(label(for: call))
                            .font(.footnote)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(label(for: call))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func label(for call: ChatFeature.ToolCallStatus) -> String {
        switch call.name {
        case "read_memory":
            let path = call.input["path"] ?? "?"
            let role = call.input["role"] ?? "?"
            return "📖 \(role)/\(path)"
        default:
            return "⚙️ \(call.name)"
        }
    }
}

struct ChatView: View {
    let store: StoreOf<ChatFeature>
    var onApiKeyReset: () -> Void = {}

    @State private var showUnauthorizedAlert = false
    @State private var errorShakeTrigger = 0
    @FocusState private var isInputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 0) {
                    ChatMessageList(
                        messages: viewStore.conversation.messages,
                        onTap: { isInputFocused = false }
                    )
                    if let rateLimit = viewStore.rateLimit {
                        RateLimitBadge(state: rateLimit)
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewStore.rateLimit)
                    }
                    if let error = viewStore.error {
                        ErrorBubbleView(
                            error: error,
                            onRetry: { viewStore.send(.retryTapped) },
                            onDismiss: { viewStore.send(.errorDismissed) }
                        )
                        .offset(y: reduceMotion ? 0 : (errorShakeTrigger % 2 == 0 ? 0 : -4))
                        .animation(reduceMotion ? nil : .default.repeatCount(3, autoreverses: true).speed(6), value: errorShakeTrigger)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewStore.error)
                    }
                    if !viewStore.activeToolCalls.isEmpty {
                        ToolCallChips(calls: viewStore.activeToolCalls)
                            .transition(.opacity)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewStore.activeToolCalls)
                    }
                    if let persistenceError = viewStore.persistenceError {
                        ChatPersistenceBanner(
                            message: persistenceError,
                            onDismiss: { viewStore.send(.persistenceErrorDismissed) }
                        )
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewStore.persistenceError)
                    }
                    ChatInputBar(
                        text: viewStore.binding(
                            get: \.inputText,
                            send: ChatFeature.Action.inputChanged
                        ),
                        isStreaming: viewStore.isStreaming,
                        onSend: { viewStore.send(.sendTapped) },
                        focus: $isInputFocused
                    )
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        let modelName = LLMModel.resolve(id: viewStore.conversation.modelId).displayName
                        HStack(spacing: 4) {
                            Text(modelName)
                                .font(.headline)
                            if let effort = viewStore.conversation.effort {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(effort.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.purple)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            viewStore.conversation.effort.map {
                                "\(modelName), \(String(localized: "a11y.chat.effort")) \($0.displayName)"
                            } ?? modelName
                        )
                    }
                }
                .onChange(of: viewStore.error) { _, newError in
                    if let error = newError {
                        errorShakeTrigger += 1
                        if error == .unauthorized {
                            showUnauthorizedAlert = true
                        }
                    }
                }
                .onChange(of: viewStore.isStreaming) { wasStreaming, isStreaming in
                    // streaming 끝났고 error 없으면 응답 수신 완료 → success haptic.
                    if wasStreaming && !isStreaming && viewStore.error == nil {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: { viewStore.pendingWrite != nil },
                        set: { isShown in
                            if !isShown, let id = viewStore.pendingWrite?.id {
                                viewStore.send(.writeRejected(id: id, reason: "dismissed"))
                            }
                        }
                    )
                ) {
                    if let req = viewStore.pendingWrite {
                        WriteApprovalModal(
                            request: req,
                            onApprove: { viewStore.send(.writeApproved(id: req.id)) },
                            onReject: { viewStore.send(.writeRejected(id: req.id, reason: nil)) }
                        )
                        .interactiveDismissDisabled(true)
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
            }
        }
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

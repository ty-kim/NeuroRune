//
//  ChatView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct ChatView: View {
    let store: StoreOf<ChatFeature>
    var onApiKeyReset: () -> Void = {}

    @State private var showUnauthorizedAlert = false
    @State private var errorShakeTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 0) {
                    ChatMessageList(
                        messages: viewStore.conversation.messages,
                        isStreaming: viewStore.isStreaming
                    )
                    if let error = viewStore.error {
                        ChatErrorBanner(error: error)
                            .offset(y: reduceMotion ? 0 : (errorShakeTrigger % 2 == 0 ? 0 : -4))
                            .animation(reduceMotion ? nil : .default.repeatCount(3, autoreverses: true).speed(6), value: errorShakeTrigger)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewStore.error)
                    }
                    ChatInputBar(
                        text: viewStore.binding(
                            get: \.inputText,
                            send: ChatFeature.Action.inputChanged
                        ),
                        isStreaming: viewStore.isStreaming,
                        onSend: { viewStore.send(.sendTapped) }
                    )
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

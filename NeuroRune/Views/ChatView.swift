//
//  ChatView.swift
//  NeuroRune
//

import SwiftUI
import ComposableArchitecture

struct ChatView: View {
    let store: StoreOf<ChatFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                VStack(spacing: 0) {
                    messageList(viewStore)
                    inputBar(viewStore)
                }
                .navigationTitle(String(localized: "chat.title"))
                .navigationBarTitleDisplayMode(.inline)
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

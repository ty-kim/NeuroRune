//
//  ChatMessageList.swift
//  NeuroRune
//

import SwiftUI

struct ChatMessageList: View {
    let messages: [Message]
    /// 현재 스트리밍 중 여부. true이면 **마지막 assistant 메시지**에 인디케이터 표시.
    var isStreaming: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(
                        Array(messages.enumerated()),
                        id: \.offset
                    ) { index, message in
                        MessageView(
                            message: message,
                            isStreaming: shouldShowIndicator(at: index, message: message)
                        )
                        .id(index)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded { onTap() }
            )
            .onChange(of: messages.count) {
                withAnimation {
                    let lastIndex = messages.count - 1
                    if lastIndex >= 0 {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.last?.content) {
                let lastIndex = messages.count - 1
                if lastIndex >= 0 {
                    proxy.scrollTo(lastIndex, anchor: .bottom)
                }
            }
            .onAppear {
                // 기존 대화 재진입 시 최하단(최신 메시지)으로 자동 스크롤.
                let lastIndex = messages.count - 1
                if lastIndex >= 0 {
                    proxy.scrollTo(lastIndex, anchor: .bottom)
                }
            }
        }
    }

    /// 현재 인덱스의 메시지가 스트리밍 인디케이터를 표시해야 하는지.
    /// 마지막 assistant 메시지 + `isStreaming == true`일 때만 true.
    private func shouldShowIndicator(at index: Int, message: Message) -> Bool {
        guard isStreaming else { return false }
        guard index == messages.count - 1 else { return false }
        return message.role == .assistant
    }
}

#Preview("Empty") {
    ChatMessageList(messages: [])
}

#Preview("With messages") {
    ChatMessageList(
        messages: [
            Message(role: .user, content: "Swift에서 actor는 뭐야?", createdAt: .now),
            Message(role: .assistant, content: "**Actor**는 Swift 동시성 모델에서 데이터 격리를 제공합니다.", createdAt: .now),
            Message(role: .user, content: "예시 좀", createdAt: .now),
            Message(role: .assistant, content: "```swift\nactor Counter { var count = 0 }\n```", createdAt: .now),
        ]
    )
}

#Preview("Streaming — with content (cursor)") {
    ChatMessageList(
        messages: [
            Message(role: .user, content: "긴 답변 부탁", createdAt: .now),
            Message(role: .assistant, content: "Answer in progre", createdAt: .now),
        ],
        isStreaming: true
    )
}

#Preview("Streaming — empty (typing dots)") {
    ChatMessageList(
        messages: [
            Message(role: .user, content: "안녕", createdAt: .now),
            Message(role: .assistant, content: "", createdAt: .now),
        ],
        isStreaming: true
    )
}

#Preview("Dark Mode") {
    ChatMessageList(
        messages: [
            Message(role: .user, content: "다크모드 테스트", createdAt: .now),
            Message(role: .assistant, content: "**Bold** + `code`", createdAt: .now),
        ]
    )
    .preferredColorScheme(.dark)
}

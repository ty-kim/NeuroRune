//
//  ChatMessageList.swift
//  NeuroRune
//

import SwiftUI

struct ChatMessageList: View {
    let messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(
                        Array(messages.enumerated()),
                        id: \.offset
                    ) { index, message in
                        MessageView(message: message)
                            .id(index)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
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
        }
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

#Preview("Streaming placeholder") {
    ChatMessageList(
        messages: [
            Message(role: .user, content: "긴 답변 부탁", createdAt: .now),
            Message(role: .assistant, content: "Answer in progre", createdAt: .now),
        ]
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

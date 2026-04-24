//
//  ChatMessageList.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI

struct ChatMessageList: View {
    let messages: [Message]
    /// 현재 스트리밍 중 여부. true이면 **마지막 assistant 메시지**에 인디케이터 표시.
    var isStreaming: Bool = false
    var onTap: () -> Void = {}
    /// Phase 22 — 현재 TTS 재생 중인 메시지 id. assistant 버블에 재생/중지 버튼 노출.
    var speakingMessageID: UUID?
    var onSpeakTapped: ((UUID) -> Void)?
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
                            isStreaming: shouldShowIndicator(at: index, message: message),
                            isSpeaking: speakingMessageID == message.id,
                            onSpeakTapped: onSpeakTapped.map { handler in
                                { handler(message.id) }
                            }
                        )
                        .id(index)
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded { onTap() }
            )
            // user 전송만 강제 bottom (iMessage 패턴).
            // assistant 스트리밍·도착은 defaultScrollAnchor의 near-bottom 판정에 위임.
            // sendTapped는 user + assistant placeholder 동시 append → delta == 2.
            // 단독 user append(retry 등)는 delta == 1 + lastRole == user.
            // 200ms 대기 = LazyVStack이 새 cell measure 완료까지 (markdown-ui 렌더 포함).
            // 즉시 scrollTo는 placeholder estimate 기반이라 오버슈트로 공백 flash.
            .onChange(of: messages.count) { oldCount, newCount in
                let delta = newCount - oldCount
                let isUserSend = delta >= 2 || (delta == 1 && messages.last?.role == .user)
                guard isUserSend else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                }
            }
        }
    }

    /// 마지막 assistant 메시지 + `isStreaming == true`일 때만 인디케이터 표시.
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

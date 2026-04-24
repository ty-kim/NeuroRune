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
    /// user 전송 후 content 확장 완료 시점에 scroll할 target index.
    /// onGeometryChange로 LazyVStack 실제 height 변화를 감지해서 layout 완료 후 처리.
    @State private var pendingScrollTarget: Int?

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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: LazyVStackHeightKey.self,
                                value: geo.size.height
                            )
                    }
                )
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded { onTap() }
            )
            // LazyVStack 실제 height 변화 후 pending scroll 처리.
            // 키보드 떠 있어도 measure 완료 보장 → Task.yield 추측 제거.
            // onPreferenceChange는 @Sendable·non-MainActor closure라 Task hop 필요.
            .onPreferenceChange(LazyVStackHeightKey.self) { _ in
                Task { @MainActor in
                    guard let target = pendingScrollTarget else { return }
                    proxy.scrollTo(target, anchor: .bottom)
                    pendingScrollTarget = nil
                }
            }
            // user 전송만 강제 bottom (iMessage 패턴).
            // assistant 스트리밍·도착은 defaultScrollAnchor의 near-bottom 판정에 위임.
            .onChange(of: messages.count) {
                guard messages.last?.role == .user else { return }
                pendingScrollTarget = messages.count - 1
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

private struct LazyVStackHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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

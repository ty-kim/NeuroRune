//
//  ChatMessageList.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import UIKit // UIResponder.keyboardDidShowNotification

struct ChatMessageList: View {
    let messages: [Message]
    /// 현재 스트리밍 중 여부. true이면 **마지막 assistant 메시지**에 인디케이터 표시.
    var isStreaming: Bool = false
    /// 입력창이 포커스된 상태. true로 전환될 때 마지막 메시지로 자동 스크롤해
    /// 키보드에 가려지지 않도록 한다.
    var isInputFocused: Bool = false
    var onTap: () -> Void = {}
    /// Phase 22 — 현재 TTS 재생 중인 메시지 id. assistant 버블에 재생/중지 버튼 노출.
    var speakingMessageID: UUID?
    var onSpeakTapped: ((UUID) -> Void)?
    @State private var autoFollowBottom = true
    private let bottomSentinelID = "chat.bottomSentinel"

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
                    Color.clear
                        .frame(height: 1)
                        .id(bottomSentinelID)
                        .onAppear { autoFollowBottom = true }
                }
                .padding()
            }
            // 바닥을 기준으로 레이아웃 → 키보드로 뷰포트 축소 시에도 마지막 메시지가 자동 유지.
            // onChange scrollTo가 "이미 바닥"이라 무시되는 문제 해결.
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded { onTap() }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // 아래로 드래그 = 위 content 보려는 의도 = auto-follow 해제
                        if value.translation.height > 0 {
                            autoFollowBottom = false
                        }
                    }
            )
            .onChange(of: messages.count) {
                // animation 없이 즉시 점프. withAnimation은 content height 확정 전에
                // target offset이 content 범위를 순간 넘어가 배경(DarkNavy) 노출.
                // 새 메시지 = 사용자 의도, 무조건 bottom
                autoFollowBottom = true
                let lastIndex = messages.count - 1
                guard lastIndex >= 0 else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo(bottomSentinelID, anchor: .bottom)
                }
            }
            .onChange(of: messages.last?.content) {
                // 스트리밍 중 토큰 유입마다 바닥 유지. animation 없이, count 트리거와 같은
                // 타이밍으로 맞춰야 jitter 없음.
                guard isStreaming, autoFollowBottom else { return }
                let lastIndex = messages.count - 1
                guard lastIndex >= 0 else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo(bottomSentinelID, anchor: .bottom)
                }
            }
            .onAppear {
                // 기존 대화 재진입 시 최하단(최신 메시지)으로 자동 스크롤.
                // LazyVStack이 첫 프레임에 아직 content 높이를 확정 못 해서
                // 즉시 scrollTo는 no-op이 된다. 짧은 지연 후 시도.
                let lastIndex = messages.count - 1
                guard lastIndex >= 0 else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo(bottomSentinelID, anchor: .bottom)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                // 키보드 완전히 올라온 시점 = safe area 안정화 완료. 이때 bottom 고정하면
                // 공백/덜감 없음. 350ms sleep 같은 매직넘버 제거.
                guard isInputFocused else { return }
                let lastIndex = messages.count - 1
                guard lastIndex >= 0 else { return }
                proxy.scrollTo(bottomSentinelID, anchor: .bottom)
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

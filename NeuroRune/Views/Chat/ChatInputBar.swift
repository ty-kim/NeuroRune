//
//  ChatInputBar.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    /// 스트리밍 중 [Stop] 버튼 탭 — Phase 20에서 도입. nil 넘기면 Stop 비활성.
    var onStop: (() -> Void)?
    /// Phase 21 — 마이크 버튼 상태·토글 핸들러. nil이면 마이크 버튼 숨김.
    var isRecording: Bool = false
    var onMicTapped: (() -> Void)?
    /// Phase 21 — STT 전사 후 자동 전송 카운트다운(2 → 1 → send).
    /// nil이 아니면 Send 버튼 자리에 숫자 표시 + 탭 시 취소.
    var autoSendCountdown: Int?
    /// 카운트다운 취소 핸들러(Send 자리 탭 or TextField 포커스).
    var onCancelCountdown: (() -> Void)?
    var focus: FocusState<Bool>.Binding

    // MARK: - Layout constants

    /// Min tap target per HIG 44pt. 아이콘은 작고 버튼 hit area로 채움.
    private static let buttonSize: CGFloat = 40
    private static let iconFont: Font = .title
    /// 카운트다운 숫자 배지 원형 크기.
    private static let countdownSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 10) {
            TextField(String(localized: "chat.inputPlaceholder"), text: $text)
                .submitLabel(.send)
                .onSubmit {
                    guard !isStreaming else { return }
                    onSend()
                }
                .focused(focus)
                .onChange(of: focus.wrappedValue) { _, focused in
                    // 입력창 탭(포커스 진입) = 카운트다운 취소.
                    if focused, autoSendCountdown != nil {
                        onCancelCountdown?()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                )

            if let onMicTapped, !isStreaming {
                Button(action: {
                    UIImpactFeedbackGenerator(style: isRecording ? .medium : .light).impactOccurred()
                    onMicTapped()
                }) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(Self.iconFont)
                        .foregroundStyle(isRecording ? .red : .secondary)
                        .symbolEffect(.pulse, options: isRecording ? .repeating : .nonRepeating,
                                      value: isRecording)
                        .frame(width: Self.buttonSize, height: Self.buttonSize)
                }
                .accessibilityLabel(String(localized: isRecording
                    ? "a11y.chat.stopRecording"
                    : "a11y.chat.startRecording"))
            }

            if isStreaming, let onStop {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStop()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(Self.iconFont)
                        .foregroundStyle(.red)
                        .frame(width: Self.buttonSize, height: Self.buttonSize)
                }
                .accessibilityLabel(String(localized: "a11y.chat.stopButton"))
            } else if let countdown = autoSendCountdown {
                // 카운트다운 중: 숫자 표시, 탭 시 즉시 전송 (reducer가 타이머 취소).
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSend()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: Self.countdownSize, height: Self.countdownSize)
                        Text("\(countdown)")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
                }
                .accessibilityLabel(String(localized: "a11y.chat.autoSendCountdown"))
                .accessibilityValue("\(countdown)")
            } else {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSend()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(Self.iconFont)
                        .frame(width: Self.buttonSize, height: Self.buttonSize)
                }
                .disabled(text.isEmpty || isStreaming || isRecording)
                .accessibilityLabel(String(localized: "a11y.chat.sendButton"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

#Preview("Empty") {
    InputBarPreview(initialText: "", isStreaming: false)
}

#Preview("With text") {
    InputBarPreview(initialText: "Hello Claude", isStreaming: false)
}

#Preview("Streaming (disabled)") {
    InputBarPreview(initialText: "Waiting for reply…", isStreaming: true)
}

#Preview("Dark Mode") {
    InputBarPreview(initialText: "다크모드", isStreaming: false)
        .preferredColorScheme(.dark)
}

private struct InputBarPreview: View {
    @State var text: String
    let isStreaming: Bool
    @FocusState private var focus: Bool

    init(initialText: String, isStreaming: Bool) {
        _text = State(initialValue: initialText)
        self.isStreaming = isStreaming
    }

    var body: some View {
        ChatInputBar(text: $text, isStreaming: isStreaming, onSend: {}, focus: $focus)
    }
}

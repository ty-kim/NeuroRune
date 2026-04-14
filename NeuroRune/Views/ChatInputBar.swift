//
//  ChatInputBar.swift
//  NeuroRune
//

import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    /// 스트리밍 중 [Stop] 버튼 탭 — Phase 20에서 도입. nil 넘기면 Stop 비활성.
    var onStop: (() -> Void)? = nil
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "chat.inputPlaceholder"), text: $text)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    guard !isStreaming else { return }
                    onSend()
                }
                .focused(focus)

            if isStreaming, let onStop {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStop()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .accessibilityLabel(String(localized: "a11y.chat.stopButton"))
            } else {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSend()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(text.isEmpty || isStreaming)
                .accessibilityLabel(String(localized: "a11y.chat.sendButton"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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


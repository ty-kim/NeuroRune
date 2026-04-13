//
//  ChatInputBar.swift
//  NeuroRune
//

import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "chat.inputPlaceholder"), text: $text)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(text.isEmpty || isStreaming)
            .accessibilityLabel(String(localized: "a11y.chat.sendButton"))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview("Empty") {
    StatefulPreviewWrapper("") { text in
        ChatInputBar(text: text, isStreaming: false, onSend: {})
    }
}

#Preview("With text") {
    StatefulPreviewWrapper("Hello Claude") { text in
        ChatInputBar(text: text, isStreaming: false, onSend: {})
    }
}

#Preview("Streaming (disabled)") {
    StatefulPreviewWrapper("Waiting for reply…") { text in
        ChatInputBar(text: text, isStreaming: true, onSend: {})
    }
}

#Preview("Dark Mode") {
    StatefulPreviewWrapper("다크모드") { text in
        ChatInputBar(text: text, isStreaming: false, onSend: {})
    }
    .preferredColorScheme(.dark)
}

private struct StatefulPreviewWrapper<Content: View>: View {
    @State private var value: String
    let content: (Binding<String>) -> Content

    init(_ initial: String, @ViewBuilder content: @escaping (Binding<String>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}


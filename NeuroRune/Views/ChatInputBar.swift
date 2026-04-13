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

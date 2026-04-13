//
//  ChatMessageList.swift
//  NeuroRune
//

import SwiftUI

struct ChatMessageList: View {
    let messages: [Message]
    let isStreaming: Bool

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

                    if isStreaming {
                        HStack {
                            ProgressView()
                                .padding(.leading, 16)
                            Spacer()
                        }
                        .id("streaming")
                        .accessibilityLabel(String(localized: "a11y.chat.streaming"))
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
        }
    }
}

//
//  MessageView.swift
//  NeuroRune
//

import SwiftUI
import MarkdownUI

struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 48)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRolePrefix + message.content)
    }

    private var accessibilityRolePrefix: String {
        message.role == .user
            ? String(localized: "a11y.message.user") + ", "
            : String(localized: "a11y.message.assistant") + ", "
    }

    private var userBubble: some View {
        Text(message.content)
            .padding(12)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var assistantBubble: some View {
        Markdown(message.content)
            .markdownTheme(.neuroRune)
            .markdownImageProvider(DisabledImageProvider())
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// LLM 응답의 이미지 URL 자동 fetch 차단 (IP/환경 정보 누출 방지).
private struct DisabledImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        Text("🖼️ [image]")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - MarkdownUI Theme

extension MarkdownUI.Theme {
    static let neuroRune = Theme()
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: true) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(12)
            }
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 4)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
        }
}

// MARK: - Preview

#Preview("User Message") {
    MessageView(
        message: Message(role: .user, content: "Swift에서 actor는 뭐야?", createdAt: .now)
    )
    .padding()
}

#Preview("Assistant Markdown") {
    ScrollView {
        MessageView(
            message: Message(
                role: .assistant,
                content: """
                **Actor**는 Swift의 동시성 모델에서 **데이터 격리**를 제공합니다.

                주요 특징:
                - 내부 상태에 대한 **직렬화된 접근** 보장
                - `await` 키워드로 외부에서 접근
                - `nonisolated`로 격리 해제 가능

                간단한 예시:

                ```swift
                actor Counter {
                    var count = 0

                    func increment() {
                        count += 1
                    }
                }

                let counter = Counter()
                await counter.increment()
                ```

                `MainActor`는 메인 스레드에서 실행되는 특수한 글로벌 actor입니다.
                """,
                createdAt: .now
            )
        )
        .padding()
    }
}

#Preview("Dark Mode") {
    VStack(spacing: 12) {
        MessageView(
            message: Message(role: .user, content: "다크모드 테스트", createdAt: .now)
        )
        MessageView(
            message: Message(
                role: .assistant,
                content: "**다크모드**에서도 `인라인 코드`와 코드 블록이 잘 보여야 합니다.\n\n```\nlet x = 42\n```",
                createdAt: .now
            )
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXL") {
    VStack(spacing: 12) {
        MessageView(
            message: Message(role: .user, content: "큰 글씨에서도 잘 보이나?", createdAt: .now)
        )
        MessageView(
            message: Message(
                role: .assistant,
                content: "**Dynamic Type**이 적용되면 `인라인 코드`도 함께 커집니다.\n\n```\nlet size = \"xxxLarge\"\n```",
                createdAt: .now
            )
        )
    }
    .padding()
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Long Code Block") {
    MessageView(
        message: Message(
            role: .assistant,
            content: """
            긴 코드 블록은 가로 스크롤됩니다:

            ```swift
            func veryLongFunctionName(parameterOne: String, parameterTwo: Int, parameterThree: Bool, parameterFour: Double) -> some View {
                Text("이 줄은 의도적으로 매우 길게 작성되었습니다. 가로 스크롤이 동작하는지 확인하세요.")
            }
            ```
            """,
            createdAt: .now
        )
    )
    .padding()
}

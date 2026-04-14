//
//  ErrorBubbleView.swift
//  NeuroRune
//
//  Created by tykim
//
//  실패한 메시지 아래 표시되는 에러 버블. 재시도·닫기 버튼 제공.
//  `LLMError.isRetryable == false`(예: `.cancelled`)이면 재시도 버튼 숨김.
//

import SwiftUI

struct ErrorBubbleView: View {
    let error: LLMError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 이 View가 처음 화면에 뜬 순간. retryAfter 카운트다운의 기준점.
    /// `@State`는 재렌더 시 유지되지만 .id(...) 변경 시 재초기화 가능.
    @State private var retryStartedAt: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error.userMessage)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            if case let .rateLimited(retryAfter?, _) = error, retryAfter > 0 {
                RetryCountdownLabel(startedAt: retryStartedAt, duration: retryAfter)
            }

            HStack(spacing: 12) {
                Spacer()
                if error.isRetryable {
                    Button {
                        onRetry()
                    } label: {
                        Label(String(localized: "error.retry"), systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel(String(localized: "error.retry"))
                }
                Button {
                    onDismiss()
                } label: {
                    Text(String(localized: "error.dismiss"))
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(String(localized: "error.dismiss"))
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 4)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }

    static func formatCountdown(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let s = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, s)
        }
        return "\(s)s"
    }
}

// MARK: - RetryCountdownLabel

/// retryAfter 초를 실시간 카운트다운으로 표시. 0초 이하가 되면 자동으로 사라진다.
/// `startedAt` 기준으로 남은 시간 계산 → ErrorBubbleView의 `@State retryStartedAt` 유지.
struct RetryCountdownLabel: View {
    let startedAt: Date
    let duration: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = max(0, Int((duration - context.date.timeIntervalSince(startedAt)).rounded()))
            if remaining > 0 {
                Text(String(format: String(localized: "error.retry.countdown.format"),
                            ErrorBubbleView.formatCountdown(remaining)))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Network error") {
    ErrorBubbleView(
        error: .network("The Internet connection appears to be offline."),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Rate Limited + retryAfter 25s") {
    ErrorBubbleView(
        error: .rateLimited(retryAfter: 25, state: nil),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Rate Limited no retryAfter") {
    ErrorBubbleView(
        error: .rateLimited(retryAfter: nil, state: nil),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Cancelled — 재시도 버튼 없음") {
    ErrorBubbleView(
        error: .cancelled,
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Server 500") {
    ErrorBubbleView(
        error: .server(status: 500, message: "Internal server error"),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Dark Mode") {
    ErrorBubbleView(
        error: .rateLimited(retryAfter: 30, state: nil),
        onRetry: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXL") {
    ErrorBubbleView(
        error: .network("Very long error message for wrapping verification under large dynamic type"),
        onRetry: {},
        onDismiss: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

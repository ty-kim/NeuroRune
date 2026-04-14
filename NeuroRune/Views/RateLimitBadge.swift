//
//  RateLimitBadge.swift
//  NeuroRune
//
//  Created by tykim
//
//  Anthropic rate limit 쿼터가 낮을 때 ChatView 상단에 표시되는 배지.
//  - 가장 여유 없는 Quota 기준으로 표시.
//  - remaining >= 20% → 숨김 (body가 EmptyView).
//  - 5% <= remaining < 20% → 노란 경고 배지 (사용률 %).
//  - remaining < 5% → 빨간 배지 + 재설정까지 카운트다운.
//

import SwiftUI

struct RateLimitBadge: View {
    let state: RateLimitState

    var body: some View {
        if let display = Self.display(for: state) {
            HStack(spacing: 8) {
                Image(systemName: display.level == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(display.level.tint)
                Text(display.primaryText)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Spacer()
                if display.level == .critical {
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        Text(Self.countdownText(to: display.quota.resetsAt, at: context.date))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(display.level.background)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(display.level.tint.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.accessibilityLabel)
        }
    }

    // MARK: - Decision

    enum Level {
        case warning
        case critical

        var tint: Color {
            switch self {
            case .warning:  return .yellow
            case .critical: return .red
            }
        }

        var background: Color {
            switch self {
            case .warning:  return Color.yellow.opacity(0.12)
            case .critical: return Color.red.opacity(0.12)
            }
        }
    }

    struct Display: Equatable {
        let level: Level
        let kind: Kind
        let quota: RateLimitState.Quota

        var primaryText: String {
            let used = Int(round((1.0 - quota.percentRemaining) * 100.0))
            switch level {
            case .warning:
                return String(format: String(localized: "rate_limit.warning.format"), kind.displayName, used)
            case .critical:
                return String(format: String(localized: "rate_limit.critical.format"), kind.displayName)
            }
        }

        var accessibilityLabel: String {
            let used = Int(round((1.0 - quota.percentRemaining) * 100.0))
            switch level {
            case .warning:
                return String(format: String(localized: "rate_limit.warning.a11y"), kind.displayName, used)
            case .critical:
                return String(format: String(localized: "rate_limit.critical.a11y"), kind.displayName)
            }
        }
    }

    enum Kind: String, Equatable {
        case outputTokens
        case tokens
        case inputTokens
        case requests

        var displayName: String {
            switch self {
            case .outputTokens: return String(localized: "rate_limit.kind.output_tokens")
            case .tokens:       return String(localized: "rate_limit.kind.tokens")
            case .inputTokens:  return String(localized: "rate_limit.kind.input_tokens")
            case .requests:     return String(localized: "rate_limit.kind.requests")
            }
        }
    }

    /// 가장 여유 없는 Quota 기준으로 Display를 생성한다.
    /// 동률 시 우선순위: outputTokens > tokens > inputTokens > requests (Opus 4.6 Max는 output이 가장 먼저 고갈).
    static func display(for state: RateLimitState) -> Display? {
        let candidates: [(Kind, RateLimitState.Quota?)] = [
            (.outputTokens, state.outputTokens),
            (.tokens,       state.tokens),
            (.inputTokens,  state.inputTokens),
            (.requests,     state.requests)
        ]

        let present: [(Kind, RateLimitState.Quota)] = candidates.compactMap { kind, quota in
            guard let quota else { return nil }
            return (kind, quota)
        }

        guard let most = present.min(by: { $0.1.percentRemaining < $1.1.percentRemaining }) else {
            return nil
        }

        let level: Level
        switch most.1.percentRemaining {
        case ..<0.05:          level = .critical
        case 0.05..<0.20:      level = .warning
        default:               return nil  // >= 20%이면 표시 안 함
        }

        return Display(level: level, kind: most.0, quota: most.1)
    }

    /// 현재 시각 기준 resetsAt까지 남은 시간을 "mm:ss" 또는 "HH:mm:ss"로 표현.
    static func countdownText(to resetsAt: Date, at now: Date) -> String {
        let remaining = max(0, Int(resetsAt.timeIntervalSince(now).rounded()))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Previews

#Preview("Warning — 15% remaining") {
    VStack {
        RateLimitBadge(state: RateLimitState(
            outputTokens: .init(limit: 8000, remaining: 1200, resetsAt: .now.addingTimeInterval(120))
        ))
        Spacer()
    }
}

#Preview("Critical — 2% remaining") {
    VStack {
        RateLimitBadge(state: RateLimitState(
            outputTokens: .init(limit: 8000, remaining: 100, resetsAt: .now.addingTimeInterval(45))
        ))
        Spacer()
    }
}

#Preview("Hidden — 50% remaining") {
    VStack {
        RateLimitBadge(state: RateLimitState(
            tokens: .init(limit: 80000, remaining: 40000, resetsAt: .now.addingTimeInterval(3600))
        ))
        Text("(배지 숨김 상태)")
            .foregroundStyle(.secondary)
        Spacer()
    }
}

#Preview("Dark Mode") {
    VStack(spacing: 0) {
        RateLimitBadge(state: RateLimitState(
            outputTokens: .init(limit: 8000, remaining: 1200, resetsAt: .now.addingTimeInterval(120))
        ))
        RateLimitBadge(state: RateLimitState(
            outputTokens: .init(limit: 8000, remaining: 100, resetsAt: .now.addingTimeInterval(45))
        ))
        Spacer()
    }
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXL") {
    RateLimitBadge(state: RateLimitState(
        tokens: .init(limit: 80000, remaining: 4000, resetsAt: .now.addingTimeInterval(75))
    ))
    .dynamicTypeSize(.xxxLarge)
}

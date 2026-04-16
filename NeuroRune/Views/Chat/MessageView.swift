//
//  MessageView.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import MarkdownUI

struct MessageView: View {
    let message: Message
    /// 이 메시지가 **현재 스트리밍 중인 마지막 assistant 메시지**일 때 true.
    /// ChatMessageList가 마지막 assistant에만 전달한다.
    var isStreaming: Bool = false
    /// Phase 22 — 이 메시지가 현재 TTS 재생 중일 때 true.
    var isSpeaking: Bool = false
    /// 스피커 버튼 탭 핸들러. nil이면 버튼 숨김.
    var onSpeakTapped: (() -> Void)?

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
            .textSelection(.enabled)
            .padding(12)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !message.content.isEmpty {
                Markdown(message.content)
                    .markdownTheme(.neuroRune)
                    .markdownImageProvider(DisabledImageProvider())
                    .textSelection(.enabled)
                    // 리스트 항목 등이 말줄임(…)으로 잘리지 않도록 intrinsic 높이 확보.
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isStreaming {
                StreamingIndicator(hasContent: !message.content.isEmpty)
            }
            if let onSpeakTapped, !isStreaming, !message.content.isEmpty {
                HStack {
                    Spacer()
                    Button(action: onSpeakTapped) {
                        Image(systemName: isSpeaking ? "pause.fill" : "speaker.wave.2.fill")
                            .font(.footnote)
                            .foregroundStyle(isSpeaking ? .red : .secondary)
                    }
                    .accessibilityLabel(String(localized: isSpeaking
                        ? "a11y.message.stopAudio"
                        : "a11y.message.playAudio"))
                }
            }
        }
        .padding(12)
        .background(bubbleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bubbleBackground: Color {
        isSpeaking
            ? Color.accentColor.opacity(0.15)
            : Color(.secondarySystemBackground)
    }
}

// MARK: - StreamingIndicator

/// 스트리밍 중인 assistant 버블의 인디케이터.
/// - `hasContent == false`: 3-dot 타이핑 (빈 버블)
/// - `hasContent == true`: 작은 펄싱 커서 (텍스트 뒤에 이어지는 느낌)
/// ReduceMotion이 켜져 있으면 정적으로 표시.
private struct StreamingIndicator: View {
    let hasContent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0

    var body: some View {
        Group {
            if hasContent {
                // 펄싱 커서 — 텍스트 끝을 이어가는 블록
                Rectangle()
                    .frame(width: 7, height: 14)
                    .cornerRadius(1)
                    .opacity(reduceMotion ? 0.6 : (0.3 + 0.7 * phase))
            } else {
                // 3-dot 타이핑 인디케이터
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .frame(width: 6, height: 6)
                            .opacity(reduceMotion ? 0.5 : dotOpacity(index: index))
                    }
                }
            }
        }
        .foregroundStyle(.secondary)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func dotOpacity(index: Int) -> Double {
        // 각 점의 위상을 살짝 어긋나게 → "파형"처럼 순차 깜빡임
        let offset = Double(index) * 0.33
        let wave = sin((phase + offset) * .pi * 2)
        return 0.35 + 0.5 * abs(wave)
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
    @MainActor
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

// Preview는 MessageView+Preview.swift 참조

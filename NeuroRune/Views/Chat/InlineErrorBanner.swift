//
//  InlineErrorBanner.swift
//  NeuroRune
//
//  Created by tykim
//
//  STT/TTS 등 파이프라인 에러를 노출하는 공통 인라인 배너.
//  `STTErrorBanner` / `SpeechErrorBanner`가 각자 필드 매핑 후 위임한다.
//

import SwiftUI

struct InlineErrorBanner: View {
    let title: String
    let message: String
    let icon: String
    var primary: Action? = nil
    let onDismiss: () -> Void

    struct Action {
        let title: String
        let handler: () -> Void
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let primary {
                Button(action: primary.handler) {
                    Text(primary.title)
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(String(localized: "error.cancel"))
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Plain") {
    InlineErrorBanner(
        title: "오류",
        message: "뭔가 잘못됐어.",
        icon: "exclamationmark.triangle.fill",
        onDismiss: {}
    )
}

#Preview("With CTA") {
    InlineErrorBanner(
        title: "권한 필요",
        message: "마이크 권한을 켜줘.",
        icon: "mic.slash.fill",
        primary: .init(title: "설정 열기", handler: {}),
        onDismiss: {}
    )
}

//
//  SpeechErrorBanner.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — TTS 파이프라인 에러 노출. `STTErrorBanner` 패턴.
//

import SwiftUI

struct SpeechErrorBanner: View {
    let error: SpeechError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "speech.banner.title"))
                    .font(.subheadline.bold())
                Text(String(localized: String.LocalizationValue(error.userMessageKey)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
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

    private var iconName: String {
        switch error {
        case .unauthorized:    return "key.slash"
        case .rateLimited:     return "hourglass"
        case .network, .server: return "wifi.exclamationmark"
        case .playbackFailed:  return "speaker.slash"
        default:               return "exclamationmark.triangle.fill"
        }
    }
}

#Preview("Unauthorized") {
    SpeechErrorBanner(error: .unauthorized, onDismiss: {})
}

#Preview("Network") {
    SpeechErrorBanner(error: .network("timeout"), onDismiss: {})
}

#Preview("Playback") {
    SpeechErrorBanner(error: .playbackFailed("decode"), onDismiss: {})
}

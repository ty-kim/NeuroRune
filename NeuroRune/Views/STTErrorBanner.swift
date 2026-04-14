//
//  STTErrorBanner.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — STT 파이프라인 에러 노출. 마이크 권한 거부 시 설정 앱 딥링크 제공.
//

import SwiftUI
import UIKit

struct STTErrorBanner: View {
    let error: STTError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "stt.banner.title"))
                    .font(.subheadline.bold())
                Text(String(localized: String.LocalizationValue(error.userMessageKey)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if error == .microphonePermissionDenied {
                Button(action: openSettings) {
                    Text(String(localized: "stt.settings"))
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

    private var iconName: String {
        switch error {
        case .microphonePermissionDenied: return "mic.slash.fill"
        case .audioTooLong:               return "clock.badge.exclamationmark"
        case .network, .server:           return "wifi.exclamationmark"
        case .unauthorized:               return "key.slash"
        case .rateLimited:                return "hourglass"
        default:                          return "exclamationmark.triangle.fill"
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("Permission denied") {
    STTErrorBanner(error: .microphonePermissionDenied, onDismiss: {})
}

#Preview("Network") {
    STTErrorBanner(error: .network("timeout"), onDismiss: {})
}

#Preview("Audio too long") {
    STTErrorBanner(error: .audioTooLong, onDismiss: {})
}

#Preview("Dark Mode") {
    STTErrorBanner(error: .unauthorized, onDismiss: {})
        .preferredColorScheme(.dark)
}

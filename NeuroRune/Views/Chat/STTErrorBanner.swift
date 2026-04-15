//
//  STTErrorBanner.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — STT 파이프라인 에러. 마이크 권한 거부 시 설정 앱 딥링크 제공.
//  공통 `InlineErrorBanner`에 필드 매핑 후 위임.
//

import SwiftUI
import UIKit

struct STTErrorBanner: View {
    let error: STTError
    let onDismiss: () -> Void

    var body: some View {
        InlineErrorBanner(
            title: String(localized: "stt.banner.title"),
            message: String(localized: String.LocalizationValue(error.userMessageKey)),
            icon: iconName,
            primary: primaryAction,
            onDismiss: onDismiss
        )
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

    private var primaryAction: InlineErrorBanner.Action? {
        guard error == .microphonePermissionDenied else { return nil }
        return .init(title: String(localized: "stt.settings"), handler: openSettings)
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

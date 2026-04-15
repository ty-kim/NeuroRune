//
//  SpeechErrorBanner.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — TTS 파이프라인 에러. 공통 `InlineErrorBanner`에 위임.
//

import SwiftUI

struct SpeechErrorBanner: View {
    let error: SpeechError
    let onDismiss: () -> Void

    var body: some View {
        InlineErrorBanner(
            title: String(localized: "speech.banner.title"),
            message: String(localized: String.LocalizationValue(error.userMessageKey)),
            icon: iconName,
            onDismiss: onDismiss
        )
    }

    private var iconName: String {
        switch error {
        case .unauthorized:     return "key.slash"
        case .rateLimited:      return "hourglass"
        case .network, .server: return "wifi.exclamationmark"
        case .playbackFailed:   return "speaker.slash"
        default:                return "exclamationmark.triangle.fill"
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

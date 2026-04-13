//
//  ChatPersistenceBanner.swift
//  NeuroRune
//

import SwiftUI

struct ChatPersistenceBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "error.persistence.title"))
                    .font(.subheadline.bold())
                Text(message)
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
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "error.persistence.title") + ", " + message)
    }
}

#Preview("Short message") {
    ChatPersistenceBanner(
        message: "디스크 공간 부족",
        onDismiss: {}
    )
}

#Preview("Long message") {
    ChatPersistenceBanner(
        message: "SwiftData container unavailable: The operation couldn't be completed. (NSCocoaErrorDomain error 134060.)",
        onDismiss: {}
    )
}

#Preview("Dark Mode") {
    ChatPersistenceBanner(
        message: "저장 중 오류가 발생했습니다",
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXL") {
    ChatPersistenceBanner(
        message: "큰 글씨에서도 잘 보이나?",
        onDismiss: {}
    )
    .dynamicTypeSize(.xxxLarge)
}


//
//  ChatErrorBanner.swift
//  NeuroRune
//

import SwiftUI

struct ChatErrorBanner: View {
    let error: LLMError

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(String(localized: "error.prefix") + " " + error.userMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
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
        .accessibilityLabel(String(localized: "error.prefix") + " " + error.userMessage)
    }
}

#Preview("Unauthorized") {
    ChatErrorBanner(error: .unauthorized)
}

#Preview("Rate Limited") {
    ChatErrorBanner(error: .rateLimited)
}

#Preview("Network") {
    ChatErrorBanner(error: .network("The Internet connection appears to be offline."))
}

#Preview("Server 500") {
    ChatErrorBanner(error: .server(status: 500, message: "Internal server error"))
}

#Preview("Dark Mode") {
    ChatErrorBanner(error: .rateLimited)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXL") {
    ChatErrorBanner(error: .network("Very long error message for wrapping verification under large dynamic type"))
        .dynamicTypeSize(.xxxLarge)
}


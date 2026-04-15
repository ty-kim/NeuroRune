//
//  SecureFieldWithReveal.swift
//  NeuroRune
//
//  Created by tykim
//
//  API 키·PAT 등 비밀값 입력을 위한 SecureField + eye 토글 조합.
//  Anthropic / Azure / Groq / GitHub 자격증명 뷰 공통 컴포넌트.
//

import SwiftUI

struct SecureFieldWithReveal: View {
    let placeholder: String
    @Binding var text: String
    var accessibilityLabel: String = ""
    var accessibilityHint: String = ""

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            field
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel(accessibilityLabel.isEmpty ? placeholder : accessibilityLabel)
                .accessibilityHint(accessibilityHint)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(String(localized: isRevealed
                ? "a11y.onboarding.hideKey"
                : "a11y.onboarding.revealKey"))
        }
    }

    @ViewBuilder
    private var field: some View {
        if isRevealed {
            TextField(placeholder, text: $text)
        } else {
            SecureField(placeholder, text: $text)
        }
    }
}

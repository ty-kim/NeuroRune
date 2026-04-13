//
//  StorageErrorView.swift
//  NeuroRune
//

import SwiftUI

struct StorageErrorView: View {
    var onResetTapped: () -> Void = {}

    @State private var showConfirmReset = false
    @State private var didReset = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text(String(localized: "storage.error.title"))
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(String(localized: didReset ? "storage.error.resetDoneBody" : "storage.error.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            if !didReset {
                Button(role: .destructive) {
                    showConfirmReset = true
                } label: {
                    Text(String(localized: "storage.error.resetButton"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .confirmationDialog(
            String(localized: "storage.error.resetConfirmTitle"),
            isPresented: $showConfirmReset,
            titleVisibility: .visible
        ) {
            Button(String(localized: "storage.error.resetConfirm"), role: .destructive) {
                try? ConversationStore.resetDefaultStorage()
                didReset = true
                onResetTapped()
            }
            Button(String(localized: "error.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "storage.error.resetConfirmMessage"))
        }
    }
}

#Preview("Initial") {
    StorageErrorView()
}

#Preview("Dark Mode") {
    StorageErrorView()
        .preferredColorScheme(.dark)
}

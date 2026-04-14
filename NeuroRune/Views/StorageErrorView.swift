//
//  StorageErrorView.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI

struct StorageErrorView: View {
    var onResetTapped: () -> Void = {}

    @State private var showConfirmReset = false
    @State private var didReset = false
    @State private var resetErrorMessage: String?

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
                do {
                    try ConversationStore.resetDefaultStorage()
                    didReset = true
                    onResetTapped()
                } catch {
                    resetErrorMessage = error.localizedDescription
                }
            }
            Button(String(localized: "error.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "storage.error.resetConfirmMessage"))
        }
        .alert(
            String(localized: "storage.error.resetFailedTitle"),
            isPresented: .init(
                get: { resetErrorMessage != nil },
                set: { if !$0 { resetErrorMessage = nil } }
            ),
            presenting: resetErrorMessage
        ) { _ in
            Button(String(localized: "error.cancel"), role: .cancel) {
                resetErrorMessage = nil
            }
        } message: { detail in
            Text(detail)
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

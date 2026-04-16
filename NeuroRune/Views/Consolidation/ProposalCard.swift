//
//  ProposalCard.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 5 — 단일 Consolidation 제안 카드. action 배지 + diff + 수락/거절.
//

import SwiftUI

struct ProposalCard: View {
    let proposal: ConsolidationProposal
    let isAccepting: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(proposal.path)
                .font(.callout.monospaced())
                .foregroundStyle(.primary)
            Text(proposal.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let content = proposal.content {
                Divider()
                if proposal.action == .update, let before = proposal.beforeContent {
                    DisclosureGroup(String(localized: "consolidation.diff")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("- before").font(.caption2).foregroundStyle(.secondary)
                            Text(before)
                                .font(.caption.monospaced())
                                .foregroundStyle(.red)
                            Text("+ after").font(.caption2).foregroundStyle(.secondary)
                            Text(content)
                                .font(.caption.monospaced())
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    DisclosureGroup(String(localized: "consolidation.preview")) {
                        Text(content)
                            .font(.caption.monospaced())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            buttons
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(actionLabel)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(actionColor.opacity(0.18))
                .foregroundStyle(actionColor)
                .clipShape(Capsule())
            Spacer()
            if isAccepting {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(role: .destructive) {
                onReject()
            } label: {
                Label(String(localized: "consolidation.reject"), systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .disabled(isAccepting)

            Spacer()

            Button {
                onAccept()
            } label: {
                Label(String(localized: "consolidation.accept"), systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAccepting)
        }
    }

    private var actionLabel: String {
        switch proposal.action {
        case .create: return String(localized: "consolidation.action.create")
        case .update: return String(localized: "consolidation.action.update")
        case .delete: return String(localized: "consolidation.action.delete")
        case .skip:   return String(localized: "consolidation.action.skip")
        }
    }

    private var actionColor: Color {
        switch proposal.action {
        case .create: return .green
        case .update: return .orange
        case .delete: return .red
        case .skip:   return .gray
        }
    }
}

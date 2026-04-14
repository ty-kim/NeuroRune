//
//  WriteApprovalModal.swift
//  NeuroRune
//

import SwiftUI

/// Claude가 write_memory 호출 시 사용자 승인 받는 모달.
/// role/path/commit_message + content preview 표시. Accept/Reject 버튼.
struct WriteApprovalModal: View {
    let request: ChatFeature.WriteRequest
    var onApprove: () -> Void
    var onReject: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    labelRow(String(localized: "writeApproval.role"), value: request.role.rawValue)
                    labelRow(String(localized: "writeApproval.path"), value: request.path)
                    labelRow(String(localized: "writeApproval.commitMessage"), value: request.commitMessage)

                    Divider()

                    Text(String(localized: "writeApproval.content"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(request.content)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle(String(localized: "writeApproval.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "writeApproval.cancel"), role: .cancel) {
                        onReject()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "writeApproval.save")) {
                        onApprove()
                    }
                    .bold()
                }
            }
        }
    }

    private func labelRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.footnote)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("New file") {
    WriteApprovalModal(
        request: ChatFeature.WriteRequest(
            id: "t1",
            role: .global,
            path: "runes/insight.md",
            content: "# 통찰\n\n오늘의 발견.\n- 항목 1\n- 항목 2",
            commitMessage: "Add runes/insight.md"
        ),
        onApprove: {},
        onReject: {}
    )
}

#Preview("Dark") {
    WriteApprovalModal(
        request: ChatFeature.WriteRequest(
            id: "t1",
            role: .local,
            path: "project_neurorune.md",
            content: "## 진행\n- 단계 1",
            commitMessage: "Update project_neurorune.md"
        ),
        onApprove: {},
        onReject: {}
    )
    .preferredColorScheme(.dark)
}

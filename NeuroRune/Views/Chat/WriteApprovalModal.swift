//
//  WriteApprovalModal.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI

/// Claude가 write_memory 호출 시 사용자 승인 받는 모달.
/// role/path/commit_message + (before)/after + diff 카운트 표시. Accept/Reject 버튼.
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

                    changeSummary

                    if let existing = request.existingContent {
                        diffBlock(old: existing, new: request.content)
                    } else {
                        contentBlock(
                            label: String(localized: "writeApproval.new"),
                            content: request.content,
                            tint: Color.green.opacity(0.1)
                        )
                    }
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
                }
            }
        }
    }

    /// 변경 요약: 신규/+추가/-삭제/변경 없음
    @ViewBuilder
    private var changeSummary: some View {
        if let existing = request.existingContent {
            let oldLines = existing.components(separatedBy: "\n")
            let newLines = request.content.components(separatedBy: "\n")
            let diff = newLines.difference(from: oldLines)
            let added = diff.insertions.count
            let removed = diff.removals.count

            HStack(spacing: 8) {
                if added == 0 && removed == 0 {
                    badge(String(localized: "writeApproval.noChange"), tint: .secondary)
                } else {
                    if added > 0 {
                        badge("+\(added)", tint: .green)
                    }
                    if removed > 0 {
                        badge("-\(removed)", tint: .red)
                    }
                }
            }
        } else {
            badge(String(localized: "writeApproval.new"), tint: .green)
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }

    /// git diff 스타일 블록. 각 라인 prefix -/+/ 와 색상 구분.
    private func diffBlock(old: String, new: String) -> some View {
        let lines = LineDiff.compute(old: old, new: new)
        return VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "writeApproval.diff"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    diffLineView(line)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func diffLineView(_ line: DiffLine) -> some View {
        switch line {
        case let .context(text):
            HStack(alignment: .top, spacing: 6) {
                Text(" ").foregroundStyle(.secondary)
                Text(text).foregroundStyle(.secondary)
            }
            .font(.system(.footnote, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)

        case let .added(text):
            HStack(alignment: .top, spacing: 6) {
                Text("+").foregroundStyle(.green)
                Text(text).foregroundStyle(.primary)
            }
            .font(.system(.footnote, design: .monospaced))
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.15))
            .textSelection(.enabled)

        case let .removed(text):
            HStack(alignment: .top, spacing: 6) {
                Text("-").foregroundStyle(.red)
                Text(text).foregroundStyle(.primary).strikethrough(color: .red.opacity(0.5))
            }
            .font(.system(.footnote, design: .monospaced))
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.12))
            .textSelection(.enabled)
        }
    }

    private func contentBlock(label: String, content: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(content)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func labelRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "%@, %@"), label, value))
    }
}

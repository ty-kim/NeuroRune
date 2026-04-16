//
//  LineDiff.swift
//  NeuroRune
//
//  Created by tykim
//
//  WriteApprovalModal의 git-diff 스타일 표시용 순수 라인 diff.
//  CollectionDifference로 산출된 removals / insertions를 원본 순서 기준으로 병합.
//

import Foundation

nonisolated enum DiffLine: Equatable, Sendable {
    /// 양쪽에 공통 — 변경 없음. 보통 회색 prefix " ".
    case context(String)
    /// 새 내용에만 있음. prefix "+".
    case added(String)
    /// 기존 내용에만 있음. prefix "-".
    case removed(String)
}

nonisolated enum LineDiff {
    /// 두 텍스트를 줄 단위로 diff. 출력은 old/new를 동시에 훑으며
    /// removal은 old의 해당 offset, insertion은 new의 해당 offset에서 emit.
    static func compute(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let diff = newLines.difference(from: oldLines)

        let removalOffsets: [Int] = diff.removals.compactMap { change in
            if case let .remove(offset, _, _) = change { return offset }
            return nil
        }.sorted()
        let insertionOffsets: [Int] = diff.insertions.compactMap { change in
            if case let .insert(offset, _, _) = change { return offset }
            return nil
        }.sorted()

        var result: [DiffLine] = []
        var oldIndex = 0
        var newIndex = 0
        var removalIndex = 0
        var insertionIndex = 0

        while oldIndex < oldLines.count || newIndex < newLines.count {
            if removalIndex < removalOffsets.count, removalOffsets[removalIndex] == oldIndex {
                result.append(.removed(oldLines[oldIndex]))
                oldIndex += 1
                removalIndex += 1
            } else if insertionIndex < insertionOffsets.count, insertionOffsets[insertionIndex] == newIndex {
                result.append(.added(newLines[newIndex]))
                newIndex += 1
                insertionIndex += 1
            } else {
                // 양쪽 동시에 진행되는 context 라인.
                result.append(.context(oldLines[oldIndex]))
                oldIndex += 1
                newIndex += 1
            }
        }

        return result
    }
}

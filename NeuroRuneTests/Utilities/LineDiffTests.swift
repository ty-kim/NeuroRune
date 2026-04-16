//
//  LineDiffTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  WriteApprovalModal git-diff 표시용 순수 함수 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct LineDiffTests {

    @Test("같은 텍스트: 모든 줄이 context")
    func identical() {
        let lines = LineDiff.compute(old: "a\nb\nc", new: "a\nb\nc")
        #expect(lines == [.context("a"), .context("b"), .context("c")])
    }

    @Test("끝에 한 줄 추가")
    func addAtEnd() {
        let lines = LineDiff.compute(old: "a\nb", new: "a\nb\nc")
        #expect(lines == [.context("a"), .context("b"), .added("c")])
    }

    @Test("끝의 한 줄 삭제")
    func removeAtEnd() {
        let lines = LineDiff.compute(old: "a\nb\nc", new: "a\nb")
        #expect(lines == [.context("a"), .context("b"), .removed("c")])
    }

    @Test("중간 한 줄 교체: - 후 + 순서")
    func replaceMiddle() {
        let lines = LineDiff.compute(old: "a\nb\nc", new: "a\nB\nc")
        #expect(lines == [.context("a"), .removed("b"), .added("B"), .context("c")])
    }

    @Test("맨 앞 추가")
    func addAtStart() {
        let lines = LineDiff.compute(old: "b\nc", new: "a\nb\nc")
        #expect(lines == [.added("a"), .context("b"), .context("c")])
    }

    @Test("빈 old → 전부 added")
    func allAdded() {
        let lines = LineDiff.compute(old: "", new: "a\nb")
        #expect(lines == [.removed(""), .added("a"), .added("b")])
    }
}

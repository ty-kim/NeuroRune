//
//  MemoryPathPolicyTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Foundation
import Testing
@testable import NeuroRune

struct MemoryPathPolicyTests {

    @Test("정상 상대 경로는 그대로 반환")
    func valid() throws {
        #expect(try MemoryPathPolicy.validate("memory/user_profile.md") == "memory/user_profile.md")
        #expect(try MemoryPathPolicy.validate("foo.md") == "foo.md")
        #expect(try MemoryPathPolicy.validate("a/b/c/deep.md") == "a/b/c/deep.md")
    }

    @Test("선행 슬래시는 제거")
    func stripsLeadingSlash() throws {
        #expect(try MemoryPathPolicy.validate("/memory/foo.md") == "memory/foo.md")
        #expect(try MemoryPathPolicy.validate("///foo.md") == "foo.md")
    }

    @Test("중간 연속 슬래시는 병합")
    func collapsesDoubleSlash() throws {
        #expect(try MemoryPathPolicy.validate("memory//foo.md") == "memory/foo.md")
    }

    @Test("빈 경로 거부")
    func rejectsEmpty() {
        #expect(throws: MemoryPathError.empty) { _ = try MemoryPathPolicy.validate("") }
        #expect(throws: MemoryPathError.empty) { _ = try MemoryPathPolicy.validate("   ") }
        #expect(throws: MemoryPathError.empty) { _ = try MemoryPathPolicy.validate("/") }
    }

    @Test("`..` parent traversal 거부")
    func rejectsParentTraversal() {
        #expect(throws: MemoryPathError.parentTraversal) {
            _ = try MemoryPathPolicy.validate("../secrets.md")
        }
        #expect(throws: MemoryPathError.parentTraversal) {
            _ = try MemoryPathPolicy.validate("memory/../other.md")
        }
    }

    @Test("`.` current directory 거부")
    func rejectsCurrentDirectory() {
        #expect(throws: MemoryPathError.currentDirectory) {
            _ = try MemoryPathPolicy.validate("./foo.md")
        }
    }

    @Test("hidden segment(.github 등) 거부")
    func rejectsHiddenSegment() {
        #expect(throws: MemoryPathError.self) {
            _ = try MemoryPathPolicy.validate(".github/workflows/ci.yml")
        }
        #expect(throws: MemoryPathError.self) {
            _ = try MemoryPathPolicy.validate("memory/.hidden/x.md")
        }
        #expect(throws: MemoryPathError.self) {
            _ = try MemoryPathPolicy.validate(".env")
        }
    }

    @Test("null byte 거부")
    func rejectsNullByte() {
        #expect(throws: MemoryPathError.invalidCharacter) {
            _ = try MemoryPathPolicy.validate("foo\0bar.md")
        }
    }

    @Test("길이 상한 초과 거부")
    func rejectsTooLong() {
        let long = String(repeating: "a", count: 256)
        #expect(throws: MemoryPathError.self) {
            _ = try MemoryPathPolicy.validate(long)
        }
    }
}

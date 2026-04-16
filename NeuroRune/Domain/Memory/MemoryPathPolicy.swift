//
//  MemoryPathPolicy.swift
//  NeuroRune
//
//  Created by tykim
//
//  LLM tool(read_memory/write_memory)와 수동 메모리 편집 경로에 공통 적용되는
//  path 검증 정책. prompt injection 방지 (.., 절대경로, hidden directory 등).
//

import Foundation

nonisolated enum MemoryPathError: Error, Equatable {
    case empty
    case tooLong(Int)
    case parentTraversal
    case currentDirectory
    case hiddenSegment(String)
    case invalidCharacter
}

extension MemoryPathError {
    var localizedMessage: String {
        switch self {
        case .empty:                   return "Path is empty"
        case let .tooLong(n):          return "Path too long: \(n) chars"
        case .parentTraversal:         return "Parent traversal (..) not allowed"
        case .currentDirectory:        return "Current directory (.) not allowed"
        case let .hiddenSegment(s):    return "Hidden directory not allowed: \(s)"
        case .invalidCharacter:        return "Invalid character in path"
        }
    }
}

nonisolated enum MemoryPathPolicy {
    /// GitHub path segment 개별 최대치는 깊게 제한하지 않되, 전체 길이는 cap.
    static let maxLength = 255

    /// 입력 경로를 검증·정규화해 repo-relative path로 반환.
    /// - 선행 `/` 제거 (절대경로 금지)
    /// - 중복 `/` 제거
    /// - `..` / `.` / hidden segment(`.`로 시작) 거부
    /// - 전체 길이·null byte 검사
    static func validate(_ input: String) throws -> String {
        guard !input.contains("\0") else { throw MemoryPathError.invalidCharacter }
        guard input.count <= maxLength else { throw MemoryPathError.tooLong(input.count) }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MemoryPathError.empty }

        // 선행 `/` 제거
        let noLeading = trimmed.drop(while: { $0 == "/" })

        // segment 분리 (연속 `/` 자동 skip)
        let segments = noLeading.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !segments.isEmpty else { throw MemoryPathError.empty }

        for segment in segments {
            if segment == ".." { throw MemoryPathError.parentTraversal }
            if segment == "." { throw MemoryPathError.currentDirectory }
            if segment.hasPrefix(".") { throw MemoryPathError.hiddenSegment(segment) }
        }

        return segments.joined(separator: "/")
    }
}

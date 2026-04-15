//
//  SentenceStreamer.swift
//  NeuroRune
//
//  Created by tykim
//
//  스트리밍 청크에서 완성된 문장을 추출. TTS 문장 단위 재생용.
//  보수적: 경계가 애매하면 버퍼에 유지(나중에 문장이 완성되길 기다림).
//

import Foundation

nonisolated enum SentenceStreamer {

    /// 청크를 버퍼에 붙이면서 완성된 문장들을 반환.
    /// 남는 부분은 `buffer`에 그대로 보관.
    static func extract(_ chunk: String, buffer: inout String) -> [String] {
        buffer += chunk
        var sentences: [String] = []
        var lastEnd = buffer.startIndex
        var i = buffer.startIndex

        while i < buffer.endIndex {
            let c = buffer[i]

            // 단락 경계: "\n\n"
            if c == "\n", let next = buffer.index(i, offsetBy: 1, limitedBy: buffer.endIndex),
               next < buffer.endIndex, buffer[next] == "\n" {
                let segment = buffer[lastEnd...i].trimmingCharacters(in: .whitespacesAndNewlines)
                if !segment.isEmpty { sentences.append(segment) }
                lastEnd = buffer.index(after: next)
                i = lastEnd
                continue
            }

            if isSentenceTerminator(c) {
                if isValidBoundary(buffer: buffer, terminatorIndex: i) {
                    let endExclusive = buffer.index(after: i)
                    let segment = buffer[lastEnd..<endExclusive].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !segment.isEmpty { sentences.append(segment) }
                    // 다음 문장 시작 위치에서 선행 공백·개행 스킵 → 버퍼에 공백 leading 제거
                    var cursor = endExclusive
                    while cursor < buffer.endIndex, buffer[cursor].isWhitespace {
                        cursor = buffer.index(after: cursor)
                    }
                    lastEnd = cursor
                    i = cursor
                    continue
                }
            }

            i = buffer.index(after: i)
        }

        buffer = String(buffer[lastEnd...])
        return sentences
    }

    /// 종결 후보 문자: `.` `?` `!` `。` `？` `！`
    private static func isSentenceTerminator(_ c: Character) -> Bool {
        "\u{002E}\u{0021}\u{003F}\u{3002}\u{FF01}\u{FF1F}".contains(c)
    }

    /// CJK fullwidth 종결은 후행 공백 없어도 경계.
    private static func isCJKTerminator(_ c: Character) -> Bool {
        "\u{3002}\u{FF01}\u{FF1F}".contains(c)  // 。 ！ ？
    }

    /// 이 위치에서 종결로 판단해도 되는지.
    /// - CJK fullwidth `。！？` 는 무조건 경계
    /// - ASCII `.!?` 는 뒤에 공백/개행이어야 경계
    /// - `.` 은 앞뒤 숫자/연속 `.`(3.5, 1.0, ..., 1..) 이면 경계 아님
    private static func isValidBoundary(buffer: String, terminatorIndex i: String.Index) -> Bool {
        let c = buffer[i]

        // `.` 특수 케이스
        if c == "." {
            let prevIndex: String.Index? = i > buffer.startIndex ? buffer.index(before: i) : nil
            let nextIndex: String.Index? = buffer.index(i, offsetBy: 1, limitedBy: buffer.endIndex)

            if let prev = prevIndex, buffer[prev].isNumber { return false }
            if let prev = prevIndex, buffer[prev] == "." { return false }
            if let next = nextIndex, next < buffer.endIndex, buffer[next].isNumber { return false }
            if let next = nextIndex, next < buffer.endIndex, buffer[next] == "." { return false }
        }

        // CJK 종결부호는 후행 공백 불필요
        if isCJKTerminator(c) {
            return true
        }

        // ASCII 종결은 뒤에 공백/개행이어야 경계. 버퍼 끝이면 아직 더 올 수 있으니 경계 X.
        let next: String.Index? = buffer.index(i, offsetBy: 1, limitedBy: buffer.endIndex)
        guard let next, next < buffer.endIndex else { return false }
        return buffer[next].isWhitespace
    }
}

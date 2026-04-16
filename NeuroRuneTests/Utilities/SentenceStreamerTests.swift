//
//  SentenceStreamerTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Foundation
import Testing
@testable import NeuroRune

struct SentenceStreamerTests {

    @Test("단순 문장: 마침표·물음표·느낌표 뒤 공백")
    func simpleSentences() {
        var buffer = ""
        let out = SentenceStreamer.extract("안녕하세요. 반가워요! 오늘 어때? ", buffer: &buffer)
        #expect(out == ["안녕하세요.", "반가워요!", "오늘 어때?"])
        #expect(buffer.trimmingCharacters(in: .whitespaces) == "")
    }

    @Test("종결 뒤에 공백 없이 끝나면 버퍼에 보관")
    func unfinishedTrailing() {
        var buffer = ""
        let out = SentenceStreamer.extract("안녕하세요.", buffer: &buffer)
        #expect(out.isEmpty)
        #expect(buffer == "안녕하세요.")
    }

    @Test("청크 2번에 걸친 문장이 완성되면 반환")
    func splitAcrossChunks() {
        var buffer = ""
        _ = SentenceStreamer.extract("안녕하세", buffer: &buffer)
        let out = SentenceStreamer.extract("요. 반가워요.", buffer: &buffer)
        #expect(out == ["안녕하세요."])
        #expect(buffer == "반가워요.")
    }

    @Test("3.5 같은 숫자 사이 마침표는 경계 아님")
    func decimalNumberNotBoundary() {
        var buffer = ""
        let out = SentenceStreamer.extract("3.5배 빨라져요. ", buffer: &buffer)
        #expect(out == ["3.5배 빨라져요."])
    }

    @Test("v1.0 스타일도 경계 아님")
    func versionNumberNotBoundary() {
        var buffer = ""
        let out = SentenceStreamer.extract("v1.0은 구버전이다. ", buffer: &buffer)
        #expect(out == ["v1.0은 구버전이다."])
    }

    @Test("연속 ... 는 경계 아님")
    func ellipsisNotBoundary() {
        var buffer = ""
        let out = SentenceStreamer.extract("잠깐... 기다려. ", buffer: &buffer)
        #expect(out == ["잠깐... 기다려."])
    }

    @Test("빈 줄(\\n\\n) 은 단락 경계로 split")
    func paragraphBoundary() {
        var buffer = ""
        let out = SentenceStreamer.extract("첫 문단입니다\n\n두 번째 문단", buffer: &buffer)
        #expect(out == ["첫 문단입니다"])
        #expect(buffer == "두 번째 문단")
    }

    @Test("중국어·일본어 종결부호 `。` `！` `？`")
    func cjkTerminators() {
        var buffer = ""
        let out = SentenceStreamer.extract("你好。怎么样？ 很好！ ", buffer: &buffer)
        #expect(out == ["你好。", "怎么样?".replacingOccurrences(of: "?", with: "？"), "很好！"])
    }

    @Test("경계 뒤 공백이 아직 안 왔으면 다음 청크 기다림")
    func needsTrailingSpace() {
        var buffer = ""
        let first = SentenceStreamer.extract("안녕.", buffer: &buffer)
        #expect(first.isEmpty)
        let second = SentenceStreamer.extract(" 반가워.", buffer: &buffer)
        #expect(second == ["안녕."])
    }

    @Test("영문 문장 + 숫자 혼합")
    func mixedEnglishWithNumbers() {
        var buffer = ""
        let out = SentenceStreamer.extract("It's 3.5x faster. You can test now. ", buffer: &buffer)
        #expect(out == ["It's 3.5x faster.", "You can test now."])
    }

    @Test("여러 청크 순차 누적")
    func cumulativeMultiChunk() {
        var buffer = ""
        let chunks = ["첫 문장. 두 번째", " 문장. 세 번째", " 문장. "]
        var all: [String] = []
        for c in chunks {
            all.append(contentsOf: SentenceStreamer.extract(c, buffer: &buffer))
        }
        #expect(all == ["첫 문장.", "두 번째 문장.", "세 번째 문장."])
    }
}

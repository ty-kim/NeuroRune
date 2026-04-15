//
//  SpeechTextSanitizerTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Foundation
import Testing
@testable import NeuroRune

struct SpeechTextSanitizerTests {

    @Test("평서문은 그대로")
    func plainUntouched() {
        #expect(speechPlainText(from: "안녕하세요") == "안녕하세요")
    }

    @Test("코드블록은 [코드]로 치환")
    func codeBlockReplaced() {
        let md = """
        설명:
        ```swift
        let x = 42
        print(x)
        ```
        끝.
        """
        let out = speechPlainText(from: md)
        #expect(out.contains("[코드]"))
        #expect(!out.contains("let x"))
    }

    @Test("인라인 코드는 내용만")
    func inlineCodeContentOnly() {
        #expect(speechPlainText(from: "`actor`는 격리된다") == "actor는 격리된다")
    }

    @Test("링크는 텍스트만")
    func linkTextOnly() {
        #expect(speechPlainText(from: "[Apple](https://apple.com)은 iOS를 만든다") == "Apple은 iOS를 만든다")
    }

    @Test("이미지는 alt만")
    func imageAltOnly() {
        #expect(speechPlainText(from: "![로고](x.png) 설명") == "로고 설명")
    }

    @Test("제목 마커 제거")
    func headingMarkersStripped() {
        let md = "# 제목 1\n## 제목 2\n### 제목 3"
        let out = speechPlainText(from: md)
        #expect(out == "제목 1\n제목 2\n제목 3")
    }

    @Test("강조 마커 제거")
    func emphasisStripped() {
        #expect(speechPlainText(from: "**굵게** 그리고 *기울임*") == "굵게 그리고 기울임")
        #expect(speechPlainText(from: "__볼드__ __끝__") == "볼드 끝")
        #expect(speechPlainText(from: "~~취소선~~ 일반") == "취소선 일반")
    }

    @Test("인용 마커 제거")
    func blockquoteStripped() {
        #expect(speechPlainText(from: "> 인용된 문장\n일반 문장") == "인용된 문장\n일반 문장")
    }

    @Test("연속 개행 정규화")
    func collapseNewlines() {
        let md = "첫줄\n\n\n\n두번째줄"
        #expect(speechPlainText(from: md) == "첫줄\n\n두번째줄")
    }

    @Test("혼합 마크다운 종합")
    func mixed() {
        let md = """
        # Swift actor

        `actor`는 **동시성**을 위한 구조다. [문서](https://swift.org)

        ```
        actor X {}
        ```
        """
        let out = speechPlainText(from: md)
        #expect(out.contains("Swift actor"))
        #expect(out.contains("actor는 동시성을 위한 구조다"))
        #expect(out.contains("문서"))
        #expect(out.contains("[코드]"))
        #expect(!out.contains("```"))
        #expect(!out.contains("**"))
        #expect(!out.contains("https://"))
    }

    @Test("앞뒤 공백 트림")
    func trim() {
        #expect(speechPlainText(from: "   안녕\n\n  ") == "안녕")
    }
}

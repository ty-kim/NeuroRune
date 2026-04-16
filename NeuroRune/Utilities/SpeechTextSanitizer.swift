//
//  SpeechTextSanitizer.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — 마크다운 텍스트를 TTS에 보낼 평문으로 정제.
//  손실 허용. 구조(제목/코드블록 등)보다 읽기 흐름 우선.
//

import Foundation

/// 마크다운 텍스트를 TTS용 평문으로 변환.
/// - 코드블록(```): "[코드]" 치환
/// - 인라인 코드(`x`): 내용만
/// - 이미지(`![alt](url)`): `alt`만
/// - 링크(`[text](url)`): `text`만
/// - 제목(`# `): 마커만 제거
/// - 강조(`** __ * _ ~~`): 기호만 제거
/// - 인용(`> `): 마커만 제거
/// - 연속 공백·개행은 정규화.
nonisolated func speechPlainText(from markdown: String) -> String {
    var text = markdown

    // 1. 코드블록 ```...```
    text = text.replacing(
        /```[\s\S]*?```/,
        with: "[코드]"
    )

    // 2. 이미지 ![alt](url) → alt
    text = text.replacing(
        /!\[([^\]]*)\]\([^)]*\)/,
        with: { match in String(match.output.1) }
    )

    // 3. 링크 [text](url) → text
    text = text.replacing(
        /\[([^\]]+)\]\([^)]*\)/,
        with: { match in String(match.output.1) }
    )

    // 4. 인라인 코드 `x` → x
    text = text.replacing(
        /`([^`]+)`/,
        with: { match in String(match.output.1) }
    )

    // 5. 제목 마커 `# ` `## ` 등 (줄 시작)
    text = text.replacing(
        /^#{1,6}\s+/.anchorsMatchLineEndings(),
        with: ""
    )

    // 6. 인용 마커 `> ` (줄 시작)
    text = text.replacing(
        /^>\s?/.anchorsMatchLineEndings(),
        with: ""
    )

    // 7. 강조 마커 제거. ** __ ~~를 먼저 소비하고 남은 * _ 제거.
    //    lookbehind 미지원이라 순차 치환으로 대체.
    text = text.replacing(/\*\*/, with: "")
    text = text.replacing(/__/, with: "")
    text = text.replacing(/~~/, with: "")
    text = text.replacing(/\*/, with: "")
    text = text.replacing(/_/, with: "")

    // 8. 연속 개행·공백 정규화
    text = text.replacing(/\n{3,}/, with: "\n\n")
    text = text.replacing(/[ \t]{2,}/, with: " ")

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

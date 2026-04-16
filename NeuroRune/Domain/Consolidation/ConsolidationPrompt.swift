//
//  ConsolidationPrompt.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 2 — 대화+메모리 → LLM 정제 프롬프트 빌더.
//  system은 고정 규칙(출력 스키마·안티바디·빈 결과 허용), user는 실제 데이터.
//

import Foundation

nonisolated struct ConsolidationInput: Sendable, Equatable {
    struct Transcript: Sendable, Equatable {
        let title: String
        let date: Date
        let text: String
    }
    struct MemoryFile: Sendable, Equatable {
        let path: String
        let content: String
    }
    var conversations: [Transcript]
    var memoryIndex: String
    var memoryFiles: [MemoryFile]
}

nonisolated enum ConsolidationPrompt {
    static func build(_ input: ConsolidationInput) -> (system: String, user: String) {
        (buildSystem(), buildUser(input))
    }

    private static func buildSystem() -> String {
        """
        너는 사용자의 외장 해마(NeuroRune)에서 consolidation을 담당한다.
        최근 대화와 기존 메모리를 훑어 정제 제안을 내라.

        매우 중요한 원칙:
        - "제안 없음"이 정상이다. 억지로 패턴을 만들지 마라.
        - 매일 여러 개 발견하는 건 narrative pull(약장수 모드)이다. 조용한 morning이 좋은 morning.
        - 확실치 않으면 skip. 과소 정제 > 과대 정제.

        출력은 다음 JSON 스키마만 사용한다. 다른 텍스트 금지.
        {
          "proposals": [
            {
              "action": "create" | "update" | "delete" | "skip",
              "path": "memory/...",
              "rationale": "어느 대화·어떤 맥락에서 나왔는지",
              "content": "create/update 시 마크다운 본문",
              "beforeContent": "update 시 기존 본문(있으면)"
            }
          ]
        }

        proposals가 빈 배열이어도 완전히 유효한 응답이다.
        """
    }

    private static func buildUser(_ input: ConsolidationInput) -> String {
        var lines: [String] = []
        lines.append("## 기존 MEMORY.md 인덱스")
        lines.append(input.memoryIndex.isEmpty ? "(없음)" : input.memoryIndex)
        lines.append("")

        lines.append("## 참조된 메모리 파일")
        if input.memoryFiles.isEmpty {
            lines.append("(없음)")
        } else {
            for f in input.memoryFiles {
                lines.append("### \(f.path)")
                lines.append(f.content)
                lines.append("")
            }
        }

        lines.append("## 최근 대화")
        if input.conversations.isEmpty {
            lines.append("(없음)")
        } else {
            let fmt = ISO8601DateFormatter()
            for c in input.conversations {
                lines.append("### \(c.title) — \(fmt.string(from: c.date))")
                lines.append(c.text)
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }
}

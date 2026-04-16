//
//  ConsolidationCollector.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 23 Slice 3c — ConversationStore + GitHub에서 ConsolidationInput 조립.
//

import Foundation
import Dependencies

nonisolated struct ConsolidationCollector: Sendable {
    /// 최근 대화(N개) + MEMORY.md + 참조 파일을 수집해 ConsolidationInput 반환.
    var collect: @Sendable () async throws -> ConsolidationInput
}

nonisolated extension ConsolidationCollector {
    /// 마크다운 문서에서 상대경로 `.md` 링크만 추출. 순서 보존 + 중복 제거.
    /// - 외부 URL(http/https) 제외
    /// - `file.md#section` 앵커는 파일 경로만 남김
    static func parseMemoryReferences(_ markdown: String) -> [String] {
        // 간단한 regex: ](path.md) 또는 ](path.md#...)
        let pattern = #"\]\(([^)\s]+?\.md)(?:#[^)]*)?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = markdown as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: markdown, range: range)

        var seen = Set<String>()
        var result: [String] = []
        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            let path = ns.substring(with: m.range(at: 1))
            if path.hasPrefix("http://") || path.hasPrefix("https://") { continue }
            if seen.insert(path).inserted {
                result.append(path)
            }
        }
        return result
    }

    /// Conversation → Transcript 변환. 각 메시지는 `role: content` 한 줄씩.
    static func makeTranscript(from conversation: Conversation) -> ConsolidationInput.Transcript {
        let body = conversation.messages
            .map { "\($0.role.rawValue): \($0.content)" }
            .joined(separator: "\n")
        return .init(
            title: conversation.title,
            date: conversation.createdAt,
            text: body
        )
    }

    /// `days` 이내 `createdAt`을 가진 대화만 반환. 순서는 입력 보존.
    static func filterRecent(_ conversations: [Conversation], now: Date, days: Int) -> [Conversation] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        return conversations.filter { $0.createdAt >= cutoff }
    }
}

// MARK: - Dependency

nonisolated extension ConsolidationCollector: DependencyKey {
    static let liveValue = ConsolidationCollector(
        collect: {
            @Dependency(\.conversationStore) var store
            @Dependency(\.githubClient) var github
            @Dependency(\.date) var date

            let all = (try? await store.loadAll()) ?? []
            let recent = filterRecent(all, now: date.now, days: 7)
            let transcripts = recent.map(makeTranscript(from:))

            var memoryIndex = ""
            var files: [ConsolidationInput.MemoryFile] = []
            if let index = try? await github.loadFile(.local, "MEMORY.md") {
                memoryIndex = index.content
                let refs = parseMemoryReferences(memoryIndex)
                for path in refs {
                    if let file = try? await github.loadFile(.local, path) {
                        files.append(.init(path: path, content: file.content))
                    }
                }
            }

            return ConsolidationInput(
                conversations: transcripts,
                memoryIndex: memoryIndex,
                memoryFiles: files
            )
        }
    )

    static let testValue = ConsolidationCollector(
        collect: unimplemented(
            "ConsolidationCollector.collect",
            placeholder: ConsolidationInput(conversations: [], memoryIndex: "", memoryFiles: [])
        )
    )

    static let previewValue = ConsolidationCollector(
        collect: { ConsolidationInput(conversations: [], memoryIndex: "", memoryFiles: []) }
    )
}

extension DependencyValues {
    nonisolated var consolidationCollector: ConsolidationCollector {
        get { self[ConsolidationCollector.self] }
        set { self[ConsolidationCollector.self] = newValue }
    }
}

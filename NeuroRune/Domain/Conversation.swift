//
//  Conversation.swift
//  NeuroRune
//

import Foundation

nonisolated struct Conversation: Equatable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var messages: [Message]
    let modelId: String
    let createdAt: Date

    static func empty(modelId: String) -> Conversation {
        Conversation(
            id: UUID(),
            title: "",
            messages: [],
            modelId: modelId,
            createdAt: Date()
        )
    }

    func appending(_ message: Message) -> Conversation {
        var copy = self
        copy.messages.append(message)
        return copy
    }

    /// 마지막 메시지를 `message`로 교체한 새 Conversation.
    /// messages가 비어 있으면 원본 반환.
    func replacingLastMessage(with message: Message) -> Conversation {
        guard !messages.isEmpty else { return self }
        var copy = self
        copy.messages[copy.messages.count - 1] = message
        return copy
    }

    /// 마지막 메시지가 빠진 새 Conversation.
    /// messages가 비어 있으면 원본 반환.
    func droppingLastMessage() -> Conversation {
        guard !messages.isEmpty else { return self }
        var copy = self
        copy.messages.removeLast()
        return copy
    }
}

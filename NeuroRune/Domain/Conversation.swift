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
}

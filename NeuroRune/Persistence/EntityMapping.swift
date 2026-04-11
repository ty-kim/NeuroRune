//
//  EntityMapping.swift
//  NeuroRune
//
//  Domain struct ↔ SwiftData @Model entity 변환.
//

import Foundation

extension ConversationEntity {
    static func from(_ conversation: Conversation) -> ConversationEntity {
        ConversationEntity(
            id: conversation.id,
            title: conversation.title,
            modelId: conversation.modelId,
            createdAt: conversation.createdAt,
            messages: conversation.messages.map(MessageEntity.from)
        )
    }

    func toDomain() -> Conversation {
        Conversation(
            id: id,
            title: title,
            messages: messages
                .sorted { $0.createdAt < $1.createdAt }
                .map { $0.toDomain() },
            modelId: modelId,
            createdAt: createdAt
        )
    }
}

extension MessageEntity {
    static func from(_ message: Message) -> MessageEntity {
        MessageEntity(
            roleRaw: message.role.rawValue,
            content: message.content,
            createdAt: message.createdAt
        )
    }

    func toDomain() -> Message {
        Message(
            role: Message.Role(rawValue: roleRaw) ?? .user,
            content: content,
            createdAt: createdAt
        )
    }
}

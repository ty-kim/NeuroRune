//
//  EntityMapping.swift
//  NeuroRune
//
//  Created by tykim
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
            effort: conversation.effort?.rawValue,
            messages: conversation.messages.enumerated().map { index, message in
                MessageEntity.from(message, ordinal: index)
            }
        )
    }

    func toDomain() throws -> Conversation {
        let domainMessages = try messages
            .sorted { $0.ordinal < $1.ordinal }
            .map { try $0.toDomain() }
        return Conversation(
            id: id,
            title: title,
            messages: domainMessages,
            modelId: modelId,
            createdAt: createdAt,
            effort: effort.flatMap(EffortLevel.init(rawValue:))
        )
    }
}

extension MessageEntity {
    static func from(_ message: Message, ordinal: Int) -> MessageEntity {
        MessageEntity(
            roleRaw: message.role.rawValue,
            content: message.content,
            createdAt: message.createdAt,
            ordinal: ordinal
        )
    }

    func toDomain() throws -> Message {
        guard let role = Message.Role(rawValue: roleRaw) else {
            throw PersistenceError.invalidMessageRole(roleRaw)
        }
        return Message(
            role: role,
            content: content,
            createdAt: createdAt
        )
    }
}

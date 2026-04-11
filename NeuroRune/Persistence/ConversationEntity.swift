//
//  ConversationEntity.swift
//  NeuroRune
//

import Foundation
import SwiftData

@Model
final class ConversationEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var modelId: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity]

    init(
        id: UUID,
        title: String,
        modelId: String,
        createdAt: Date,
        messages: [MessageEntity]
    ) {
        self.id = id
        self.title = title
        self.modelId = modelId
        self.createdAt = createdAt
        self.messages = messages
    }
}

@Model
final class MessageEntity {
    var roleRaw: String
    var content: String
    var createdAt: Date

    init(roleRaw: String, content: String, createdAt: Date) {
        self.roleRaw = roleRaw
        self.content = content
        self.createdAt = createdAt
    }
}

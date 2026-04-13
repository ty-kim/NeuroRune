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
    /// Default false — SwiftData lightweight migration이 기존 row에 이 값을 채움.
    var thinkingEnabled: Bool = false

    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity]

    init(
        id: UUID,
        title: String,
        modelId: String,
        createdAt: Date,
        thinkingEnabled: Bool,
        messages: [MessageEntity]
    ) {
        self.id = id
        self.title = title
        self.modelId = modelId
        self.createdAt = createdAt
        self.thinkingEnabled = thinkingEnabled
        self.messages = messages
    }
}

@Model
final class MessageEntity {
    var roleRaw: String
    var content: String
    var createdAt: Date
    /// Conversation 내에서의 입력 순서. `createdAt`은 동일 시각 / 역순 생성 등으로
    /// 대화 순서를 보장할 수 없어, 별도의 안정적인 순서 필드를 둔다.
    var ordinal: Int

    init(roleRaw: String, content: String, createdAt: Date, ordinal: Int) {
        self.roleRaw = roleRaw
        self.content = content
        self.createdAt = createdAt
        self.ordinal = ordinal
    }
}

//
//  Message.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation

nonisolated struct Message: Sendable {
    enum Role: String, Equatable, Sendable {
        case user
        case assistant
    }

    /// 세션 내 메시지 식별자. TTS 재생 대상 추적 등 UI 상태에 쓰임.
    /// 저장소에 없던 기존 레코드는 load 시점에 새로 부여됨(비영속).
    let id: UUID
    let role: Role
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

nonisolated extension Message: Equatable {
    /// Equatable은 의미적 동등성(role/content/createdAt) 기준.
    /// `id`는 UI 추적용 태그라 동등성에 제외 — TestStore 비교·중복 제거 등이 기존대로 동작.
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.role == rhs.role
            && lhs.content == rhs.content
            && lhs.createdAt == rhs.createdAt
    }
}

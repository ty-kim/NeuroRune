//
//  EntityMappingTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
@testable import NeuroRune

struct EntityMappingTests {

    @Test("손상된 roleRaw는 PersistenceError.invalidMessageRole로 throw된다")
    func toDomainThrowsOnInvalidRole() throws {
        let entity = MessageEntity(
            roleRaw: "garbage",
            content: "hi",
            createdAt: Date(timeIntervalSince1970: 100),
            ordinal: 0
        )

        #expect(throws: PersistenceError.invalidMessageRole("garbage")) {
            _ = try entity.toDomain()
        }
    }

    @Test("유효한 roleRaw는 toDomain에서 정상 변환된다")
    func toDomainSucceedsOnValidRole() throws {
        let entity = MessageEntity(
            roleRaw: "assistant",
            content: "hi",
            createdAt: Date(timeIntervalSince1970: 100),
            ordinal: 0
        )

        let message = try entity.toDomain()

        #expect(message.role == .assistant)
        #expect(message.content == "hi")
    }

    @Test("ConversationEntity ↔ Domain은 effort를 보존한다")
    func effortRoundtrip() throws {
        let conversation = Conversation(
            id: UUID(),
            title: "t",
            messages: [],
            modelId: "claude-opus-4-6",
            createdAt: Date(timeIntervalSince1970: 1_000),
            effort: .medium
        )

        let entity = ConversationEntity.from(conversation)
        #expect(entity.effort == "medium")

        let roundtrip = try entity.toDomain()
        #expect(roundtrip.effort == .medium)
    }

    @Test("effort nil은 entity에도 nil로 보존된다")
    func effortNilRoundtrip() throws {
        let conversation = Conversation(
            id: UUID(),
            title: "t",
            messages: [],
            modelId: "claude-opus-4-6",
            createdAt: Date(timeIntervalSince1970: 1_000),
            effort: nil
        )

        let entity = ConversationEntity.from(conversation)
        #expect(entity.effort == nil)

        let roundtrip = try entity.toDomain()
        #expect(roundtrip.effort == nil)
    }
}

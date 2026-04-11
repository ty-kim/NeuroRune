//
//  EntityMappingTests.swift
//  NeuroRuneTests
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
}

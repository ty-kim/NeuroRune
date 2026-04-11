//
//  ConversationStoreTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
import SwiftData
@testable import NeuroRune

struct ConversationStoreTests {

    let store: ConversationStore

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ConversationEntity.self, MessageEntity.self,
            configurations: config
        )
        store = ConversationStore.liveBacked(container: container)
    }

    @Test("save 후 load(id:)는 같은 Conversation을 반환한다")
    func saveThenLoadRoundtrip() async throws {
        let conversation = Self.sampleConversation()

        try await store.save(conversation)
        let loaded = try await store.load(conversation.id)

        #expect(loaded == conversation)
    }

    @Test("loadAll은 저장된 모든 Conversation을 반환한다")
    func loadAllReturnsAllSaved() async throws {
        let first = Self.sampleConversation(title: "a")
        let second = Self.sampleConversation(title: "b", createdAt: Date(timeIntervalSince1970: 2_000_000))

        try await store.save(first)
        try await store.save(second)

        let all = try await store.loadAll()

        #expect(all.count == 2)
        #expect(all.map(\.title).sorted() == ["a", "b"])
    }

    @Test("loadAll은 createdAt 내림차순으로 반환한다")
    func loadAllSortsByCreatedAtDescending() async throws {
        let older = Self.sampleConversation(
            title: "older",
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let newer = Self.sampleConversation(
            title: "newer",
            createdAt: Date(timeIntervalSince1970: 3_000_000)
        )
        let middle = Self.sampleConversation(
            title: "middle",
            createdAt: Date(timeIntervalSince1970: 2_000_000)
        )

        try await store.save(older)
        try await store.save(newer)
        try await store.save(middle)

        let all = try await store.loadAll()

        #expect(all.map(\.title) == ["newer", "middle", "older"])
    }

    @Test("delete(id:) 후 load(id:)는 nil을 반환한다")
    func deleteRemovesConversation() async throws {
        let conversation = Self.sampleConversation()

        try await store.save(conversation)
        try await store.delete(conversation.id)

        let loaded = try await store.load(conversation.id)

        #expect(loaded == nil)
    }

    @Test("같은 id에 save가 다시 호출되면 기존 Conversation을 업데이트한다")
    func saveOnExistingIdUpdates() async throws {
        let id = UUID()
        let original = Self.sampleConversation(id: id, title: "first")
        try await store.save(original)

        let updated = Conversation(
            id: id,
            title: "second",
            messages: [
                Message(role: .user, content: "updated content", createdAt: Date(timeIntervalSince1970: 10))
            ],
            modelId: "claude-sonnet-4-6",
            createdAt: original.createdAt
        )
        try await store.save(updated)

        let loaded = try await store.load(id)

        #expect(loaded?.title == "second")
        #expect(loaded?.modelId == "claude-sonnet-4-6")
        #expect(loaded?.messages.count == 1)
        #expect(loaded?.messages.first?.content == "updated content")

        // 총 개수도 1개여야 (업데이트지 중복 삽입 X)
        let all = try await store.loadAll()
        #expect(all.count == 1)
    }

    static func sampleConversation(
        id: UUID = UUID(),
        title: String = "sample",
        modelId: String = "claude-opus-4-6",
        createdAt: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> Conversation {
        Conversation(
            id: id,
            title: title,
            messages: [
                Message(role: .user, content: "hi", createdAt: Date(timeIntervalSince1970: 1)),
                Message(role: .assistant, content: "hello", createdAt: Date(timeIntervalSince1970: 2))
            ],
            modelId: modelId,
            createdAt: createdAt
        )
    }
}

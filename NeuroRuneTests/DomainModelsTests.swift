//
//  DomainModelsTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
@testable import NeuroRune

struct MessageTests {

    @Test("Message는 role, content, createdAt을 저장한다")
    func messageStoresProperties() {
        let createdAt = Date(timeIntervalSince1970: 1_000_000)
        let message = Message(role: .user, content: "hello", createdAt: createdAt)

        #expect(message.role == .user)
        #expect(message.content == "hello")
        #expect(message.createdAt == createdAt)
    }
}

struct ConversationTests {

    @Test("Conversation.empty(modelId:)는 messages가 빈 새 Conversation을 만든다")
    func conversationEmptyHasNoMessages() {
        let conversation = Conversation.empty(modelId: "claude-sonnet-4-6")

        #expect(conversation.messages.isEmpty)
        #expect(conversation.modelId == "claude-sonnet-4-6")
    }

    @Test("Conversation.appending은 messages 끝에 Message가 추가된 새 Conversation을 반환한다")
    func conversationAppendingReturnsNewConversationWithMessage() {
        let original = Conversation.empty(modelId: "claude-opus-4-6")
        let message = Message(
            role: .user,
            content: "첫 메시지",
            createdAt: Date(timeIntervalSince1970: 3_000_000)
        )

        let updated = original.appending(message)

        #expect(original.messages.isEmpty)
        #expect(updated.messages == [message])
        #expect(updated.id == original.id)
        #expect(updated.modelId == original.modelId)
    }

    @Test("Conversation은 id, title, messages, modelId, createdAt을 저장한다")
    func conversationStoresProperties() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 2_000_000)
        let message = Message(role: .user, content: "hi", createdAt: createdAt)
        let conversation = Conversation(
            id: id,
            title: "첫 세션",
            messages: [message],
            modelId: "claude-opus-4-6",
            createdAt: createdAt
        )

        #expect(conversation.id == id)
        #expect(conversation.title == "첫 세션")
        #expect(conversation.messages == [message])
        #expect(conversation.modelId == "claude-opus-4-6")
        #expect(conversation.createdAt == createdAt)
    }
}

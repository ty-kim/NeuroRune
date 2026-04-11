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

struct LLMModelTests {

    @Test("LLMModel은 id, displayName을 저장한다")
    func llmModelStoresProperties() {
        let model = LLMModel(id: "claude-opus-4-6", displayName: "Claude Opus 4.6")

        #expect(model.id == "claude-opus-4-6")
        #expect(model.displayName == "Claude Opus 4.6")
    }

    @Test("LLMModel.allSupported는 opus46, sonnet46, haiku45 3개 상수를 포함한다")
    func llmModelAllSupportedHasThreeModels() {
        let all = LLMModel.allSupported

        #expect(all.count == 3)
        #expect(all.contains(LLMModel.opus46))
        #expect(all.contains(LLMModel.sonnet46))
        #expect(all.contains(LLMModel.haiku45))
    }

    @Test("각 상수의 id는 Anthropic API alias 형식이다")
    func llmModelConstantsUseAnthropicAliases() {
        #expect(LLMModel.opus46.id == "claude-opus-4-6")
        #expect(LLMModel.sonnet46.id == "claude-sonnet-4-6")
        #expect(LLMModel.haiku45.id == "claude-haiku-4-5")
    }
}

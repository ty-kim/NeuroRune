//
//  ConversationStore.swift
//  NeuroRune
//

import Foundation
import SwiftData
import Dependencies

struct ConversationStore: Sendable {
    var save: @Sendable (Conversation) async throws -> Void
    var load: @Sendable (UUID) async throws -> Conversation?
    var loadAll: @Sendable () async throws -> [Conversation]
    var delete: @Sendable (UUID) async throws -> Void
}

extension ConversationStore {

    static func liveBacked(container: ModelContainer) -> ConversationStore {
        ConversationStore(
            save: { conversation in
                let context = ModelContext(container)
                let targetId = conversation.id
                let descriptor = FetchDescriptor<ConversationEntity>(
                    predicate: #Predicate { $0.id == targetId }
                )

                if let existing = try context.fetch(descriptor).first {
                    existing.title = conversation.title
                    existing.modelId = conversation.modelId
                    // replace messages: clear + insert
                    for msg in existing.messages {
                        context.delete(msg)
                    }
                    existing.messages = conversation.messages.map(MessageEntity.from)
                } else {
                    context.insert(ConversationEntity.from(conversation))
                }
                try context.save()
            },
            load: { id in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<ConversationEntity>(
                    predicate: #Predicate { $0.id == id }
                )
                return try context.fetch(descriptor).first?.toDomain()
            },
            loadAll: {
                let context = ModelContext(container)
                var descriptor = FetchDescriptor<ConversationEntity>()
                descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
                let entities = try context.fetch(descriptor)
                return entities.map { $0.toDomain() }
            },
            delete: { id in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<ConversationEntity>(
                    predicate: #Predicate { $0.id == id }
                )
                if let entity = try context.fetch(descriptor).first {
                    context.delete(entity)
                    try context.save()
                }
            }
        )
    }
}

extension ConversationStore: DependencyKey {
    static let liveValue: ConversationStore = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(
                for: ConversationEntity.self, MessageEntity.self,
                configurations: config
            )
            return .liveBacked(container: container)
        } catch {
            // Fallback: Phase 11 통합에서 container 초기화 실패 시 테스트 환경과 동일하게 처리
            return .testValue
        }
    }()

    static let testValue = ConversationStore(
        save: unimplemented("ConversationStore.save"),
        load: unimplemented("ConversationStore.load"),
        loadAll: unimplemented("ConversationStore.loadAll"),
        delete: unimplemented("ConversationStore.delete")
    )
}

extension DependencyValues {
    var conversationStore: ConversationStore {
        get { self[ConversationStore.self] }
        set { self[ConversationStore.self] = newValue }
    }
}

//
//  ConversationStore.swift
//  NeuroRune
//

import Foundation
import SwiftData
import Dependencies

nonisolated struct ConversationStore: Sendable {
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
                if let existing = try fetchEntity(by: conversation.id, in: context) {
                    existing.title = conversation.title
                    existing.modelId = conversation.modelId
                    // replace messages: clear + insert (ordinal로 입력 순서 보존)
                    for msg in existing.messages {
                        context.delete(msg)
                    }
                    existing.messages = conversation.messages.enumerated().map { index, message in
                        MessageEntity.from(message, ordinal: index)
                    }
                } else {
                    context.insert(ConversationEntity.from(conversation))
                }
                try context.save()
            },
            load: { id in
                let context = ModelContext(container)
                return try fetchEntity(by: id, in: context)?.toDomain()
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
                if let entity = try fetchEntity(by: id, in: context) {
                    context.delete(entity)
                    try context.save()
                }
            }
        )
    }
}

private nonisolated func fetchEntity(
    by id: UUID,
    in context: ModelContext
) throws -> ConversationEntity? {
    let descriptor = FetchDescriptor<ConversationEntity>(
        predicate: #Predicate { $0.id == id }
    )
    return try context.fetch(descriptor).first
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
            fatalError("ConversationStore init failed: \(error)")
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

//
//  ConversationStore.swift
//  NeuroRune
//

import Foundation
import SwiftData
import Dependencies
import os

nonisolated struct ConversationStore: Sendable {
    var save: @Sendable (Conversation) async throws -> Void
    var load: @Sendable (UUID) async throws -> Conversation?
    var loadAll: @Sendable () async throws -> [Conversation]
    var delete: @Sendable (UUID) async throws -> Void
}

nonisolated extension ConversationStore {

    static func liveBacked(container: ModelContainer) -> ConversationStore {
        ConversationStore(
            save: { conversation in
                let context = ModelContext(container)
                if let existing = try fetchEntity(by: conversation.id, in: context) {
                    existing.title = conversation.title
                    existing.modelId = conversation.modelId
                    for msg in existing.messages {
                        context.delete(msg)
                    }
                    existing.messages = conversation.messages.enumerated().map { index, message in
                        MessageEntity.from(message, ordinal: index)
                    }
                    Logger.persistence.info("upsert conversation, id: \(conversation.id), messages: \(conversation.messages.count)")
                } else {
                    context.insert(ConversationEntity.from(conversation))
                    Logger.persistence.info("save new conversation, id: \(conversation.id), messages: \(conversation.messages.count)")
                }
                do {
                    try context.save()
                } catch {
                    Logger.persistence.error("save failed, id: \(conversation.id), error: \(error.localizedDescription)")
                    throw error
                }
            },
            load: { id in
                let context = ModelContext(container)
                let entity = try fetchEntity(by: id, in: context)
                if entity != nil {
                    Logger.persistence.info("load hit, id: \(id)")
                } else {
                    Logger.persistence.info("load miss, id: \(id)")
                }
                return try entity.flatMap { try $0.toDomain() }
            },
            loadAll: {
                let context = ModelContext(container)
                var descriptor = FetchDescriptor<ConversationEntity>()
                descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
                let entities = try context.fetch(descriptor)
                Logger.persistence.info("loadAll, count: \(entities.count)")
                return try entities.map { try $0.toDomain() }
            },
            delete: { id in
                let context = ModelContext(container)
                if let entity = try fetchEntity(by: id, in: context) {
                    context.delete(entity)
                    try context.save()
                    Logger.persistence.info("delete conversation, id: \(id)")
                } else {
                    Logger.persistence.info("delete skipped, not found, id: \(id)")
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

nonisolated extension ConversationStore: DependencyKey {
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
    nonisolated var conversationStore: ConversationStore {
        get { self[ConversationStore.self] }
        set { self[ConversationStore.self] = newValue }
    }
}

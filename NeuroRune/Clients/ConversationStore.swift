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
                    existing.thinkingEnabled = conversation.thinkingEnabled
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
            Logger.persistence.info("container init succeeded")
            return .liveBacked(container: container)
        } catch {
            Logger.persistence.fault("container init failed: \(error.localizedDescription); falling back to failing store")
            return .failing
        }
    }()

    /// 모든 연산이 `PersistenceError.containerUnavailable`을 throw하는 store.
    /// 컨테이너 초기화 실패 시 liveValue 자리에 들어간다.
    static let failing = ConversationStore(
        save: { _ in throw PersistenceError.containerUnavailable },
        load: { _ in throw PersistenceError.containerUnavailable },
        loadAll: { throw PersistenceError.containerUnavailable },
        delete: { _ in throw PersistenceError.containerUnavailable }
    )

    /// SwiftData 기본 store 파일을 삭제한다. 앱 재실행 시 fresh 컨테이너 시도.
    /// 사용자 "스토리지 초기화" 플로우에서 호출.
    static func resetDefaultStorage() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            let url = appSupport.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
        }
        Logger.persistence.info("default storage reset; restart app for fresh container")
    }

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

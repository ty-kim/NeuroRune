//
//  UITestConversationStore.swift
//  NeuroRune
//
//  Created by tykim
//

#if DEBUG
import Foundation

extension ConversationStore {
    /// UI 테스트 전용 in-memory ConversationStore.
    /// 앱 기동마다 새 instance → 매번 conversations empty로 시작.
    /// 실제 SwiftData 오염 없이 UI 플로우 검증.
    static let uiTestMock: ConversationStore = {
        let storage = UITestConversationStorage()
        return ConversationStore(
            save: { conversation in
                storage.upsert(conversation)
            },
            load: { id in
                storage.load(id: id)
            },
            loadAll: {
                storage.loadAll()
            },
            delete: { id in
                storage.delete(id: id)
            }
        )
    }()
}

nonisolated private final class UITestConversationStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var dict: [UUID: Conversation] = [:]

    func upsert(_ conversation: Conversation) {
        lock.lock()
        defer { lock.unlock() }
        dict[conversation.id] = conversation
    }

    func load(id: UUID) -> Conversation? {
        lock.lock()
        defer { lock.unlock() }
        return dict[id]
    }

    func loadAll() -> [Conversation] {
        lock.lock()
        defer { lock.unlock() }
        return Array(dict.values).sorted { $0.createdAt > $1.createdAt }
    }

    func delete(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        dict.removeValue(forKey: id)
    }
}
#endif

//
//  WriteApprovalGate.swift
//  NeuroRune
//

import Foundation
import Dependencies

/// Claude의 write_memory 호출에 대한 사용자 승인 채널.
/// .run effect가 `requestApproval`로 await, modal 액션이 `setApproval`로 resume.
nonisolated enum WriteDecision: Equatable, Sendable {
    case approve
    case reject(reason: String?)
}

nonisolated struct WriteApprovalGate: Sendable {
    var requestApproval: @Sendable (_ id: String) async -> WriteDecision
    var setApproval: @Sendable (_ id: String, _ decision: WriteDecision) -> Void
}

/// 내부 store. lock 기반으로 sync/async 양쪽 호출 안전.
private final nonisolated class WriteApprovalStore: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [String: CheckedContinuation<WriteDecision, Never>] = [:]

    func request(_ id: String) async -> WriteDecision {
        await withCheckedContinuation { cont in
            lock.lock()
            continuations[id] = cont
            lock.unlock()
        }
    }

    func set(_ id: String, _ decision: WriteDecision) {
        lock.lock()
        let cont = continuations.removeValue(forKey: id)
        lock.unlock()
        cont?.resume(returning: decision)
    }
}

nonisolated extension WriteApprovalGate: DependencyKey {
    static let liveValue: WriteApprovalGate = {
        let store = WriteApprovalStore()
        return WriteApprovalGate(
            requestApproval: { id in await store.request(id) },
            setApproval: { id, decision in store.set(id, decision) }
        )
    }()

    static let testValue = WriteApprovalGate(
        requestApproval: unimplemented("WriteApprovalGate.requestApproval", placeholder: .reject(reason: nil)),
        setApproval: unimplemented("WriteApprovalGate.setApproval")
    )
}

extension DependencyValues {
    nonisolated var writeApprovalGate: WriteApprovalGate {
        get { self[WriteApprovalGate.self] }
        set { self[WriteApprovalGate.self] = newValue }
    }
}

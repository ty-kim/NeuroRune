//
//  ChatFeature+WriteApproval.swift
//  NeuroRune
//
//  Created by tykim
//
//  write_memory tool approval 관련 action 처리를 main reducer에서 분리.
//  구조적 분할 (behavior 동일). +STT, +Speak 패턴 대칭.
//

import Foundation
import ComposableArchitecture

nonisolated extension ChatFeature {

    /// write approval 관련 action 전담 reducer. main `reduce`에서 위임받음.
    func reduceWriteApproval(into state: inout State, action: Action) -> Effect<Action> {
        @Dependency(\.writeApprovalGate) var writeApprovalGate

        switch action {
        case let .writeApprovalRequested(req):
            state.pendingWrite = req
            return .none

        case let .writeApproved(id):
            state.pendingWrite = nil
            return .run { _ in
                writeApprovalGate.setApproval(id, .approve)
            }

        case let .writeRejected(id, reason):
            state.pendingWrite = nil
            return .run { _ in
                writeApprovalGate.setApproval(id, .reject(reason: reason))
            }

        default:
            return .none
        }
    }
}

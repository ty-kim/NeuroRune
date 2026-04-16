//
//  WriteApprovalGateTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
@testable import NeuroRune

private actor RegistrationProbe {
    private var count = 0
    private var waiters: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func record() {
        count += 1
        var ready: [CheckedContinuation<Void, Never>] = []
        var pending: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in waiters {
            if count >= waiter.target {
                ready.append(waiter.continuation)
            } else {
                pending.append(waiter)
            }
        }
        waiters = pending
        for continuation in ready {
            continuation.resume()
        }
    }

    func waitForCount(_ target: Int) async {
        guard count < target else { return }
        await withCheckedContinuation { continuation in
            waiters.append((target, continuation))
        }
    }
}

struct WriteApprovalGateTests {

    @Test("requestApproval은 setApproval로 set된 결정을 반환한다")
    func requestReturnsSetDecision() async {
        let gate = WriteApprovalGate.live()
        let id = "t1-\(UUID().uuidString)"

        async let decision = gate.requestApproval(id)
        gate.setApproval(id, .approve)

        let result = await decision
        #expect(result == .approve)
    }

    @Test("setApproval이 requestApproval보다 먼저 와도 결정을 반환한다")
    func setBeforeRequestIsDelivered() async {
        let gate = WriteApprovalGate.live()
        let id = "early-\(UUID().uuidString)"

        gate.setApproval(id, .approve)

        let result = await gate.requestApproval(id)
        #expect(result == .approve)
    }

    @Test("서로 다른 id는 독립적으로 결정된다")
    func multipleIdsTrackedIndependently() async {
        let gate = WriteApprovalGate.live()
        let a = "a-\(UUID().uuidString)"
        let b = "b-\(UUID().uuidString)"

        async let d1 = gate.requestApproval(a)
        async let d2 = gate.requestApproval(b)
        gate.setApproval(b, .reject(reason: "user said no"))
        gate.setApproval(a, .approve)

        let r1 = await d1
        let r2 = await d2
        #expect(r1 == .approve)
        #expect(r2 == .reject(reason: "user said no"))
    }

    @Test("Task 취소 시 pending continuation은 reject(cancelled)로 resume")
    func cancellationResumesWithReject() async {
        let id = "cancel-\(UUID().uuidString)"
        let probe = RegistrationProbe()
        let gate = WriteApprovalGate.live(onRequestRegistered: { registeredID in
            guard registeredID == id else { return }
            Task { await probe.record() }
        })

        let task = Task { await gate.requestApproval(id) }
        await probe.waitForCount(1)
        task.cancel()

        let result = await task.value
        #expect(result == .reject(reason: "cancelled"))
    }

    @Test("같은 id 중복 request 시 기존 것은 superseded로 reject")
    func duplicateIdSupersedes() async {
        let id = "dup-\(UUID().uuidString)"
        let probe = RegistrationProbe()
        let gate = WriteApprovalGate.live(onRequestRegistered: { registeredID in
            guard registeredID == id else { return }
            Task { await probe.record() }
        })

        let first = Task { await gate.requestApproval(id) }
        await probe.waitForCount(1)
        let second = Task { await gate.requestApproval(id) }
        await probe.waitForCount(2)
        gate.setApproval(id, .approve)

        let firstResult = await first.value
        let secondResult = await second.value
        #expect(firstResult == .reject(reason: "superseded"))
        #expect(secondResult == .approve)
    }
}

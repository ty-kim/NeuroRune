//
//  WriteApprovalGateTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
@testable import NeuroRune

struct WriteApprovalGateTests {

    @Test("requestApproval은 setApproval로 set된 결정을 반환한다")
    func requestReturnsSetDecision() async {
        let gate = WriteApprovalGate.liveValue

        async let decision = gate.requestApproval("t1")
        // request가 continuation 등록할 시간 확보
        try? await Task.sleep(nanoseconds: 50_000_000)
        gate.setApproval("t1", .approve)

        let result = await decision
        #expect(result == .approve)
    }

    @Test("서로 다른 id는 독립적으로 결정된다")
    func multipleIdsTrackedIndependently() async {
        let gate = WriteApprovalGate.liveValue

        async let d1 = gate.requestApproval("a")
        async let d2 = gate.requestApproval("b")
        try? await Task.sleep(nanoseconds: 50_000_000)
        gate.setApproval("b", .reject(reason: "user said no"))
        gate.setApproval("a", .approve)

        let r1 = await d1
        let r2 = await d2
        #expect(r1 == .approve)
        #expect(r2 == .reject(reason: "user said no"))
    }
}

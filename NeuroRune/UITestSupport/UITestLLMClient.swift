//
//  UITestLLMClient.swift
//  NeuroRune
//
//  Created by tykim
//

#if DEBUG
import Foundation

extension LLMClient {
    /// UI 테스트 전용 스트리밍 stub.
    /// `--ui-test-mock-llm` 플래그로 활성화.
    /// 즉시 고정 delta 2개 yield + finish. wall-clock 대기 없음.
    static let uiTestMock = LLMClient(
        streamMessage: { _, _, _, _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.textDelta("hi"))
                continuation.yield(.textDelta(" there"))
                continuation.finish()
            }
        }
    )

    /// UI 테스트 전용 write_memory tool_use 시나리오 stub.
    /// `--ui-test-mock-llm-tool-use` 플래그로 활성화.
    /// 첫 호출: write_memory tool_use 요청 emit (모달 노출 유도).
    /// 두 번째 호출 이후: textDelta "saved" emit (tool_result 수신 후 assistant 응답).
    static let uiTestToolUseMock: LLMClient = {
        let counter = UITestCallCounter()
        return LLMClient(
            streamMessage: { _, _, _, _, _ in
                let callIndex = counter.next()
                return AsyncThrowingStream { continuation in
                    if callIndex == 0 {
                        let inputJSON = #"{"role":"local","path":"memory/ui_test.md","content":"hello","commit_message":"UI test"}"#
                        continuation.yield(.toolUseRequest(
                            id: "tu_uitest_0",
                            name: "write_memory",
                            inputJSON: inputJSON
                        ))
                    } else {
                        continuation.yield(.textDelta("saved"))
                    }
                    continuation.finish()
                }
            }
        )
    }()
}

nonisolated private final class UITestCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let current = count
        count += 1
        return current
    }
}
#endif

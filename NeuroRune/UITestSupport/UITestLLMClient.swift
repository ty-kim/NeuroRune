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
}
#endif

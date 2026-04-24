//
//  UITestSTTClient.swift
//  NeuroRune
//
//  Created by tykim
//

#if DEBUG
import Foundation

extension STTClient {
    /// UI 테스트 전용 STT stub.
    /// `--ui-test-mock-stt` 플래그로 활성화.
    /// 실제 audio 무시하고 고정 텍스트 반환.
    static let uiTestMock = STTClient(
        transcribe: { _, _ in
            STTResult(text: "voice input")
        }
    )
}
#endif

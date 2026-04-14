//
//  STTClient.swift
//  NeuroRune
//
//  Phase 21 — Speech-to-Text 변환 프로토콜.
//  오디오 바이트(현재 WAV 16kHz mono 16-bit 권장)를 받아 텍스트 결과 반환.
//  구현체(`liveValue`)는 다음 세션에서 Clova CSR 연결.
//

import Foundation
import Dependencies

nonisolated struct STTClient: Sendable {
    /// 오디오 바이트와 언어 코드(Clova 기준: "Kor", "Eng", "Jpn", "Chn")를 받아 전사 결과 반환.
    /// 실패 시 `STTError` 계열 throw.
    var transcribe: @Sendable (_ audio: Data, _ language: String) async throws -> STTResult
}

nonisolated extension STTClient: DependencyKey {
    static let liveValue = STTClient(
        transcribe: unimplemented("STTClient.liveValue not connected yet — Clova CSR 다음 세션")
    )

    static let testValue = STTClient(
        transcribe: unimplemented("STTClient.transcribe")
    )

    static let previewValue = STTClient(
        transcribe: { _, _ in
            STTResult(text: "안녕하세요 미리보기 전사 텍스트입니다")
        }
    )
}

extension DependencyValues {
    nonisolated var sttClient: STTClient {
        get { self[STTClient.self] }
        set { self[STTClient.self] = newValue }
    }
}

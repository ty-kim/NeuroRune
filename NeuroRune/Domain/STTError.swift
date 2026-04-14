//
//  STTError.swift
//  NeuroRune
//
//  Phase 21 — STT 파이프라인 에러.
//  녹음(마이크 권한·AVAudioEngine)과 전사(Clova CSR 네트워크) 단계를 모두 포함.
//

import Foundation

nonisolated enum STTError: Error, Equatable, Sendable {
    /// 마이크 권한 거부.
    case microphonePermissionDenied
    /// AVAudioEngine 등 로컬 녹음 실패. detail은 로그용.
    case recordingFailed(String)
    /// 60초 초과. Clova CSR short sentence 한도.
    case audioTooLong
    /// 네트워크 연결·타임아웃.
    case network(String)
    /// 401 — NCP 키 불일치 또는 구독 미활성화.
    case unauthorized
    /// 429 — 쿼터 초과.
    case rateLimited
    /// 4xx/5xx 기타. status는 HTTP 코드.
    case server(status: Int, message: String)
    /// JSON 디코딩 실패.
    case decoding(String)
    /// 사용자 또는 시스템 취소.
    case cancelled
}

extension STTError {
    /// 사용자 노출용 현지화 키.
    var userMessageKey: String {
        switch self {
        case .microphonePermissionDenied: return "stt.error.mic_permission"
        case .recordingFailed:            return "stt.error.recording"
        case .audioTooLong:               return "stt.error.audio_too_long"
        case .network:                    return "stt.error.network"
        case .unauthorized:               return "stt.error.unauthorized"
        case .rateLimited:                return "stt.error.rate_limited"
        case .server:                     return "stt.error.server"
        case .decoding:                   return "stt.error.decoding"
        case .cancelled:                  return "stt.error.cancelled"
        }
    }

    /// 재시도가 의미 있는 에러인지.
    /// - 권한 거부·오디오 길이 초과·취소는 재시도 무의미.
    /// - 나머지는 네트워크·서버 일시 장애 가능성 있음.
    var isRetryable: Bool {
        switch self {
        case .microphonePermissionDenied, .audioTooLong, .cancelled:
            return false
        case .recordingFailed, .network, .unauthorized, .rateLimited, .server, .decoding:
            return true
        }
    }
}

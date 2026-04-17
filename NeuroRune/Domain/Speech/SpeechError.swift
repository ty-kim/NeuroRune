//
//  SpeechError.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — TTS 파이프라인 에러. 합성(네트워크)과 재생(AVAudioPlayer) 단계를 모두 포함.
//

import Foundation

nonisolated enum SpeechError: Error, Equatable, Sendable {
    /// 401 — API 키 불일치 또는 만료.
    case unauthorized
    /// 429 — 쿼터 초과.
    case rateLimited
    /// 4xx/5xx 기타. status는 HTTP 코드.
    case server(status: Int, message: String)
    /// 네트워크 연결·타임아웃.
    case network(String)
    /// 응답 바디가 비었거나 오디오로 해석 불가.
    case decoding(String)
    /// AVAudioPlayer 재생 실패.
    case playbackFailed(String)
    /// 사용자 또는 시스템 취소.
    case cancelled
    /// 텍스트가 TTS 예산(SpeechBudget.maxTotalCharsPerResponse)을 초과.
    case tooLong
    /// voice_id에 접근 불가 (플랜 다운그레이드로 PVC 권한 없음 등).
    case voiceUnavailable
}

extension SpeechError {
    var userMessageKey: String {
        switch self {
        case .unauthorized:    return "speech.error.unauthorized"
        case .rateLimited:     return "speech.error.rate_limited"
        case .server:          return "speech.error.server"
        case .network:         return "speech.error.network"
        case .decoding:        return "speech.error.decoding"
        case .playbackFailed:  return "speech.error.playback"
        case .cancelled:       return "speech.error.cancelled"
        case .tooLong:         return "speech.error.tooLong"
        case .voiceUnavailable: return "speech.error.voiceUnavailable"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .cancelled, .tooLong, .voiceUnavailable: return false
        default:                                      return true
        }
    }
}

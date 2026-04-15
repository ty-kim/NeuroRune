//
//  LLMError.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation

nonisolated enum LLMError: Error, Equatable, Sendable {
    case unauthorized
    /// 429 Too Many Requests. retryAfter는 `retry-after` 헤더 값(초), state는 응답 헤더의 쿼터 정보.
    /// 둘 다 없을 수 있다 (헤더 누락).
    case rateLimited(retryAfter: TimeInterval?, state: RateLimitState?)
    case network(String)
    case decoding(String)
    case server(status: Int, message: String)
    /// 사용자나 시스템에 의한 작업 취소. UI는 보통 조용히 무시.
    case cancelled
}

extension LLMError {
    var userMessage: String {
        switch self {
        case .unauthorized:
            String(localized: "error.unauthorized")
        case .rateLimited:
            String(localized: "error.rateLimited")
        case let .network(detail):
            String(localized: "error.network") + ": " + detail
        case let .decoding(detail):
            String(localized: "error.decoding") + ": " + detail
        case let .server(_, message):
            message
        case .cancelled:
            String(localized: "error.cancelled")
        }
    }

    /// 사용자가 "재시도" 버튼을 눌러 다시 시도할 가치가 있는 에러인지.
    /// - `.cancelled`만 false. 나머지는 모두 재시도 UI 노출.
    var isRetryable: Bool {
        switch self {
        case .cancelled:
            return false
        case .unauthorized, .rateLimited, .network, .decoding, .server:
            return true
        }
    }
}

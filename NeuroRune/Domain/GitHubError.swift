//
//  GitHubError.swift
//  NeuroRune
//

import Foundation

nonisolated enum GitHubError: Error, Equatable {
    case unauthorized
    case notFound
    case rateLimited
    case conflict // sha mismatch 등 422
    case network(String)
    case decoding(String)
    case server(status: Int, message: String)
    /// GitHub Contents API가 base64가 아닌 인코딩 반환 (예: 1MB 초과 시 "none").
    case unsupportedEncoding(String)
    /// Base64 디코딩 실패.
    case invalidBase64

    /// 사용자에게 노출할 로컬라이즈 메시지.
    /// 여러 Feature에서 동일 switch가 반복되던 것을 한 군데로 통합.
    var localizedMessage: String {
        switch self {
        case .unauthorized: return String(localized: "memory.error.unauthorized")
        case .notFound: return String(localized: "memory.error.notFound")
        case .rateLimited: return String(localized: "memory.error.rateLimited")
        case .conflict: return String(localized: "memory.error.conflict")
        case let .server(_, message): return message
        case let .network(message): return message
        case let .decoding(message): return message
        case let .unsupportedEncoding(encoding): return String(localized: "memory.error.unsupportedEncoding") + " (\(encoding))"
        case .invalidBase64: return String(localized: "memory.error.invalidBase64")
        }
    }
}

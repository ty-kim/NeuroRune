//
//  LLMError.swift
//  NeuroRune
//

import Foundation

nonisolated enum LLMError: Error, Equatable, Sendable {
    case unauthorized
    case rateLimited
    case network(String)
    case decoding(String)
    case server(status: Int, message: String)
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
        }
    }
}

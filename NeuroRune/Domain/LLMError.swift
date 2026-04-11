//
//  LLMError.swift
//  NeuroRune
//

nonisolated enum LLMError: Error, Equatable, Sendable {
    case unauthorized
    case rateLimited
    case network(String)
    case decoding(String)
    case server(status: Int)
}

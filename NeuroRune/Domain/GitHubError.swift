//
//  GitHubError.swift
//  NeuroRune
//

nonisolated enum GitHubError: Error, Equatable {
    case unauthorized
    case notFound
    case rateLimited
    case conflict // sha mismatch 등 422
    case network(String)
    case decoding(String)
    case server(status: Int, message: String)
}

//
//  KeychainClient.swift
//  NeuroRune
//

import Foundation

protocol KeychainClient: Sendable {
    nonisolated func save(key: String, value: String) throws
    nonisolated func load(key: String) throws -> String?
    nonisolated func delete(key: String) throws
}

nonisolated enum KeychainError: Error, Equatable {
    case unhandled(status: OSStatus)
    case decodingFailed
}

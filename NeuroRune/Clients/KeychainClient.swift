//
//  KeychainClient.swift
//  NeuroRune
//

import Foundation

protocol KeychainClient: Sendable {
    func save(key: String, value: String) throws
    func load(key: String) throws -> String?
    func delete(key: String) throws
}

enum KeychainError: Error, Equatable {
    case unhandled(status: OSStatus)
    case decodingFailed
}

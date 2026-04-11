//
//  Message.swift
//  NeuroRune
//

import Foundation

nonisolated struct Message: Equatable, Sendable {
    nonisolated enum Role: String, Equatable, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
    let createdAt: Date
}

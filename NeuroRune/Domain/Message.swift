//
//  Message.swift
//  NeuroRune
//

import Foundation

struct Message: Equatable, Sendable {
    enum Role: String, Equatable, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
    let createdAt: Date
}

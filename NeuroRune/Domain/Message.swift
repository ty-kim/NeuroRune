//
//  Message.swift
//  NeuroRune
//
//  Created by tykim
//

import Foundation

nonisolated struct Message: Equatable, Sendable {
    enum Role: String, Equatable, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
    let createdAt: Date
}

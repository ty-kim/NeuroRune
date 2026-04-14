//
//  Log.swift
//  NeuroRune
//
//  Created by tykim
//

import os

nonisolated extension Logger {
    private static let subsystem = "com.neurorune"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    static let llm = Logger(subsystem: subsystem, category: "llm")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}

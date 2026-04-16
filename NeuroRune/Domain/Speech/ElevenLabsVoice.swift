//
//  ElevenLabsVoice.swift
//  NeuroRune
//
//  Created by tykim
//
//  GET /v1/voices 항목. voice_id + name + 선택 메타(labels/preview_url).
//

import Foundation

nonisolated struct ElevenLabsVoice: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let previewUrl: String?
    let labels: [String: String]?
}

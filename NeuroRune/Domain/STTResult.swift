//
//  STTResult.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — Clova CSR STT 결과 도메인 객체.
//

import Foundation

/// Speech-to-Text 변환 결과.
/// 현재는 전사 텍스트만. 향후 confidence·language 추가 여지.
nonisolated struct STTResult: Equatable, Sendable {
    /// 전사된 텍스트.
    let text: String

    init(text: String) {
        self.text = text
    }
}

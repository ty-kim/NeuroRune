//
//  AzureCredentials.swift
//  NeuroRune
//
//  Created by tykim
//
//  Azure Speech Service (Cognitive Services) 자격 증명.
//  key + region 쌍. region은 엔드포인트 URL 구성에 쓰임.
//

import Foundation

nonisolated struct AzureCredentials: Equatable, Sendable {
    /// `Ocp-Apim-Subscription-Key` 헤더 값.
    let apiKey: String
    /// Azure region (e.g. `koreacentral`, `eastus`).
    /// 엔드포인트: `https://{region}.tts.speech.microsoft.com/...`
    let region: String

    init(apiKey: String, region: String) {
        self.apiKey = apiKey
        self.region = region
    }

    var isValid: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

nonisolated extension AzureCredentials {
    /// Keychain 저장 키. 변경 시 기존 사용자 데이터 마이그레이션 고려.
    nonisolated enum KeychainKey {
        nonisolated static let apiKey = "azure.apiKey"
        nonisolated static let region = "azure.region"
    }
}

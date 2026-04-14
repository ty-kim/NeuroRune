//
//  NCPCredentials.swift
//  NeuroRune
//
//  Naver Cloud Platform API Gateway 인증 키 쌍.
//  하나의 키 쌍으로 Clova CSR·Voice·OCR 등 여러 NCP AI 서비스에 공통 사용.
//  서비스별 구독(Subscription)은 NCP 콘솔에서 별도 활성화 필요.
//

import Foundation

nonisolated struct NCPCredentials: Equatable, Sendable {
    /// `X-NCP-APIGW-API-KEY-ID` 헤더값.
    let apiKeyID: String
    /// `X-NCP-APIGW-API-KEY` 헤더값.
    let apiKey: String

    init(apiKeyID: String, apiKey: String) {
        self.apiKeyID = apiKeyID
        self.apiKey = apiKey
    }

    /// 두 값 모두 비어있지 않은지. Keychain에서 로드 후 유효성 체크용.
    var isValid: Bool {
        !apiKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

nonisolated extension NCPCredentials {
    /// Keychain 저장 시 사용할 키 이름. 변경 시 사용자 데이터 마이그레이션 고려 필요.
    nonisolated enum KeychainKey {
        nonisolated static let apiKeyID = "ncp.apiKeyID"
        nonisolated static let apiKey = "ncp.apiKey"
    }
}

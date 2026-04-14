//
//  STTClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — Speech-to-Text 변환 프로토콜.
//  오디오 바이트(현재 WAV 16kHz mono 16-bit 권장)를 받아 텍스트 결과 반환.
//  구현체(`liveValue`)는 다음 세션에서 Clova CSR 연결.
//

import Foundation
import Dependencies
import os

nonisolated struct STTClient: Sendable {
    /// 오디오 바이트와 언어 코드(Clova 기준: "Kor", "Eng", "Jpn", "Chn")를 받아 전사 결과 반환.
    /// 실패 시 `STTError` 계열 throw.
    var transcribe: @Sendable (_ audio: Data, _ language: String) async throws -> STTResult
}

// MARK: - Clova CSR 구현

nonisolated extension STTClient {

    /// Clova CSR(Short Sentence) REST API 기반 구현.
    /// - session: 테스트 시 `URLProtocolStub`을 탑재한 세션 주입
    /// - credentials: NCP API Gateway 키 쌍
    static func clovaCSR(session: URLSession, credentials: NCPCredentials) -> STTClient {
        STTClient(
            transcribe: { audio, language in
                let request = try buildCSRRequest(
                    audio: audio,
                    language: language,
                    credentials: credentials
                )

                let data: Data
                let response: URLResponse
                do {
                    (data, response) = try await session.data(for: request)
                } catch let urlError as URLError where urlError.code == .cancelled {
                    throw STTError.cancelled
                } catch let urlError as URLError {
                    throw STTError.network(urlError.localizedDescription)
                } catch {
                    throw STTError.network(error.localizedDescription)
                }

                guard let http = response as? HTTPURLResponse else {
                    throw STTError.network("non-http response")
                }

                return try handle(status: http.statusCode, body: data)
            }
        )
    }

    /// Clova CSR 엔드포인트.
    /// 공식: `https://naveropenapi.apigw.ntruss.com/recog/v1/stt?lang={lang}`
    static func buildCSRRequest(
        audio: Data,
        language: String,
        credentials: NCPCredentials
    ) throws -> URLRequest {
        guard var components = URLComponents(string: "https://naveropenapi.apigw.ntruss.com/recog/v1/stt") else {
            throw STTError.network("invalid CSR endpoint URL")
        }
        components.queryItems = [URLQueryItem(name: "lang", value: language)]
        guard let url = components.url else {
            throw STTError.network("failed to construct CSR URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiKeyID, forHTTPHeaderField: "X-NCP-APIGW-API-KEY-ID")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-NCP-APIGW-API-KEY")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audio
        return request
    }

    /// HTTP 상태 + 응답 본문을 STTResult / STTError로 매핑.
    static func handle(status: Int, body: Data) throws -> STTResult {
        switch status {
        case 200..<300:
            return try decodeCSRResponse(body)
        case 401:
            throw STTError.unauthorized
        case 429:
            throw STTError.rateLimited
        default:
            let message = extractMessage(from: body) ?? "CSR request failed"
            throw STTError.server(status: status, message: message)
        }
    }

    /// Clova CSR 응답 JSON: `{ "text": "안녕" }` 형태.
    static func decodeCSRResponse(_ data: Data) throws -> STTResult {
        struct CSRResponse: Decodable {
            let text: String
        }
        do {
            let decoded = try JSONDecoder().decode(CSRResponse.self, from: data)
            return STTResult(text: decoded.text)
        } catch {
            throw STTError.decoding(error.localizedDescription)
        }
    }

    /// 서버 에러 응답 JSON에서 메시지 추출 시도. 실패 시 nil.
    static func extractMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            let error: ErrorBody?
            let errorMessage: String?
            struct ErrorBody: Decodable {
                let message: String?
            }
        }
        if let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return env.error?.message ?? env.errorMessage
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Dependency

nonisolated extension STTClient: DependencyKey {
    static let liveValue: STTClient = {
        STTClient(
            transcribe: { audio, language in
                guard let credentials = try NCPCredentialsClient.liveValue.load() else {
                    Logger.network.error("STT transcribe: NCP credentials missing")
                    throw STTError.unauthorized
                }
                let client = STTClient.clovaCSR(session: .shared, credentials: credentials)
                return try await client.transcribe(audio, language)
            }
        )
    }()

    static let testValue = STTClient(
        transcribe: unimplemented("STTClient.transcribe")
    )

    static let previewValue = STTClient(
        transcribe: { _, _ in
            STTResult(text: "안녕하세요 미리보기 전사 텍스트입니다")
        }
    )
}

extension DependencyValues {
    nonisolated var sttClient: STTClient {
        get { self[STTClient.self] }
        set { self[STTClient.self] = newValue }
    }
}

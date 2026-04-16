//
//  STTClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 21 — Speech-to-Text 변환.
//  오디오 바이트(WAV 16kHz mono 16-bit 권장)를 받아 텍스트 결과 반환.
//  liveValue는 Groq Whisper API(whisper-large-v3) 사용.
//

import Foundation
import Dependencies
import os

nonisolated struct STTClient: Sendable {
    /// 오디오 바이트와 ISO-639-1 언어 코드("ko", "en", "ja", "zh")를 받아 전사 결과 반환.
    /// 실패 시 `STTError` 계열 throw.
    var transcribe: @Sendable (_ audio: Data, _ language: String) async throws -> STTResult
}

// MARK: - Groq Whisper 구현

nonisolated extension STTClient {

    /// Groq Whisper API 기반 구현.
    /// - session: 테스트 시 `URLProtocolStub`을 탑재한 세션 주입
    /// - credentials: Groq API 키 (Bearer)
    static func groqWhisper(session: URLSession, credentials: GroqCredentials) -> STTClient {
        STTClient(
            transcribe: { audio, language in
                let request = try buildGroqRequest(
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

    /// Groq Whisper 엔드포인트. OpenAI 호환 API.
    /// `https://api.groq.com/openai/v1/audio/transcriptions`
    static func buildGroqRequest(
        audio: Data,
        language: String,
        credentials: GroqCredentials
    ) throws -> URLRequest {
        guard let url = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions") else {
            throw STTError.network("invalid Groq endpoint URL")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(
            boundary: boundary,
            audio: audio,
            language: language
        )
        return request
    }

    /// multipart/form-data 구성: file(audio/wav) + model + language + response_format.
    static func buildMultipartBody(boundary: String, audio: Data, language: String) -> Data {
        var body = Data()
        let crlf = "\r\n"

        func appendField(name: String, value: String) {
            body.append(Data("--\(boundary)\(crlf)".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".utf8))
            body.append(Data("\(value)\(crlf)".utf8))
        }

        // file
        body.append(Data("--\(boundary)\(crlf)".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\(crlf)".utf8))
        body.append(Data("Content-Type: audio/wav\(crlf)\(crlf)".utf8))
        body.append(audio)
        body.append(Data(crlf.utf8))

        appendField(name: "model", value: "whisper-large-v3")
        appendField(name: "language", value: language)
        appendField(name: "response_format", value: "json")

        body.append(Data("--\(boundary)--\(crlf)".utf8))
        return body
    }

    /// HTTP 상태 + 응답 본문을 STTResult / STTError로 매핑.
    static func handle(status: Int, body: Data) throws -> STTResult {
        switch status {
        case 200..<300:
            return try decodeGroqResponse(body)
        case 401:
            throw STTError.unauthorized
        case 429:
            throw STTError.rateLimited
        default:
            let message = extractMessage(from: body) ?? "Groq request failed"
            throw STTError.server(status: status, message: message)
        }
    }

    /// Groq Whisper 응답 JSON: `{ "text": "..." }`.
    static func decodeGroqResponse(_ data: Data) throws -> STTResult {
        struct GroqResponse: Decodable {
            let text: String
        }
        do {
            let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
            return STTResult(text: decoded.text)
        } catch {
            throw STTError.decoding(error.localizedDescription)
        }
    }

    /// OpenAI 호환 에러 응답: `{ "error": { "message": "..." } }`.
    static func extractMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            let error: ErrorBody?
            struct ErrorBody: Decodable {
                let message: String?
            }
        }
        if let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return env.error?.message
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Dependency

nonisolated extension STTClient: DependencyKey {
    static let liveValue: STTClient = {
        STTClient(
            transcribe: { audio, language in
                guard let credentials = try GroqCredentialsClient.liveValue.load() else {
                    Logger.network.error("STT transcribe: Groq credentials missing")
                    throw STTError.unauthorized
                }
                let client = STTClient.groqWhisper(session: .shared, credentials: credentials)
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

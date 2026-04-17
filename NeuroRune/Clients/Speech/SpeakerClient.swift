//
//  SpeakerClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs Text-to-Speech 변환. 텍스트·voice·voice_settings를 받아 MP3 Data 반환.
//

import Foundation
import Dependencies
import os

nonisolated struct SpeakerClient: Sendable {
    /// 텍스트를 합성해 MP3 바이너리 반환 (ElevenLabs).
    /// - voiceId: ElevenLabs voice_id
    /// - languageCode: ISO 639-1 (예: "ko", "en"). nil이면 모델 자동 판별.
    /// - settings: voice_settings (stability/similarity/style/speakerBoost)
    var synthesize: @Sendable (
        _ text: String,
        _ voiceId: String,
        _ languageCode: String?,
        _ settings: ElevenLabsVoiceSettings
    ) async throws -> Data
}

// MARK: - ElevenLabs

nonisolated extension SpeakerClient {

    static let elevenLabsOutputFormat = "mp3_44100_128"

    /// ElevenLabs POST /v1/text-to-speech/{voice_id} 요청 빌더.
    /// voiceId는 비어있을 수 없음. languageCode는 ISO 639-1 (선택).
    static func buildElevenLabsRequest(
        text: String,
        voiceId: String,
        modelId: String,
        languageCode: String?,
        settings: ElevenLabsVoiceSettings,
        credentials: ElevenLabsCredentials
    ) throws -> URLRequest {
        let trimmedVoiceId = voiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVoiceId.isEmpty else {
            throw SpeechError.network("empty voiceId")
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.elevenlabs.io"
        components.path = "/v1/text-to-speech/\(trimmedVoiceId)"
        components.queryItems = [URLQueryItem(name: "output_format", value: elevenLabsOutputFormat)]
        guard let url = components.url else {
            throw SpeechError.network("invalid ElevenLabs endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("NeuroRune", forHTTPHeaderField: "User-Agent")

        var body: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "voice_settings": [
                "stability": settings.stability,
                "similarity_boost": settings.similarityBoost,
                "style": settings.style,
                "use_speaker_boost": settings.useSpeakerBoost
            ]
        ]
        if let languageCode {
            body["language_code"] = languageCode
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// ElevenLabs 실제 호출. buildElevenLabsRequest + URLSession.data + handleElevenLabs.
    /// Slice 6에서 SpeakerClient.synthesize 클로저에 연결 예정. 현재는 독립 함수.
    static func elevenLabs(
        session: URLSession,
        text: String,
        voiceId: String,
        modelId: String,
        languageCode: String?,
        settings: ElevenLabsVoiceSettings,
        credentials: ElevenLabsCredentials
    ) async throws -> Data {
        let request = try buildElevenLabsRequest(
            text: text,
            voiceId: voiceId,
            modelId: modelId,
            languageCode: languageCode,
            settings: settings,
            credentials: credentials
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw SpeechError.cancelled
        } catch let urlError as URLError {
            throw SpeechError.network(urlError.localizedDescription)
        } catch {
            throw SpeechError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SpeechError.network("non-http response")
        }

        return try handleElevenLabs(status: http.statusCode, body: data)
    }

    /// ElevenLabs 응답 status → SpeechError 매핑.
    /// - 422: voiceUnavailable (PVC 플랜 제한, 잘못된 voice_id 등)
    /// - 401/429/5xx: 기존 매핑 재사용
    static func handleElevenLabs(status: Int, body: Data) throws -> Data {
        switch status {
        case 200..<300:
            guard !body.isEmpty else {
                throw SpeechError.decoding("empty audio body")
            }
            return body
        case 401:
            throw SpeechError.unauthorized
        case 422:
            throw SpeechError.voiceUnavailable
        case 429:
            throw SpeechError.rateLimited
        default:
            let message = String(data: body, encoding: .utf8) ?? "ElevenLabs request failed"
            throw SpeechError.server(status: status, message: message)
        }
    }
}

// MARK: - Dependency

nonisolated extension SpeakerClient: DependencyKey {
    static let liveValue: SpeakerClient = {
        SpeakerClient(
            synthesize: { text, voiceId, languageCode, settings in
                guard let credentials = try ElevenLabsCredentialsClient.liveValue.load() else {
                    Logger.network.error("SpeakerClient synthesize: ElevenLabs credentials missing")
                    throw SpeechError.unauthorized
                }
                return try await SpeakerClient.elevenLabs(
                    session: .shared,
                    text: text,
                    voiceId: voiceId,
                    modelId: SpeakerClient.elevenLabsDefaultModelId,
                    languageCode: languageCode,
                    settings: settings,
                    credentials: credentials
                )
            }
        )
    }()

    static let testValue = SpeakerClient(
        synthesize: unimplemented("SpeakerClient.synthesize", placeholder: Data())
    )

    static let previewValue = SpeakerClient(
        synthesize: { _, _, _, _ in Data(count: 1024) }
    )

    /// ElevenLabs 기본 모델 ID. curl 테스트로 확정 (Eleven v3).
    static let elevenLabsDefaultModelId = "eleven_v3"
}

extension DependencyValues {
    nonisolated var speakerClient: SpeakerClient {
        get { self[SpeakerClient.self] }
        set { self[SpeakerClient.self] = newValue }
    }
}

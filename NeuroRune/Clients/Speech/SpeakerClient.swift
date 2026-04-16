//
//  SpeakerClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  Phase 22 — Text-to-Speech 변환.
//  텍스트·voice·언어·속도·피치를 받아 MP3 바이너리 반환.
//  liveValue는 Azure Neural TTS(audio-16khz-32kbitrate-mono-mp3) 사용.
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

// MARK: - Azure Neural 구현 (Slice 9에서 제거 예정)

nonisolated extension SpeakerClient {

    /// Azure 레거시. Slice 6에서 synthesize closure는 ElevenLabs 전용으로 전환.
    /// Azure 관련 request/SSML 빌더는 유지(테스트용), 호출 경로는 제거 대기.
    static func azureNeural(session: URLSession, credentials: AzureCredentials) -> SpeakerClient {
        SpeakerClient(
            synthesize: { _, _, _, _ in
                throw SpeechError.network("Azure deprecated; use ElevenLabs")
            }
        )
    }

    /// Azure region 검증: 소문자/숫자/하이픈만. URL 조작 문자(점, 슬래시, @ 등) 차단.
    static func isValidRegion(_ region: String) -> Bool {
        guard !region.isEmpty else { return false }
        return region.allSatisfy { c in
            c.isLowercase && c.isLetter
                || c.isNumber
                || c == "-"
        }
    }

    static func buildAzureRequest(
        text: String,
        voice: String,
        language: String,
        rate: Double,
        pitch: Double,
        credentials: AzureCredentials
    ) throws -> URLRequest {
        let region = credentials.region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidRegion(region) else {
            throw SpeechError.network("invalid Azure region format")
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(region).tts.speech.microsoft.com"
        components.path = "/cognitiveservices/v1"
        guard let url = components.url else {
            throw SpeechError.network("invalid Azure endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("audio-16khz-32kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.setValue("NeuroRune", forHTTPHeaderField: "User-Agent")
        request.httpBody = buildSSML(
            text: text,
            voice: voice,
            language: language,
            rate: rate,
            pitch: pitch
        ).data(using: .utf8)
        return request
    }

    /// SSML 빌더. text/voice/language는 XML 이스케이프.
    static func buildSSML(
        text: String,
        voice: String,
        language: String,
        rate: Double,
        pitch: Double
    ) -> String {
        let pitchPercent = Int((pitch - 1.0) * 100)
        let pitchStr = pitchPercent >= 0 ? "+\(pitchPercent)%" : "\(pitchPercent)%"
        let rateStr = String(format: "%.2f", rate)
        // swiftlint:disable:next line_length
        return "<speak version=\"1.0\" xml:lang=\"\(xmlEscape(language))\"><voice name=\"\(xmlEscape(voice))\"><prosody rate=\"\(rateStr)\" pitch=\"\(pitchStr)\">\(xmlEscape(text))</prosody></voice></speak>"
    }

    /// XML 특수문자 이스케이프.
    static func xmlEscape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func handle(status: Int, body: Data) throws -> Data {
        switch status {
        case 200..<300:
            guard !body.isEmpty else {
                throw SpeechError.decoding("empty audio body")
            }
            return body
        case 401:
            throw SpeechError.unauthorized
        case 429:
            throw SpeechError.rateLimited
        default:
            let message = String(data: body, encoding: .utf8) ?? "Azure request failed"
            throw SpeechError.server(status: status, message: message)
        }
    }

    // MARK: - ElevenLabs

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

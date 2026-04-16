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
    /// 텍스트를 합성해 MP3 바이너리 반환.
    /// - voice: Azure voice 이름 (e.g. `ko-KR-SunHiNeural`)
    /// - language: BCP-47 (e.g. `ko-KR`, `en-US`)
    /// - rate: 0.5~1.5 (1.0이 기본)
    /// - pitch: 0.5~1.5 (1.0이 기본 = ±0%)
    var synthesize: @Sendable (
        _ text: String,
        _ voice: String,
        _ language: String,
        _ rate: Double,
        _ pitch: Double
    ) async throws -> Data
}

// MARK: - Azure Neural 구현

nonisolated extension SpeakerClient {

    static func azureNeural(session: URLSession, credentials: AzureCredentials) -> SpeakerClient {
        SpeakerClient(
            synthesize: { text, voice, language, rate, pitch in
                let request = try buildAzureRequest(
                    text: text,
                    voice: voice,
                    language: language,
                    rate: rate,
                    pitch: pitch,
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

                return try handle(status: http.statusCode, body: data)
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
}

// MARK: - Dependency

nonisolated extension SpeakerClient: DependencyKey {
    static let liveValue: SpeakerClient = {
        SpeakerClient(
            synthesize: { text, voice, language, rate, pitch in
                guard let credentials = try AzureCredentialsClient.liveValue.load() else {
                    Logger.network.error("SpeakerClient synthesize: Azure credentials missing")
                    throw SpeechError.unauthorized
                }
                let client = SpeakerClient.azureNeural(session: .shared, credentials: credentials)
                return try await client.synthesize(text, voice, language, rate, pitch)
            }
        )
    }()

    static let testValue = SpeakerClient(
        synthesize: unimplemented("SpeakerClient.synthesize", placeholder: Data())
    )

    static let previewValue = SpeakerClient(
        synthesize: { _, _, _, _, _ in Data(count: 1024) }
    )
}

extension DependencyValues {
    nonisolated var speakerClient: SpeakerClient {
        get { self[SpeakerClient.self] }
        set { self[SpeakerClient.self] = newValue }
    }
}

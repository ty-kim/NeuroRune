//
//  ElevenLabsClient.swift
//  NeuroRune
//
//  Created by tykim
//
//  ElevenLabs 메타 API (voice 목록 등). 합성은 SpeakerClient.elevenLabs 사용.
//

import Foundation
import Dependencies

nonisolated struct ElevenLabsClient: Sendable {
    /// GET /v1/voices — 계정에서 접근 가능한 voice 목록.
    var listVoices: @Sendable () async throws -> [ElevenLabsVoice]
}

nonisolated extension ElevenLabsClient {

    static let endpointHost = "api.elevenlabs.io"

    static func buildListVoicesRequest(credentials: ElevenLabsCredentials) -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpointHost
        components.path = "/v1/voices"
        // swiftlint:disable:next force_unwrapping
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private struct VoicesPayload: Decodable {
        struct Voice: Decodable {
            let voice_id: String
            let name: String
            let preview_url: String?
            let labels: [String: String]?
        }
        let voices: [Voice]
    }

    static func parseVoices(data: Data) throws -> [ElevenLabsVoice] {
        do {
            let payload = try JSONDecoder().decode(VoicesPayload.self, from: data)
            return payload.voices.map {
                ElevenLabsVoice(
                    id: $0.voice_id,
                    name: $0.name,
                    previewUrl: $0.preview_url,
                    labels: $0.labels
                )
            }
        } catch {
            throw SpeechError.decoding(error.localizedDescription)
        }
    }

    static func live(session: URLSession, credentials: ElevenLabsCredentials) -> ElevenLabsClient {
        ElevenLabsClient(
            listVoices: {
                let request = buildListVoicesRequest(credentials: credentials)

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
                switch http.statusCode {
                case 200..<300:
                    return try parseVoices(data: data)
                case 401:
                    throw SpeechError.unauthorized
                case 429:
                    throw SpeechError.rateLimited
                default:
                    let msg = String(data: data, encoding: .utf8) ?? "ElevenLabs list voices failed"
                    throw SpeechError.server(status: http.statusCode, message: msg)
                }
            }
        )
    }
}

nonisolated extension ElevenLabsClient: DependencyKey {
    static let liveValue: ElevenLabsClient = {
        ElevenLabsClient(
            listVoices: {
                guard let credentials = try ElevenLabsCredentialsClient.liveValue.load() else {
                    throw SpeechError.unauthorized
                }
                return try await live(session: .shared, credentials: credentials).listVoices()
            }
        )
    }()

    static let testValue = ElevenLabsClient(
        listVoices: unimplemented("ElevenLabsClient.listVoices", placeholder: [])
    )

    static let previewValue = ElevenLabsClient(
        listVoices: {
            [
                ElevenLabsVoice(id: "pv1", name: "Rachel", previewUrl: nil, labels: nil),
                ElevenLabsVoice(id: "pv2", name: "Adam", previewUrl: nil, labels: nil)
            ]
        }
    )
}

extension DependencyValues {
    nonisolated var elevenLabsClient: ElevenLabsClient {
        get { self[ElevenLabsClient.self] }
        set { self[ElevenLabsClient.self] = newValue }
    }
}

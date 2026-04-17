//
//  ElevenLabsClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  ElevenLabsClient.listVoices 요청 빌더 · 파서 · 통합 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct ElevenLabsClientTests {

    private let creds = ElevenLabsCredentials(apiKey: "sk_xyz")

    // MARK: - 요청 빌더

    @Test("GET /v1/voices + xi-api-key 헤더")
    func listVoicesRequest() {
        let req = ElevenLabsClient.buildListVoicesRequest(credentials: creds)
        #expect(req.url?.absoluteString == "https://api.elevenlabs.io/v1/voices")
        #expect(req.httpMethod == "GET")
        #expect(req.value(forHTTPHeaderField: "xi-api-key") == "sk_xyz")
        #expect(req.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    // MARK: - 파서

    @Test("응답 JSON → ElevenLabsVoice 배열")
    func parseVoicesList() throws {
        let json = """
        {
          "voices": [
            {
              "voice_id": "21m00Tcm4TlvDq8ikWAM",
              "name": "Rachel",
              "preview_url": "https://example.com/r.mp3",
              "labels": {"accent":"american","gender":"female"}
            },
            {
              "voice_id": "JBFqnCBsd6RMkjVDRZzb",
              "name": "George"
            }
          ]
        }
        """.data(using: .utf8)!

        let voices = try ElevenLabsClient.parseVoices(data: json)
        #expect(voices.count == 2)
        #expect(voices[0].id == "21m00Tcm4TlvDq8ikWAM")
        #expect(voices[0].name == "Rachel")
        #expect(voices[0].previewUrl == "https://example.com/r.mp3")
        #expect(voices[0].labels?["accent"] == "american")
        #expect(voices[1].name == "George")
        #expect(voices[1].previewUrl == nil)
    }

    @Test("빈 voices 배열")
    func parseEmptyVoices() throws {
        let json = #"{"voices":[]}"#.data(using: .utf8)!
        let voices = try ElevenLabsClient.parseVoices(data: json)
        #expect(voices.isEmpty)
    }

    @Test("잘못된 JSON → decoding 에러")
    func parseGarbage() {
        #expect(throws: SpeechError.self) {
            _ = try ElevenLabsClient.parseVoices(data: Data("not json".utf8))
        }
    }

    // MARK: - 통합

    @Test("listVoices 통합: 200 응답 → [ElevenLabsVoice]")
    func listVoicesIntegration() async throws {
        let body = #"{"voices":[{"voice_id":"a","name":"Alpha"}]}"#.data(using: .utf8)!
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (http, body, nil)
        }

        let client = ElevenLabsClient.live(session: stub.session, credentials: creds)
        let voices = try await client.listVoices()
        #expect(voices == [ElevenLabsVoice(id: "a", name: "Alpha", previewUrl: nil, labels: nil)])
    }

    @Test("listVoices 401 → unauthorized")
    func listVoices401() async {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (http, Data(), nil)
        }
        let client = ElevenLabsClient.live(session: stub.session, credentials: creds)

        await #expect(throws: SpeechError.unauthorized) {
            _ = try await client.listVoices()
        }
    }
}

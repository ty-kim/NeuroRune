//
//  ElevenLabsRequestTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  SpeakerClient.buildElevenLabsRequest 순수 함수 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct ElevenLabsRequestTests {

    private let creds = ElevenLabsCredentials(apiKey: "sk_xyz")
    private let settings = ElevenLabsVoiceSettings(
        stability: 0.5,
        similarityBoost: 0.75,
        style: 0.0,
        useSpeakerBoost: true
    )

    @Test("URL: voice_id path + output_format 쿼리")
    func urlHasVoiceIdAndFormat() throws {
        let req = try SpeakerClient.buildElevenLabsRequest(
            text: "hi",
            voiceId: "JBFqnCBsd6RMkjVDRZzb",
            modelId: "eleven_v3",
            languageCode: nil,
            settings: settings,
            credentials: creds
        )
        let url = try #require(req.url)
        #expect(url.absoluteString.hasPrefix("https://api.elevenlabs.io/v1/text-to-speech/JBFqnCBsd6RMkjVDRZzb"))
        #expect(url.query?.contains("output_format=mp3_44100_128") == true)
    }

    @Test("헤더: xi-api-key, Content-Type=application/json")
    func requiredHeaders() throws {
        let req = try SpeakerClient.buildElevenLabsRequest(
            text: "hi",
            voiceId: "v1",
            modelId: "eleven_v3",
            languageCode: nil,
            settings: settings,
            credentials: creds
        )
        #expect(req.value(forHTTPHeaderField: "xi-api-key") == "sk_xyz")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(req.httpMethod == "POST")
    }

    @Test("body: text, model_id, voice_settings 포함")
    func bodyFields() throws {
        let req = try SpeakerClient.buildElevenLabsRequest(
            text: "안녕",
            voiceId: "v1",
            modelId: "eleven_v3",
            languageCode: nil,
            settings: settings,
            credentials: creds
        )
        let body = try #require(req.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["text"] as? String == "안녕")
        #expect(json["model_id"] as? String == "eleven_v3")
        let vs = try #require(json["voice_settings"] as? [String: Any])
        #expect(vs["stability"] as? Double == 0.5)
        #expect(vs["similarity_boost"] as? Double == 0.75)
        #expect(vs["style"] as? Double == 0.0)
        #expect(vs["use_speaker_boost"] as? Bool == true)
    }

    @Test("language_code 있으면 body에 포함, nil이면 키 자체 없음")
    func optionalLanguageCode() throws {
        let reqWith = try SpeakerClient.buildElevenLabsRequest(
            text: "t", voiceId: "v", modelId: "m",
            languageCode: "ko", settings: settings, credentials: creds
        )
        let json1 = try JSONSerialization.jsonObject(with: reqWith.httpBody!) as? [String: Any]
        #expect(json1?["language_code"] as? String == "ko")

        let reqWithout = try SpeakerClient.buildElevenLabsRequest(
            text: "t", voiceId: "v", modelId: "m",
            languageCode: nil, settings: settings, credentials: creds
        )
        let json2 = try JSONSerialization.jsonObject(with: reqWithout.httpBody!) as? [String: Any]
        #expect(json2?["language_code"] == nil)
    }

    @Test("voiceId 비어있으면 network 에러")
    func emptyVoiceIdRejected() {
        #expect(throws: SpeechError.self) {
            _ = try SpeakerClient.buildElevenLabsRequest(
                text: "t", voiceId: "", modelId: "m",
                languageCode: nil, settings: settings, credentials: creds
            )
        }
    }

    // MARK: - handleElevenLabs 매핑

    @Test("200 + 비어있지 않은 body → Data 반환")
    func handleSuccess() throws {
        let mp3 = Data([0xFF, 0xFB])
        let data = try SpeakerClient.handleElevenLabs(status: 200, body: mp3)
        #expect(data == mp3)
    }

    @Test("200 + empty body → decoding 에러")
    func handleEmptyBody() {
        #expect(throws: SpeechError.self) {
            _ = try SpeakerClient.handleElevenLabs(status: 200, body: Data())
        }
    }

    @Test("401 → unauthorized")
    func handle401() {
        #expect(throws: SpeechError.unauthorized) {
            _ = try SpeakerClient.handleElevenLabs(status: 401, body: Data())
        }
    }

    @Test("422 → voiceUnavailable (PVC 플랜 제한)")
    func handle422() {
        #expect(throws: SpeechError.voiceUnavailable) {
            _ = try SpeakerClient.handleElevenLabs(status: 422, body: Data())
        }
    }

    @Test("429 → rateLimited")
    func handle429() {
        #expect(throws: SpeechError.rateLimited) {
            _ = try SpeakerClient.handleElevenLabs(status: 429, body: Data())
        }
    }

    @Test("500 → server(500, ...)")
    func handle500() {
        do {
            _ = try SpeakerClient.handleElevenLabs(status: 500, body: Data("boom".utf8))
            Issue.record("expected server error")
        } catch let SpeechError.server(status, message) {
            #expect(status == 500)
            #expect(message == "boom")
        } catch {
            Issue.record("unexpected: \(error)")
        }
    }

    // MARK: - elevenLabs(session:) 통합

    @Test("elevenLabs 통합: 200 응답 → MP3 Data 반환")
    func elevenLabsSynthesizeSuccess() async throws {
        let mp3 = Data([0xFF, 0xFB, 0x90, 0x00])
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (http, mp3, nil)
        }

        let data = try await SpeakerClient.elevenLabs(
            session: stub.session,
            text: "hi",
            voiceId: "v1",
            modelId: "eleven_v3",
            languageCode: "en",
            settings: settings,
            credentials: creds
        )
        #expect(data == mp3)
    }

    @Test("elevenLabs 통합: URLError cancelled → SpeechError.cancelled")
    func elevenLabsCancelled() async throws {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let error = URLError(.cancelled)
            let http = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (http, nil, error)
        }

        await #expect(throws: SpeechError.cancelled) {
            _ = try await SpeakerClient.elevenLabs(
                session: stub.session,
                text: "hi",
                voiceId: "v1",
                modelId: "eleven_v3",
                languageCode: nil,
                settings: settings,
                credentials: creds
            )
        }
    }
}

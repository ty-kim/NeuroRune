//
//  SpeakerClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  SpeakerClient.azureNeural 통합 + SSML 빌더 유닛 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct SpeakerClientTests {

    private let credentials = AzureCredentials(apiKey: "azure-key", region: "koreacentral")

    // MARK: - SSML 빌더

    @Test("SSML 빌더는 voice·language·rate·pitch를 조립하고 text를 이스케이프한다")
    func ssmlBasic() {
        let ssml = SpeakerClient.buildSSML(
            text: "안녕 <world>",
            voice: "ko-KR-SunHiNeural",
            language: "ko-KR",
            rate: 1.0,
            pitch: 1.0
        )
        #expect(ssml.contains("xml:lang=\"ko-KR\""))
        #expect(ssml.contains("name=\"ko-KR-SunHiNeural\""))
        #expect(ssml.contains("rate=\"1.00\""))
        #expect(ssml.contains("pitch=\"+0%\""))
        // < 이스케이프
        #expect(ssml.contains("&lt;world&gt;"))
        #expect(!ssml.contains("<world>"))
    }

    @Test("pitch 0.5는 -50%, 1.5는 +50%")
    func ssmlPitchPercent() {
        let low = SpeakerClient.buildSSML(text: "t", voice: "v", language: "ko-KR", rate: 1.0, pitch: 0.5)
        #expect(low.contains("pitch=\"-50%\""))

        let high = SpeakerClient.buildSSML(text: "t", voice: "v", language: "ko-KR", rate: 1.0, pitch: 1.5)
        #expect(high.contains("pitch=\"+50%\""))
    }

    @Test("xmlEscape는 5개 특수문자를 치환한다")
    func xmlEscapeAll() {
        let s = SpeakerClient.xmlEscape(#"A & B < C > D " E ' F"#)
        #expect(s == #"A &amp; B &lt; C &gt; D &quot; E &apos; F"#)
    }

    // MARK: - Request 구성

    @Test("buildAzureRequest는 region 기반 endpoint·헤더·SSML body를 세팅한다")
    func buildRequestFields() throws {
        let req = try SpeakerClient.buildAzureRequest(
            text: "hello",
            voice: "en-US-JennyNeural",
            language: "en-US",
            rate: 1.0,
            pitch: 1.0,
            credentials: credentials
        )
        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString == "https://koreacentral.tts.speech.microsoft.com/cognitiveservices/v1")
        #expect(req.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Key") == "azure-key")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/ssml+xml")
        #expect(req.value(forHTTPHeaderField: "X-Microsoft-OutputFormat") == "audio-16khz-32kbitrate-mono-mp3")
        let body = String(data: req.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("en-US-JennyNeural"))
        #expect(body.contains(">hello<"))
    }

    // MARK: - Success

    @Test("200 + non-empty body → Data 반환")
    func success200ReturnsData() async throws {
        let mp3 = Data([0xFF, 0xFB, 0x90, 0x00])  // fake MP3 frame header
        let stub = stubStatus(200, body: mp3)
        let client = SpeakerClient.azureNeural(session: stub.session, credentials: credentials)

        let data = try await client.synthesize("hi", "v", "ko-KR", 1.0, 1.0)
        #expect(data == mp3)
    }

    @Test("200이지만 empty body → SpeechError.decoding")
    func emptyBodyDecodingError() async throws {
        let stub = stubStatus(200, body: Data())
        let client = SpeakerClient.azureNeural(session: stub.session, credentials: credentials)

        do {
            _ = try await client.synthesize("hi", "v", "ko-KR", 1.0, 1.0)
            Issue.record("expected decoding error")
        } catch let SpeechError.decoding(detail) {
            #expect(!detail.isEmpty)
        } catch {
            Issue.record("unexpected: \(error)")
        }
    }

    // MARK: - Error mapping

    @Test("401 → SpeechError.unauthorized")
    func unauthorized() async throws {
        let stub = stubStatus(401, body: Data("bad key".utf8))
        let client = SpeakerClient.azureNeural(session: stub.session, credentials: credentials)

        await #expect(throws: SpeechError.unauthorized) {
            _ = try await client.synthesize("hi", "v", "ko-KR", 1.0, 1.0)
        }
    }

    @Test("429 → SpeechError.rateLimited")
    func rateLimited() async throws {
        let stub = stubStatus(429, body: Data())
        let client = SpeakerClient.azureNeural(session: stub.session, credentials: credentials)

        await #expect(throws: SpeechError.rateLimited) {
            _ = try await client.synthesize("hi", "v", "ko-KR", 1.0, 1.0)
        }
    }

    @Test("5xx → SpeechError.server")
    func serverError() async throws {
        let stub = stubStatus(503, body: Data("overloaded".utf8))
        let client = SpeakerClient.azureNeural(session: stub.session, credentials: credentials)

        do {
            _ = try await client.synthesize("hi", "v", "ko-KR", 1.0, 1.0)
            Issue.record("expected server error")
        } catch let SpeechError.server(status, message) {
            #expect(status == 503)
            #expect(message.contains("overloaded"))
        } catch {
            Issue.record("unexpected: \(error)")
        }
    }

    @Test("URLError timeout → SpeechError.network")
    func networkTimeoutMapped() async throws {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let error = URLError(.timedOut)
            let http = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (http, nil, error)
        }
        let client = SpeakerClient.azureNeural(session: stub.session, credentials: credentials)

        do {
            _ = try await client.synthesize("hi", "v", "ko-KR", 1.0, 1.0)
            Issue.record("expected network error")
        } catch SpeechError.network {
            // ok
        } catch {
            Issue.record("unexpected: \(error)")
        }
    }

    @Test("URLError cancelled → SpeechError.cancelled")
    func cancelledMapped() async throws {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let error = URLError(.cancelled)
            let http = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (http, nil, error)
        }
        let client = SpeakerClient.azureNeural(session: stub.session, credentials: credentials)

        await #expect(throws: SpeechError.cancelled) {
            _ = try await client.synthesize("hi", "v", "ko-KR", 1.0, 1.0)
        }
    }

    // MARK: - Helpers

    private func stubStatus(_ status: Int, body: Data) -> URLProtocolStub.Stub {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
            return (http, body, nil)
        }
        return stub
    }
}

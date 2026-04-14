//
//  STTClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  STTClient.groqWhisper 통합 테스트. URLProtocolStub로 HTTP 응답 주입.
//

import Foundation
import Testing
@testable import NeuroRune

struct STTClientTests {

    private let credentials = GroqCredentials(apiKey: "gsk_test-key")

    // MARK: - Request 구성

    @Test("buildGroqRequest는 endpoint·Bearer·multipart Content-Type을 세팅한다")
    func buildRequestFields() throws {
        let audio = Data([0x01, 0x02, 0x03])
        let req = try STTClient.buildGroqRequest(audio: audio, language: "ko", credentials: credentials)

        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString == "https://api.groq.com/openai/v1/audio/transcriptions")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer gsk_test-key")
        let contentType = req.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
    }

    @Test("multipart body에 file·model·language·response_format이 포함된다")
    func multipartBodyFields() throws {
        // ASCII 전용 오디오 바이트로 utf-8 디코딩 가능하게 유지
        let audio = Data("AB".utf8)
        let body = STTClient.buildMultipartBody(boundary: "BOUND", audio: audio, language: "ko")
        let text = String(data: body, encoding: .utf8) ?? ""

        #expect(text.contains("name=\"file\"; filename=\"audio.wav\""))
        #expect(text.contains("Content-Type: audio/wav"))
        #expect(text.contains("name=\"model\""))
        #expect(text.contains("whisper-large-v3"))
        #expect(text.contains("name=\"language\""))
        #expect(text.contains("ko"))
        #expect(text.contains("name=\"response_format\""))
        #expect(text.contains("json"))
        #expect(text.hasSuffix("--BOUND--\r\n"))
    }

    // MARK: - Success

    @Test("200 + 정상 JSON → STTResult.text")
    func success200ReturnsText() async throws {
        let stub = stubStatus(200, jsonBody: #"{"text":"안녕하세요"}"#)
        let client = STTClient.groqWhisper(session: stub.session, credentials: credentials)

        let result = try await client.transcribe(Data([0xAA]), "ko")
        #expect(result.text == "안녕하세요")
    }

    // MARK: - Error mapping

    @Test("401 → STTError.unauthorized")
    func unauthorized() async throws {
        let stub = stubStatus(401, jsonBody: #"{"error":{"message":"Invalid API Key"}}"#)
        let client = STTClient.groqWhisper(session: stub.session, credentials: credentials)

        await #expect(throws: STTError.unauthorized) {
            _ = try await client.transcribe(Data(), "ko")
        }
    }

    @Test("429 → STTError.rateLimited")
    func rateLimited() async throws {
        let stub = stubStatus(429, jsonBody: "")
        let client = STTClient.groqWhisper(session: stub.session, credentials: credentials)

        await #expect(throws: STTError.rateLimited) {
            _ = try await client.transcribe(Data(), "ko")
        }
    }

    @Test("5xx → STTError.server 에 status·메시지")
    func serverError() async throws {
        let stub = stubStatus(503, jsonBody: #"{"error":{"message":"overloaded"}}"#)
        let client = STTClient.groqWhisper(session: stub.session, credentials: credentials)

        do {
            _ = try await client.transcribe(Data(), "ko")
            Issue.record("expected server error")
        } catch let STTError.server(status, message) {
            #expect(status == 503)
            #expect(message == "overloaded")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("200이지만 JSON 파싱 실패 → STTError.decoding")
    func decodingError() async throws {
        let stub = stubStatus(200, jsonBody: #"{"unexpected":"shape"}"#)
        let client = STTClient.groqWhisper(session: stub.session, credentials: credentials)

        do {
            _ = try await client.transcribe(Data(), "ko")
            Issue.record("expected decoding error")
        } catch let STTError.decoding(detail) {
            #expect(!detail.isEmpty)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("URLError 타임아웃 → STTError.network")
    func networkTimeoutMapped() async throws {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let error = URLError(.timedOut)
            let http = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (http, nil, error)
        }
        let client = STTClient.groqWhisper(session: stub.session, credentials: credentials)

        do {
            _ = try await client.transcribe(Data(), "ko")
            Issue.record("expected network error")
        } catch STTError.network {
            // ok
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("URLError cancelled → STTError.cancelled")
    func cancelledMapped() async throws {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let error = URLError(.cancelled)
            let http = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (http, nil, error)
        }
        let client = STTClient.groqWhisper(session: stub.session, credentials: credentials)

        await #expect(throws: STTError.cancelled) {
            _ = try await client.transcribe(Data(), "ko")
        }
    }

    // MARK: - Helpers

    private func stubStatus(_ status: Int, jsonBody: String) -> URLProtocolStub.Stub {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (http, Data(jsonBody.utf8), nil)
        }
        return stub
    }
}

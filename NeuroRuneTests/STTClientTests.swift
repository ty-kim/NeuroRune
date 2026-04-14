//
//  STTClientTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  STTClient.clovaCSR 통합 테스트. URLProtocolStub로 HTTP 응답 주입.
//

import Foundation
import Testing
@testable import NeuroRune

struct STTClientTests {

    private let credentials = NCPCredentials(apiKeyID: "id-test", apiKey: "key-test")

    // MARK: - Request 구성

    @Test("buildCSRRequest는 lang 쿼리와 두 헤더, octet-stream, body를 채운다")
    func buildRequestFields() throws {
        let audio = Data([0x01, 0x02, 0x03])
        let req = try STTClient.buildCSRRequest(audio: audio, language: "Kor", credentials: credentials)

        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString == "https://naveropenapi.apigw.ntruss.com/recog/v1/stt?lang=Kor")
        #expect(req.value(forHTTPHeaderField: "X-NCP-APIGW-API-KEY-ID") == "id-test")
        #expect(req.value(forHTTPHeaderField: "X-NCP-APIGW-API-KEY") == "key-test")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        #expect(req.httpBody == audio)
    }

    @Test("buildCSRRequest는 언어 코드를 그대로 lang 쿼리로 넘긴다")
    func languageCodePassthrough() throws {
        for lang in ["Kor", "Eng", "Jpn", "Chn"] {
            let req = try STTClient.buildCSRRequest(audio: Data(), language: lang, credentials: credentials)
            #expect(req.url?.absoluteString.contains("lang=\(lang)") == true)
        }
    }

    // MARK: - Success

    @Test("200 + 정상 JSON → STTResult.text")
    func success200ReturnsText() async throws {
        let stub = stubStatus(200, jsonBody: #"{"text":"안녕하세요"}"#)
        let client = STTClient.clovaCSR(session: stub.session, credentials: credentials)

        let result = try await client.transcribe(Data([0xAA]), "Kor")
        #expect(result.text == "안녕하세요")
    }

    // MARK: - Error mapping

    @Test("401 → STTError.unauthorized")
    func unauthorized() async throws {
        let stub = stubStatus(401, jsonBody: #"{"error":{"message":"bad key"}}"#)
        let client = STTClient.clovaCSR(session: stub.session, credentials: credentials)

        await #expect(throws: STTError.unauthorized) {
            _ = try await client.transcribe(Data(), "Kor")
        }
    }

    @Test("429 → STTError.rateLimited")
    func rateLimited() async throws {
        let stub = stubStatus(429, jsonBody: "")
        let client = STTClient.clovaCSR(session: stub.session, credentials: credentials)

        await #expect(throws: STTError.rateLimited) {
            _ = try await client.transcribe(Data(), "Kor")
        }
    }

    @Test("5xx → STTError.server 에 status·메시지")
    func serverError() async throws {
        let stub = stubStatus(503, jsonBody: #"{"errorMessage":"overloaded"}"#)
        let client = STTClient.clovaCSR(session: stub.session, credentials: credentials)

        do {
            _ = try await client.transcribe(Data(), "Kor")
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
        let client = STTClient.clovaCSR(session: stub.session, credentials: credentials)

        do {
            _ = try await client.transcribe(Data(), "Kor")
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
        let client = STTClient.clovaCSR(session: stub.session, credentials: credentials)

        do {
            _ = try await client.transcribe(Data(), "Kor")
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
        let client = STTClient.clovaCSR(session: stub.session, credentials: credentials)

        await #expect(throws: STTError.cancelled) {
            _ = try await client.transcribe(Data(), "Kor")
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

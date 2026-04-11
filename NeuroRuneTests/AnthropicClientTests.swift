//
//  AnthropicClientTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
@testable import NeuroRune

@Suite(.serialized)
struct AnthropicClientTests {

    init() {
        URLProtocolStub.reset()
    }

    // MARK: - Request: URL + Method

    @Test("sendMessage는 Anthropic messages endpoint로 POST 한다")
    func sendMessagePostsToAnthropicEndpoint() async throws {
        stubSuccess()
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        _ = try? await client.sendMessage([Self.testUserMessage], .opus46)

        let captured = URLProtocolStub.lastRequest
        #expect(captured?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(captured?.httpMethod == "POST")
    }

    // MARK: - Request: Headers

    @Test("요청 헤더에 x-api-key가 포함된다")
    func includesApiKeyHeader() async throws {
        stubSuccess()
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-ant-abc123")

        _ = try? await client.sendMessage([Self.testUserMessage], .opus46)

        #expect(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "x-api-key") == "sk-ant-abc123")
    }

    @Test("요청 헤더에 anthropic-version: 2023-06-01이 포함된다")
    func includesAnthropicVersionHeader() async throws {
        stubSuccess()
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        _ = try? await client.sendMessage([Self.testUserMessage], .opus46)

        #expect(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    }

    @Test("요청 헤더에 content-type: application/json이 포함된다")
    func includesContentTypeHeader() async throws {
        stubSuccess()
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        _ = try? await client.sendMessage([Self.testUserMessage], .opus46)

        #expect(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    // MARK: - Request: Body

    @Test("body의 model 필드가 전달된 LLMModel.id와 일치한다")
    func bodyModelFieldMatchesProvidedModel() async throws {
        stubSuccess()
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        _ = try? await client.sendMessage([Self.testUserMessage], .sonnet46)

        let body = try Self.decodeCapturedBody()
        #expect(body["model"] as? String == "claude-sonnet-4-6")
    }

    @Test("body의 messages 배열이 role/content 형태로 직렬화된다")
    func bodyMessagesFieldIsSerializedCorrectly() async throws {
        stubSuccess()
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")
        let messages = [
            Message(role: .user, content: "안녕", createdAt: Date()),
            Message(role: .assistant, content: "반갑다", createdAt: Date()),
            Message(role: .user, content: "다시", createdAt: Date())
        ]

        _ = try? await client.sendMessage(messages, .opus46)

        let body = try Self.decodeCapturedBody()
        let bodyMessages = body["messages"] as? [[String: String]]
        #expect(bodyMessages?.count == 3)
        #expect(bodyMessages?[0] == ["role": "user", "content": "안녕"])
        #expect(bodyMessages?[1] == ["role": "assistant", "content": "반갑다"])
        #expect(bodyMessages?[2] == ["role": "user", "content": "다시"])
    }

    @Test("body에 max_tokens 필드가 포함된다 (기본 4096)")
    func bodyHasMaxTokensField() async throws {
        stubSuccess()
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        _ = try? await client.sendMessage([Self.testUserMessage], .opus46)

        let body = try Self.decodeCapturedBody()
        #expect(body["max_tokens"] as? Int == 4096)
    }

    // MARK: - Response: 200 parsing

    @Test("200 응답의 content[0].text를 assistant Message로 파싱한다")
    func parses200ResponseIntoAssistantMessage() async throws {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body: [String: Any] = [
                "id": "msg_01XYZ",
                "type": "message",
                "role": "assistant",
                "model": "claude-opus-4-6",
                "content": [["type": "text", "text": "안녕하세요. 반갑습니다."]],
                "stop_reason": "end_turn"
            ]
            let data = try? JSONSerialization.data(withJSONObject: body)
            return (http, data, nil)
        }
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        let result = try await client.sendMessage([Self.testUserMessage], .opus46)

        #expect(result.role == .assistant)
        #expect(result.content == "안녕하세요. 반갑습니다.")
    }

    // MARK: - Response: Error mapping

    @Test("401 응답은 LLMError.unauthorized를 throw한다")
    func mapsUnauthorized() async throws {
        Self.stubStatus(401, body: #"{"error":{"type":"authentication_error","message":"invalid"}}"#)
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-bad")

        await #expect(throws: LLMError.unauthorized) {
            _ = try await client.sendMessage([Self.testUserMessage], .opus46)
        }
    }

    @Test("429 응답은 LLMError.rateLimited를 throw한다")
    func mapsRateLimited() async throws {
        Self.stubStatus(429, body: #"{"error":{"type":"rate_limit_error"}}"#)
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        await #expect(throws: LLMError.rateLimited) {
            _ = try await client.sendMessage([Self.testUserMessage], .opus46)
        }
    }

    @Test("5xx 응답은 LLMError.server(status:)를 throw한다")
    func mapsServerError() async throws {
        Self.stubStatus(503, body: #"{"error":{"type":"overloaded_error"}}"#)
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        await #expect(throws: LLMError.server(status: 503)) {
            _ = try await client.sendMessage([Self.testUserMessage], .opus46)
        }
    }

    @Test("URLError는 LLMError.network로 wrap된다")
    func mapsNetworkError() async throws {
        URLProtocolStub.setHandler { request in
            let dummy = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (dummy, nil, URLError(.timedOut))
        }
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        await #expect {
            _ = try await client.sendMessage([Self.testUserMessage], .opus46)
        } throws: { error in
            guard case let LLMError.network(description) = error else { return false }
            return !description.isEmpty
        }
    }

    @Test("빈 content 배열은 LLMError.decoding으로 throw된다")
    func mapsEmptyContentToDecodingError() async throws {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body: [String: Any] = [
                "id": "msg_empty",
                "type": "message",
                "role": "assistant",
                "content": [],
                "model": "claude-opus-4-6",
                "stop_reason": "end_turn"
            ]
            let data = try? JSONSerialization.data(withJSONObject: body)
            return (http, data, nil)
        }
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        await #expect {
            _ = try await client.sendMessage([Self.testUserMessage], .opus46)
        } throws: { error in
            guard case LLMError.decoding = error else { return false }
            return true
        }
    }

    @Test("content에 text block이 없으면 LLMError.decoding으로 throw된다")
    func mapsNoTextBlockToDecodingError() async throws {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body: [String: Any] = [
                "id": "msg_tool",
                "type": "message",
                "role": "assistant",
                "content": [
                    ["type": "tool_use", "id": "tool_1", "name": "calculator", "input": ["x": 1]]
                ],
                "model": "claude-opus-4-6",
                "stop_reason": "tool_use"
            ]
            let data = try? JSONSerialization.data(withJSONObject: body)
            return (http, data, nil)
        }
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        await #expect {
            _ = try await client.sendMessage([Self.testUserMessage], .opus46)
        } throws: { error in
            guard case LLMError.decoding = error else { return false }
            return true
        }
    }

    @Test("content에 여러 text block이 있으면 순서대로 결합된다")
    func concatenatesMultipleTextBlocks() async throws {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body: [String: Any] = [
                "id": "msg_multi",
                "type": "message",
                "role": "assistant",
                "content": [
                    ["type": "text", "text": "안녕. "],
                    ["type": "text", "text": "반갑다."]
                ],
                "model": "claude-opus-4-6",
                "stop_reason": "end_turn"
            ]
            let data = try? JSONSerialization.data(withJSONObject: body)
            return (http, data, nil)
        }
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        let result = try await client.sendMessage([Self.testUserMessage], .opus46)

        #expect(result.content == "안녕. 반갑다.")
    }

    @Test("잘못된 JSON 응답은 LLMError.decoding으로 wrap된다")
    func mapsDecodingError() async throws {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (http, Data("not a json".utf8), nil)
        }
        let client = LLMClient.anthropic(session: Self.makeSession(), apiKey: "sk-test")

        await #expect {
            _ = try await client.sendMessage([Self.testUserMessage], .opus46)
        } throws: { error in
            guard case LLMError.decoding = error else { return false }
            return true
        }
    }

    private static func stubStatus(_ status: Int, body: String) {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (http, Data(body.utf8), nil)
        }
    }

    // MARK: - Helpers

    static let testUserMessage = Message(
        role: .user,
        content: "hello",
        createdAt: Date(timeIntervalSince1970: 1_000_000)
    )

    static func makeSession() -> URLSession {
        URLProtocolStub.makeSession()
    }

    private func stubSuccess() {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body: [String: Any] = [
                "id": "msg_01",
                "type": "message",
                "role": "assistant",
                "content": [["type": "text", "text": "ok"]],
                "model": "claude-opus-4-6",
                "stop_reason": "end_turn"
            ]
            let data = try? JSONSerialization.data(withJSONObject: body)
            return (http, data, nil)
        }
    }

    static func decodeCapturedBody() throws -> [String: Any] {
        guard let data = URLProtocolStub.lastRequest?.httpBodyStream?.readAllData()
                ?? URLProtocolStub.lastRequest?.httpBody else {
            throw TestError.noRequestBody
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestError.bodyNotJSON
        }
        return json
    }

    enum TestError: Error {
        case noRequestBody
        case bodyNotJSON
    }
}

private extension InputStream {
    func readAllData() -> Data {
        open()
        defer { close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while hasBytesAvailable {
            let read = self.read(buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }
        return data
    }
}

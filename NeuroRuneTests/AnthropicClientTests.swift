//
//  AnthropicClientTests.swift
//  NeuroRuneTests
//
//  LLMClient.anthropic(session:apiKey:) 통합 테스트.
//  URLProtocolStub로 HTTP layer 가짜 응답을 주입, streamMessage의
//  status 매핑, SSE chunk 수집, 에러 전파를 검증한다.
//

import Testing
import Foundation
@testable import NeuroRune

struct AnthropicClientTests {

    // MARK: - Success path

    @Test("SSE bytes → chunk를 순서대로 수집한다")
    func collectsChunksInOrder() async throws {
        let sse = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        let stub = stubStatus(200, body: sse)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        var collected: [String] = []
        let stream = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        for try await event in stream {
            if case .textDelta(let text) = event { collected.append(text) }
        }

        #expect(collected == ["Hello", " world"])
    }

    @Test("message_stop 이후 라인은 무시되고 스트림 종료된다")
    func messageStopTerminatesStream() async throws {
        let sse = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"A"}}

        event: message_stop
        data: {"type":"message_stop"}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"SHOULD_NOT_APPEAR"}}

        """
        let stub = stubStatus(200, body: sse)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        var collected: [String] = []
        let stream = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        for try await event in stream {
            if case .textDelta(let text) = event { collected.append(text) }
        }

        #expect(collected == ["A"])
    }

    // MARK: - Status mapping

    @Test("401 → LLMError.unauthorized")
    func mapsUnauthorized() async throws {
        let stub = stubStatus(401, body: #"{"error":{"type":"authentication_error"}}"#)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-bad")

        await #expect(throws: LLMError.unauthorized) {
            _ = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        }
    }

    @Test("429 → LLMError.rateLimited")
    func mapsRateLimited() async throws {
        let stub = stubStatus(429, body: #"{"error":{"type":"rate_limit_error"}}"#)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        await #expect(throws: LLMError.rateLimited) {
            _ = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        }
    }

    @Test("5xx → LLMError.server")
    func mapsServerError() async throws {
        let stub = stubStatus(503, body: #"{"error":{"type":"overloaded_error"}}"#)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        await #expect {
            _ = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        } throws: { error in
            guard case LLMError.server(let status, _) = error else { return false }
            return status == 503
        }
    }

    @Test("URLError → LLMError.network")
    func mapsNetworkError() async throws {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            let dummy = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (dummy, nil, URLError(.timedOut))
        }
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        await #expect {
            _ = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        } throws: { error in
            guard case LLMError.network = error else { return false }
            return true
        }
    }

    // MARK: - Stream error propagation

    @Test("스트림 중 error 이벤트는 LLMError.server로 throw된다")
    func streamErrorEventPropagates() async throws {
        let sse = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"partial"}}

        event: error
        data: {"type":"error","error":{"type":"overloaded_error","message":"Service overloaded"}}

        """
        let stub = stubStatus(200, body: sse)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        var collected: [String] = []
        let stream = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)

        await #expect {
            for try await event in stream {
                if case .textDelta(let text) = event { collected.append(text) }
            }
        } throws: { error in
            guard case LLMError.server(_, let message) = error else { return false }
            return message == "Service overloaded"
        }

        #expect(collected == ["partial"])
    }

    @Test("message_stop 없이 바이트 스트림 종료 시 LLMError.decoding throw")
    func streamEndWithoutStopThrowsDecoding() async throws {
        let sse = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"partial"}}

        """
        let stub = stubStatus(200, body: sse)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        var collected: [String] = []
        let stream = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)

        await #expect {
            for try await event in stream {
                if case .textDelta(let text) = event { collected.append(text) }
            }
        } throws: { error in
            guard case LLMError.decoding = error else { return false }
            return true
        }

        #expect(collected == ["partial"])
    }

    // MARK: - Rate limit

    @Test("200 응답 헤더에 rate limit가 있으면 첫 event로 rateLimitUpdate emit")
    func yieldsRateLimitUpdateBeforeTextDelta() async throws {
        let sse = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"x"}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        let stub = stubStatus(
            200,
            body: sse,
            extraHeaders: [
                "anthropic-ratelimit-tokens-limit": "80000",
                "anthropic-ratelimit-tokens-remaining": "62400",
                "anthropic-ratelimit-tokens-reset": "2026-04-14T14:00:00Z"
            ]
        )
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        var events: [LLMStreamEvent] = []
        let stream = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        for try await event in stream {
            events.append(event)
        }

        guard case let .rateLimitUpdate(state) = events.first else {
            Issue.record("first event is not rateLimitUpdate: \(events)")
            return
        }
        #expect(state.tokens?.limit == 80000)
        #expect(state.tokens?.remaining == 62400)
    }

    @Test("rate limit 헤더가 없으면 rateLimitUpdate emit 안 함")
    func skipsRateLimitUpdateWhenHeadersAbsent() async throws {
        let sse = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"x"}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        let stub = stubStatus(200, body: sse)
        let client = LLMClient.anthropic(session: stub.session, apiKey: "sk-test")

        var hasRateLimitEvent = false
        let stream = try await client.streamMessage([Self.userMessage], .opus46, nil, nil, nil)
        for try await event in stream {
            if case .rateLimitUpdate = event { hasRateLimitEvent = true }
        }

        #expect(hasRateLimitEvent == false)
    }

    // MARK: - Helpers

    static let userMessage = APIMessage.text(role: "user", content: "hi")

    private func stubStatus(_ status: Int, body: String, extraHeaders: [String: String] = [:]) -> URLProtocolStub.Stub {
        let stub = URLProtocolStub.Stub()
        stub.setHandler { request in
            var headers = ["Content-Type": "text/event-stream"]
            for (k, v) in extraHeaders { headers[k] = v }
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            return (http, Data(body.utf8), nil)
        }
        return stub
    }
}

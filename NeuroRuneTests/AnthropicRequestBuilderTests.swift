//
//  AnthropicRequestBuilderTests.swift
//  NeuroRuneTests
//

import Testing
import Foundation
@testable import NeuroRune

struct AnthropicRequestBuilderTests {

    private static let testMessage = Message(
        role: .user,
        content: "hi",
        createdAt: Date(timeIntervalSince1970: 1_000_000)
    )

    @Test("stream:true 옵션이 body에 반영된다")
    func streamTrueIsEncodedInBody() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test",
            stream: true
        )

        let body = try decodeBody(request)
        #expect(body["stream"] as? Bool == true)
    }

    @Test("stream 옵션 미지정 시 body에 stream 필드가 없다")
    func streamOmittedWhenDefault() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test"
        )

        let body = try decodeBody(request)
        #expect(body["stream"] == nil)
    }

    @Test("thinkingBudgetTokens 지정 시 body의 thinking이 enabled로 설정된다")
    func thinkingEncodedWhenBudgetProvided() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test",
            thinkingBudgetTokens: 5_000
        )

        let body = try decodeBody(request)
        let thinking = body["thinking"] as? [String: Any]
        #expect(thinking?["type"] as? String == "enabled")
        #expect(thinking?["budget_tokens"] as? Int == 5_000)
    }

    @Test("thinkingBudgetTokens 미지정 시 body에 thinking 필드가 없다")
    func thinkingOmittedWhenNil() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test"
        )

        let body = try decodeBody(request)
        #expect(body["thinking"] == nil)
    }

    private func decodeBody(_ request: URLRequest) throws -> [String: Any] {
        guard let data = request.httpBody else {
            throw DecodeError.noBody
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodeError.notJSON
        }
        return json
    }

    enum DecodeError: Error {
        case noBody
        case notJSON
    }
}

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

    @Test("effort + supportsEffort 모델이면 thinking.adaptive + output_config.effort 전송")
    func adaptiveEffortEncodedWhenSupported() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test",
            effort: .medium
        )

        let body = try decodeBody(request)
        let thinking = body["thinking"] as? [String: Any]
        #expect(thinking?["type"] as? String == "adaptive")
        let outputConfig = body["output_config"] as? [String: Any]
        #expect(outputConfig?["effort"] as? String == "medium")
    }

    @Test("effort 미지정 시 thinking/output_config 필드가 없다")
    func thinkingOmittedWhenEffortNil() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test"
        )

        let body = try decodeBody(request)
        #expect(body["thinking"] == nil)
        #expect(body["output_config"] == nil)
    }

    @Test("system 인자가 있으면 body의 system 필드에 그대로 전달")
    func systemFieldEncodedWhenProvided() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test",
            system: "You are a helpful assistant."
        )

        let body = try decodeBody(request)
        #expect(body["system"] as? String == "You are a helpful assistant.")
    }

    @Test("system 미지정 시 body에 system 필드가 없다")
    func systemOmittedWhenNil() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test"
        )

        let body = try decodeBody(request)
        #expect(body["system"] == nil)
    }

    @Test("tools 인자가 있으면 body의 tools 배열에 직렬화")
    func toolsFieldEncodedWhenProvided() throws {
        let tool = LLMTool(
            name: "read_memory",
            description: "Load a memory file by path.",
            inputSchema: LLMTool.InputSchema(
                properties: ["path": LLMTool.Property(type: "string", description: "File path")],
                required: ["path"]
            )
        )
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test",
            tools: [tool]
        )

        let body = try decodeBody(request)
        let tools = body["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        let first = tools?.first
        #expect(first?["name"] as? String == "read_memory")
        #expect(first?["description"] as? String == "Load a memory file by path.")
        let schema = first?["input_schema"] as? [String: Any]
        #expect(schema?["type"] as? String == "object")
        #expect((schema?["required"] as? [String]) == ["path"])
    }

    @Test("tools 미지정 시 body에 tools 필드가 없다")
    func toolsOmittedWhenNil() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .opus46,
            apiKey: "sk-test"
        )

        let body = try decodeBody(request)
        #expect(body["tools"] == nil)
    }

    @Test("supportsEffort=false 모델은 effort를 지정해도 thinking/output_config omit")
    func effortOmittedForUnsupportedModel() throws {
        let request = try AnthropicRequestBuilder.build(
            messages: [Self.testMessage],
            model: .haiku45,
            apiKey: "sk-test",
            effort: .high
        )

        let body = try decodeBody(request)
        #expect(body["thinking"] == nil)
        #expect(body["output_config"] == nil)
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

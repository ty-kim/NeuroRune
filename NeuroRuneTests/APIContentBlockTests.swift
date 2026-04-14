//
//  APIContentBlockTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
@testable import NeuroRune

struct APIContentBlockTests {

    @Test("text block은 type/text 필드로 직렬화")
    func encodesTextBlock() throws {
        let block = APIContentBlock.text("hello")
        let dict = try encode(block)

        #expect(dict["type"] as? String == "text")
        #expect(dict["text"] as? String == "hello")
    }

    @Test("tool_use block은 type/id/name/input으로 직렬화")
    func encodesToolUseBlock() throws {
        let block = APIContentBlock.toolUse(
            id: "toolu_x",
            name: "read_memory",
            input: ["role": "global", "path": "MEMORY.md"]
        )
        let dict = try encode(block)

        #expect(dict["type"] as? String == "tool_use")
        #expect(dict["id"] as? String == "toolu_x")
        #expect(dict["name"] as? String == "read_memory")
        let input = dict["input"] as? [String: String]
        #expect(input?["role"] == "global")
        #expect(input?["path"] == "MEMORY.md")
    }

    @Test("tool_result block은 type/tool_use_id/content로 직렬화")
    func encodesToolResultBlock() throws {
        let block = APIContentBlock.toolResult(toolUseID: "toolu_x", content: "memory body")
        let dict = try encode(block)

        #expect(dict["type"] as? String == "tool_result")
        #expect(dict["tool_use_id"] as? String == "toolu_x")
        #expect(dict["content"] as? String == "memory body")
    }

    @Test("APIMessage.Content.text는 string으로 직렬화")
    func encodesAPIMessageWithStringContent() throws {
        let msg = APIMessage.text(role: "user", content: "hi")
        let dict = try encodeMessage(msg)

        #expect(dict["role"] as? String == "user")
        #expect(dict["content"] as? String == "hi")
    }

    @Test("APIMessage.Content.blocks는 배열로 직렬화")
    func encodesAPIMessageWithBlocks() throws {
        let msg = APIMessage(
            role: "assistant",
            content: .blocks([
                .text("plan"),
                .toolUse(id: "t1", name: "read_memory", input: ["path": "p"]),
            ])
        )
        let dict = try encodeMessage(msg)

        let blocks = dict["content"] as? [[String: Any]]
        #expect(blocks?.count == 2)
        #expect(blocks?[0]["type"] as? String == "text")
        #expect(blocks?[1]["type"] as? String == "tool_use")
    }

    private func encode(_ block: APIContentBlock) throws -> [String: Any] {
        let data = try JSONEncoder().encode(block)
        return try (JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func encodeMessage(_ msg: APIMessage) throws -> [String: Any] {
        let data = try JSONEncoder().encode(msg)
        return try (JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

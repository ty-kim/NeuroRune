//
//  AnthropicSSEParserTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//

import Testing
import Foundation
@testable import NeuroRune

struct AnthropicSSEParserTests {

    @Test("content_block_delta의 text_delta는 textDelta로 파싱된다")
    func parsesTextDelta() {
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .textDelta("Hello"))
    }

    @Test("content_block_delta의 input_json_delta는 toolUseInputDelta로 파싱된다")
    func parsesInputJSONDelta() {
        let json = #"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"path\":"}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .toolUseInputDelta(index: 1, partialJSON: "{\"path\":"))
    }

    @Test("content_block_delta의 알 수 없는 delta type은 ignored")
    func ignoresUnknownDeltaType() {
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"sig"}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .ignored)
    }

    @Test("content_block_start의 tool_use는 toolUseStart로 파싱된다")
    func parsesToolUseStart() {
        let json = #"{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_x","name":"read_memory","input":{}}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .toolUseStart(index: 1, id: "toolu_x", name: "read_memory"))
    }

    @Test("content_block_start의 text 블록은 ignored")
    func ignoresTextBlockStart() {
        let json = #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .ignored)
    }

    @Test("content_block_stop은 contentBlockStop으로 파싱된다")
    func parsesContentBlockStop() {
        let json = #"{"type":"content_block_stop","index":1}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .contentBlockStop(index: 1))
    }

    @Test("message_delta는 messageDelta(stopReason:)로 파싱된다")
    func parsesMessageDelta() {
        let json = #"{"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .messageDelta(stopReason: "tool_use"))
    }

    @Test("message_stop은 stop으로 파싱된다")
    func parsesMessageStop() {
        let json = #"{"type":"message_stop"}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .stop)
    }

    @Test("error 이벤트는 error(message:)로 파싱된다")
    func parsesErrorEvent() {
        let json = #"{"type":"error","error":{"type":"overloaded_error","message":"Service overloaded"}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .error(message: "Service overloaded"))
    }

    @Test("message_start 등 기타 이벤트는 ignored")
    func ignoresUnknownEvents() {
        let json = #"{"type":"message_start","message":{"id":"msg_01"}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .ignored)
    }

    @Test("[DONE] 같은 non-JSON은 ignored")
    func ignoresNonJSON() {
        let event = AnthropicSSEParser.parseDataLine("[DONE]")

        #expect(event == .ignored)
    }
}

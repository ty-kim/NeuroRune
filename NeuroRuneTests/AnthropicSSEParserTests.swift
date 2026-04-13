//
//  AnthropicSSEParserTests.swift
//  NeuroRuneTests
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

    @Test("content_block_delta의 non-text_delta는 ignored")
    func ignoresNonTextDelta() {
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{"}}"#

        let event = AnthropicSSEParser.parseDataLine(json)

        #expect(event == .ignored)
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

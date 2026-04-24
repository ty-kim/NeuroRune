//
//  ChatSmokeTests.swift
//  NeuroRuneUITests
//
//  Created by tykim
//

import XCTest

final class ChatSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_채팅_기본_플로우_전송_후_응답_버블_노출() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-mock-llm"]
        app.launch()

        // ConversationList 진입 → 새 대화 시작 (empty/list 상태 둘 다 커버)
        let newChatButton = app.buttons.matching(identifier: "list.newChatButton").firstMatch
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5), "list.newChatButton 미노출")
        newChatButton.tap()

        // modelPicker에서 첫 모델 탭 → ChatView 진입
        let modelButton = app.buttons.matching(identifier: "modelPicker.modelButton").firstMatch
        XCTAssertTrue(modelButton.waitForExistence(timeout: 3), "modelPicker.modelButton 미노출")
        modelButton.tap()

        // 채팅 플로우
        let input = app.textFields["chat.inputField"]
        XCTAssertTrue(input.waitForExistence(timeout: 5), "chat.inputField 미노출")
        input.tap()
        input.typeText("hello")

        let sendButton = app.buttons["chat.sendButton"]
        XCTAssertTrue(sendButton.isEnabled, "sendButton 비활성")
        sendButton.tap()

        // 모든 element type 포괄 검색 (.accessibilityElement combine 때문에 type 불확정).
        let userMessage = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "hello")
        ).firstMatch
        XCTAssertTrue(userMessage.waitForExistence(timeout: 3), "user 메시지 'hello' 미노출")

        let assistantMessage = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "hi")
        ).firstMatch
        XCTAssertTrue(assistantMessage.waitForExistence(timeout: 3), "assistant 응답 'hi' 미노출")
    }
}

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
        // 테스트 간 격리: 직전 테스트의 앱 프로세스/키보드/포커스 잔재가
        // 다음 테스트로 새는 것을 차단. 새 XCUIApplication만으론 시뮬레이터
        // 상태 cleanup이 100% 보장되지 않음.
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: - Helpers

    /// ChatView 진입: ConversationList → 새 대화 → 첫 모델.
    /// 각 탭 전에 `waitForExistence`로 출현 보장 (flaky 방지).
    /// `list.newChatButton`은 emptyState + toolbar 둘 다 노출되므로 `.firstMatch`.
    @MainActor
    private func enterChatView(_ app: XCUIApplication) {
        let newChatButton = app.buttons["list.newChatButton"].firstMatch
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5), "list.newChatButton 미노출")
        newChatButton.tap()

        let modelButton = app.buttons["modelPicker.modelButton"].firstMatch
        XCTAssertTrue(modelButton.waitForExistence(timeout: 3), "modelPicker.modelButton 미노출")
        modelButton.tap()
    }

    /// role 기반 message bubble 검색 (identifier + label CONTAINS 교집합).
    /// `.descendants(.any)` 광범위 + `matching(identifier:)`로 타입 무관하게 좁힘.
    @MainActor
    private func firstMessage(
        in app: XCUIApplication,
        identifier: String,
        containing text: String
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    // MARK: - Smoke 1

    @MainActor
    func test_채팅_기본_플로우_전송_후_응답_버블_노출() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-mode", "--ui-test-mock-llm"]
        app.launch()

        enterChatView(app)

        let input = app.textFields["chat.inputField"]
        XCTAssertTrue(input.waitForExistence(timeout: 5), "chat.inputField 미노출")
        input.tap()
        input.typeText("hello")

        let sendButton = app.buttons["chat.sendButton"]
        XCTAssertTrue(sendButton.isEnabled, "sendButton 비활성")
        sendButton.tap()

        let userMessage = firstMessage(in: app, identifier: "message.bubble.user", containing: "hello")
        XCTAssertTrue(userMessage.waitForExistence(timeout: 3), "user 버블 'hello' 미노출")

        let assistantMessage = firstMessage(in: app, identifier: "message.bubble.assistant", containing: "from ui test")
        XCTAssertTrue(assistantMessage.waitForExistence(timeout: 3), "assistant 버블 미노출")
    }

    // MARK: - Smoke 2

    @MainActor
    func test_STT_전사결과_자동전송_어시스턴트_응답() throws {
        // mic 두 번 탭 race를 우회 — `--ui-test-stt-prefill`은 ChatView mount 직후
        // `.transcribed` 액션을 직접 디스패치한다. 마이크/녹음/전사 자체는 unit test가 커버.
        let app = XCUIApplication()
        app.launchArguments += [
            "--ui-test-mode",
            "--ui-test-mock-llm",
            "--ui-test-mock-stt",
            "--ui-test-stt-prefill"
        ]
        app.launch()

        enterChatView(app)

        // ChatView mount → 자동 .transcribed("voice input") → ImmediateClock countdown → sendTapped → mock LLM.
        let userMessage = firstMessage(in: app, identifier: "message.bubble.user", containing: "voice input")
        XCTAssertTrue(userMessage.waitForExistence(timeout: 5), "user 버블 'voice input' 미노출")

        let assistantMessage = firstMessage(in: app, identifier: "message.bubble.assistant", containing: "from ui test")
        XCTAssertTrue(assistantMessage.waitForExistence(timeout: 5), "assistant 버블 미노출")
    }

    // MARK: - Smoke 3

    @MainActor
    func test_Memory_Write_승인_모달_Accept_이어지는_응답() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--ui-test-mode",
            "--ui-test-mock-llm-tool-use",
            "--ui-test-mock-github"
        ]
        app.launch()

        enterChatView(app)

        let input = app.textFields["chat.inputField"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("write something")
        app.buttons["chat.sendButton"].tap()

        let approveButton = app.buttons["writeApproval.approve"]
        XCTAssertTrue(approveButton.waitForExistence(timeout: 5), "writeApproval.approve 미노출")
        approveButton.tap()

        let assistantMessage = firstMessage(in: app, identifier: "message.bubble.assistant", containing: "saved")
        XCTAssertTrue(assistantMessage.waitForExistence(timeout: 5), "assistant 버블 'saved' 미노출")
    }
}

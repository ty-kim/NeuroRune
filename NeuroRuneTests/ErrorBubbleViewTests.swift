//
//  ErrorBubbleViewTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  ErrorBubbleView의 순수 유틸(formatCountdown) 검증.
//  View 렌더링은 Preview로 수동 확인.
//

import Testing
@testable import NeuroRune

struct ErrorBubbleViewTests {

    @Test func formatCountdown은_1분_미만이면_초_단위() {
        #expect(ErrorBubbleView.formatCountdown(0) == "0s")
        #expect(ErrorBubbleView.formatCountdown(1) == "1s")
        #expect(ErrorBubbleView.formatCountdown(30) == "30s")
        #expect(ErrorBubbleView.formatCountdown(59) == "59s")
    }

    @Test func formatCountdown은_1분_이상이면_m_ss_포맷() {
        #expect(ErrorBubbleView.formatCountdown(60) == "1:00")
        #expect(ErrorBubbleView.formatCountdown(65) == "1:05")
        #expect(ErrorBubbleView.formatCountdown(125) == "2:05")
        #expect(ErrorBubbleView.formatCountdown(599) == "9:59")
    }

    @Test func formatCountdown은_10분_넘어도_m_ss() {
        #expect(ErrorBubbleView.formatCountdown(600) == "10:00")
        #expect(ErrorBubbleView.formatCountdown(3600) == "60:00")
    }
}

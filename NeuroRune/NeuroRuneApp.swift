//
//  NeuroRuneApp.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import Dependencies

@main
struct NeuroRuneApp: App {
    init() {
        Self.applyUITestDependencyOverrides()
        @Dependency(\.audioRecorder) var audioRecorder
        audioRecorder.cleanupOrphanedFiles()
        SpeechSettings.removeLegacyDefaults(from: .standard)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .background(Color("DarkNavy"))
        }
    }

    /// UI 테스트 실행 시 `--ui-test-mock-*` 플래그에 따라 dependency를 교체한다.
    /// production 실행 경로에선 `--ui-test-mode` 플래그 부재로 no-op.
    /// Mock 본체는 `UITestSupport/` DEBUG 영역.
    private static func applyUITestDependencyOverrides() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--ui-test-mode") else { return }
        #if DEBUG
        prepareDependencies { deps in
            // Keychain은 UI test mode 전체에 기본 교체 — Anthropic 키 pre-seed로 onboarding 우회.
            deps.keychainClient = .uiTestMock
            if args.contains("--ui-test-mock-llm") {
                deps.llmClient = .uiTestMock
            }
            // TODO: --ui-test-mock-stt → STTClient 교체
            // TODO: --ui-test-mock-github → GitHubClient 교체
        }
        #endif
    }
}

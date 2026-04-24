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
    /// Mock client 구현은 후속 behavioral 커밋에서 채운다.
    private static func applyUITestDependencyOverrides() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--ui-test-mode") else { return }
        prepareDependencies { _ in
            // TODO: --ui-test-mock-llm → LLMClient 교체
            // TODO: --ui-test-mock-stt → STTClient 교체
            // TODO: --ui-test-mock-github → GitHubClient 교체
        }
    }
}

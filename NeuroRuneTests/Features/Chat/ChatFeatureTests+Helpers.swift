//
//  ChatFeatureTests+Helpers.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  ChatFeatureTests 공용 빌더·Mock 의존성 헬퍼.
//  테스트 반복 코드(Message 생성, 기본 dependencies 세팅)를 1곳으로 수렴.
//

import Foundation
import ComposableArchitecture
@testable import NeuroRune

extension ChatFeatureTests {

    // MARK: - Message 빌더

    /// user 메시지 생성. createdAt은 `fixedDate`로 고정.
    static func userMsg(_ content: String) -> Message {
        Message(role: .user, content: content, createdAt: fixedDate)
    }

    /// assistant 메시지 생성. createdAt은 `fixedDate`로 고정.
    static func assistantMsg(_ content: String = "") -> Message {
        Message(role: .assistant, content: content, createdAt: fixedDate)
    }

    // MARK: - 기본 Mock Dependencies

    /// sendTapped가 동작하려면 llmClient·conversationStore·githubCredentialsClient가
    /// 모두 필요하다. 대부분 테스트는 "영향 없는 기본값"만 필요하므로 이 헬퍼로 일괄 세팅.
    ///
    /// 커스텀 필요 시 withDependencies 블록에서 개별 override:
    /// ```swift
    /// } withDependencies: {
    ///     applyDefaultDependencies(&$0)
    ///     $0.llmClient.streamMessage = { ... 커스텀 ... }
    /// }
    /// ```
    func applyDefaultDependencies(_ deps: inout DependencyValues) {
        deps.date = .constant(Self.fixedDate)
        deps.llmClient.streamMessage = { @Sendable _, _, _, _, _ in
            AsyncThrowingStream { $0.finish() }
        }
        deps.conversationStore.save = { @Sendable _ in }
        deps.githubCredentialsClient.load = { @Sendable _ in nil }
    }
}

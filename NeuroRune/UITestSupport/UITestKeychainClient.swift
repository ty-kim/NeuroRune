//
//  UITestKeychainClient.swift
//  NeuroRune
//
//  Created by tykim
//

#if DEBUG
import Foundation

extension KeychainClient {
    /// UI 테스트 전용 in-memory keychain stub.
    /// `--ui-test-mode` 플래그로 활성화.
    /// 실제 Keychain 오염 없이 UI 플로우 검증.
    /// Anthropic API 키를 pre-seed해 onboarding을 우회.
    static let uiTestMock: KeychainClient = {
        let storage = UITestKeychainStorage()
        storage.set(
            key: AnthropicCredentialsFeature.anthropicKeyName,
            value: "sk-ant-ui-test-fake"
        )
        return KeychainClient(
            save: { key, value in storage.set(key: key, value: value) },
            load: { key in storage.get(key: key) },
            delete: { key in storage.delete(key: key) }
        )
    }()
}

nonisolated private final class UITestKeychainStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var dict: [String: String] = [:]

    func set(key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        dict[key] = value
    }

    func get(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return dict[key]
    }

    func delete(key: String) {
        lock.lock()
        defer { lock.unlock() }
        dict.removeValue(forKey: key)
    }
}
#endif

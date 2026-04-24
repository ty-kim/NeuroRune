//
//  UITestGitHubClient.swift
//  NeuroRune
//
//  Created by tykim
//

#if DEBUG
import Foundation

extension GitHubClient {
    /// UI 테스트 전용 GitHub stub.
    /// `--ui-test-mock-github` 플래그로 활성화.
    /// saveFile은 입력 path/content 그대로 반영한 파일 반환, loadFile은 빈 파일(신규 취급).
    static let uiTestMock = GitHubClient(
        listContents: { _, _ in [] },
        loadFile: { _, path in
            GitHubFile(path: path, sha: "ui-test-sha", content: "", isDirectory: false)
        },
        saveFile: { _, path, content, _, _ in
            GitHubFile(path: path, sha: "ui-test-saved-sha", content: content, isDirectory: false)
        },
        deleteFile: { _, _, _, _ in }
    )
}
#endif

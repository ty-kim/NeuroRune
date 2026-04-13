//
//  GitHubFile.swift
//  NeuroRune
//

import Foundation

nonisolated struct GitHubFile: Equatable, Hashable, Sendable, Identifiable {
    let path: String
    let sha: String
    /// Base64 디코딩된 평문. 디렉터리 응답일 땐 빈 문자열.
    let content: String
    let isDirectory: Bool

    var id: String { path }
    var name: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

nonisolated struct GitHubRepoConfig: Equatable, Sendable {
    let owner: String
    let repo: String
    let branch: String

    init(owner: String, repo: String, branch: String = "main") {
        self.owner = owner
        self.repo = repo
        self.branch = branch
    }
}

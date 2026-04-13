//
//  GitHubCredentials.swift
//  NeuroRune
//

import Foundation

nonisolated struct GitHubCredentials: Codable, Equatable, Sendable {
    let pat: String
    let owner: String
    let repo: String
    let branch: String

    var repoConfig: GitHubRepoConfig {
        GitHubRepoConfig(owner: owner, repo: repo, branch: branch)
    }

    init(pat: String, owner: String, repo: String, branch: String = "main") {
        self.pat = pat
        self.owner = owner
        self.repo = repo
        self.branch = branch
    }

    var isValid: Bool {
        !pat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

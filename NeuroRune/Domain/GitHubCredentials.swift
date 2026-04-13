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
    /// repo 안에서 메모리 파일이 위치할 경로. 빈 문자열이면 repo 루트.
    let path: String

    var repoConfig: GitHubRepoConfig {
        GitHubRepoConfig(owner: owner, repo: repo, branch: branch)
    }

    init(pat: String, owner: String, repo: String, branch: String = "main", path: String = "") {
        self.pat = pat
        self.owner = owner
        self.repo = repo
        self.branch = branch
        self.path = path
    }

    // 기존 저장된 creds(이전 path 필드 없음)과의 호환을 위해 커스텀 decode.
    enum CodingKeys: String, CodingKey {
        case pat, owner, repo, branch, path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pat = try container.decode(String.self, forKey: .pat)
        owner = try container.decode(String.self, forKey: .owner)
        repo = try container.decode(String.self, forKey: .repo)
        branch = try container.decodeIfPresent(String.self, forKey: .branch) ?? "main"
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
    }

    var isValid: Bool {
        !pat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

//
//  GitHubClientLive.swift
//  NeuroRune
//

import Foundation
import os

nonisolated extension GitHubClient {

    /// URLSession + PAT 기반 실제 GitHub REST 구현.
    static func live(session: URLSession, pat: String) -> GitHubClient {
        GitHubClient(
            listContents: { config, path in
                let request = makeRequest(config: config, path: path, method: "GET", pat: pat, body: nil)
                let (data, response) = try await performData(request: request, session: session)
                try validateStatus(response, data: data)

                // 디렉터리는 배열, 파일 단일은 단일 객체. 우선 배열 시도 → 실패 시 단일.
                if let items = try? JSONDecoder().decode([GitHubContentItem].self, from: data) {
                    return items.map { $0.toMetadata() }
                }
                if let item = try? JSONDecoder().decode(GitHubContentItem.self, from: data) {
                    return [item.toMetadata()]
                }
                throw GitHubError.decoding("unexpected contents response shape")
            },
            loadFile: { config, path in
                let request = makeRequest(config: config, path: path, method: "GET", pat: pat, body: nil)
                let (data, response) = try await performData(request: request, session: session)
                try validateStatus(response, data: data)

                let item: GitHubContentItem
                do {
                    item = try JSONDecoder().decode(GitHubContentItem.self, from: data)
                } catch {
                    throw GitHubError.decoding(String(describing: error))
                }
                return try item.toFileWithContent()
            },
            saveFile: { config, path, content, sha, message in
                var body: [String: Any] = [
                    "message": message,
                    "content": Data(content.utf8).base64EncodedString(),
                    "branch": config.branch
                ]
                if let sha {
                    body["sha"] = sha
                }
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                let request = makeRequest(config: config, path: path, method: "PUT", pat: pat, body: bodyData)
                let (data, response) = try await performData(request: request, session: session)
                try validateStatus(response, data: data)

                struct SaveResponse: Decodable {
                    let content: GitHubContentItem
                }
                let parsed: SaveResponse
                do {
                    parsed = try JSONDecoder().decode(SaveResponse.self, from: data)
                } catch {
                    throw GitHubError.decoding(String(describing: error))
                }
                // 서버가 돌려주는 content 필드엔 payload content가 없음. 로컬 content 결합.
                var file = parsed.content.toMetadata()
                file = GitHubFile(
                    path: file.path,
                    sha: file.sha,
                    content: content,
                    isDirectory: false
                )
                return file
            },
            deleteFile: { config, path, sha, message in
                let body: [String: Any] = [
                    "message": message,
                    "sha": sha,
                    "branch": config.branch
                ]
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                let request = makeRequest(config: config, path: path, method: "DELETE", pat: pat, body: bodyData)
                let (data, response) = try await performData(request: request, session: session)
                try validateStatus(response, data: data)
            }
        )
    }
}

// MARK: - Request builder

private nonisolated func makeRequest(
    config: GitHubRepoConfig,
    path: String,
    method: String,
    pat: String,
    body: Data?
) -> URLRequest {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.github.com"
    components.percentEncodedPath = encodeContentsPath(config: config, path: path)
    if method == "GET" {
        components.queryItems = [URLQueryItem(name: "ref", value: config.branch)]
    }

    var request = URLRequest(url: components.url!)
    request.httpMethod = method
    request.setValue("Bearer \(pat)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    return request
}

/// `/repos/{owner}/{repo}/contents/{path}`의 각 segment를 percent-encoding.
/// 공백/한글/괄호 등 GitHub가 허용하는 특수문자 파일명에서 404 방지.
private nonisolated func encodeContentsPath(config: GitHubRepoConfig, path: String) -> String {
    let fixedSegments = ["repos", config.owner, config.repo, "contents"]
    let pathSegments = path.split(separator: "/").map(String.init)
    let allSegments = fixedSegments + pathSegments
    let encoded = allSegments.map {
        $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0
    }
    return "/" + encoded.joined(separator: "/")
}

// MARK: - Response types

private nonisolated struct GitHubContentItem: Decodable {
    let name: String
    let path: String
    let sha: String
    let type: String
    let content: String?
    let encoding: String?

    /// content 없이 메타데이터만. 디렉터리 listing/save 응답용.
    func toMetadata() -> GitHubFile {
        GitHubFile(
            path: path,
            sha: sha,
            content: "",
            isDirectory: type == "dir"
        )
    }

    /// content 디코딩 포함. loadFile 응답용. 실패 시 명시적 throw — 데이터 손실
    /// (빈 문자열로 덮어쓰기) 방지.
    func toFileWithContent() throws -> GitHubFile {
        // 디렉터리는 content 필요 없음
        if type == "dir" {
            return toMetadata()
        }
        guard let encoding, encoding == "base64" else {
            // GitHub Contents API: 1MB 초과 시 encoding="none", content=""
            throw GitHubError.unsupportedEncoding(encoding ?? "missing")
        }
        guard let content else {
            throw GitHubError.invalidBase64
        }
        let cleaned = content.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleaned),
              let text = String(data: data, encoding: .utf8) else {
            throw GitHubError.invalidBase64
        }
        return GitHubFile(
            path: path,
            sha: sha,
            content: text,
            isDirectory: false
        )
    }
}

// MARK: - Status + errors

private nonisolated func performData(
    request: URLRequest,
    session: URLSession
) async throws -> (Data, URLResponse) {
    do {
        return try await session.data(for: request)
    } catch let urlError as URLError {
        throw GitHubError.network(urlError.localizedDescription)
    } catch {
        throw GitHubError.network(error.localizedDescription)
    }
}

private nonisolated func validateStatus(_ response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse else {
        throw GitHubError.network("non-http response")
    }
    switch http.statusCode {
    case 200..<300:
        return
    case 401:
        throw GitHubError.unauthorized
    case 403:
        // rate limit indicator in header; 403 without rate limit also generic forbidden
        if http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
            throw GitHubError.rateLimited
        }
        throw GitHubError.server(status: 403, message: extractMessage(data: data))
    case 404:
        throw GitHubError.notFound
    case 409, 422:
        throw GitHubError.conflict
    default:
        throw GitHubError.server(status: http.statusCode, message: extractMessage(data: data))
    }
}

private nonisolated func extractMessage(data: Data) -> String {
    struct Err: Decodable { let message: String? }
    if let err = try? JSONDecoder().decode(Err.self, from: data), let m = err.message {
        return m
    }
    return String(data: data, encoding: .utf8) ?? "unknown"
}

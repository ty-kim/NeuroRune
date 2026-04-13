//
//  GitHubClientLiveTests.swift
//  NeuroRuneTests
//
//  GitHubClient.live(session:pat:) 통합 테스트.
//  URLProtocolStub로 REST 응답 주입, CRUD 경로 및 상태 매핑 검증.
//

import Testing
import Foundation
@testable import NeuroRune

@Suite(.serialized)
struct GitHubClientLiveTests {

    init() {
        URLProtocolStub.reset()
    }

    static let config = GitHubRepoConfig(owner: "ty-kim", repo: "memory")

    // MARK: - listContents

    @Test("listContents: 디렉터리 응답을 GitHubFile 배열로 변환한다")
    func listContentsParsesDirectoryArray() async throws {
        let body = """
        [
          {"name":"a.md","path":"memory/a.md","sha":"sha-a","type":"file","encoding":null,"content":null},
          {"name":"b.md","path":"memory/b.md","sha":"sha-b","type":"file","encoding":null,"content":null},
          {"name":"sub","path":"memory/sub","sha":"sha-sub","type":"dir","encoding":null,"content":null}
        ]
        """
        stubStatus(200, body: body)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        let result = try await client.listContents(Self.config, "memory")

        #expect(result.count == 3)
        #expect(result[0].path == "memory/a.md")
        #expect(result[0].sha == "sha-a")
        #expect(result[0].isDirectory == false)
        #expect(result[2].isDirectory == true)
    }

    @Test("파일명의 공백/한글은 URL 경로에서 percent-encoding된다")
    func pathWithSpecialCharsIsPercentEncoded() async throws {
        stubStatus(200, body: "[]")
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        _ = try await client.listContents(Self.config, "memory/my note 한글.md")

        let url = URLProtocolStub.lastRequest?.url?.absoluteString
        #expect(url?.contains("%20") == true) // space → %20
        #expect(url?.contains(" ") == false)  // literal space 없어야 함
        #expect(url?.contains("한글") == false) // 한글 literal도 인코딩됨
    }

    @Test("listContents: Authorization 헤더에 Bearer <pat>이 설정된다")
    func listContentsSetsBearerAuth() async throws {
        stubStatus(200, body: "[]")
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_xyz")

        _ = try await client.listContents(Self.config, "memory")

        let auth = URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(auth == "Bearer ghp_xyz")
    }

    // MARK: - loadFile

    @Test("loadFile: Base64 content를 평문으로 디코딩한다")
    func loadFileDecodesBase64Content() async throws {
        let plain = "# Hello\n\nSample."
        let encoded = Data(plain.utf8).base64EncodedString()
        let body = """
        {"name":"a.md","path":"memory/a.md","sha":"sha-a","type":"file","encoding":"base64","content":"\(encoded)"}
        """
        stubStatus(200, body: body)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        let file = try await client.loadFile(Self.config, "memory/a.md")

        #expect(file.path == "memory/a.md")
        #expect(file.sha == "sha-a")
        #expect(file.content == plain)
    }

    // MARK: - saveFile

    @Test("saveFile: sha 없이 신규 생성하면 body에 sha가 없고 content는 Base64")
    func saveFileNewOmitsSha() async throws {
        let responseBody = """
        {"content":{"name":"a.md","path":"memory/a.md","sha":"new-sha","type":"file","encoding":null,"content":null}}
        """
        stubStatus(201, body: responseBody)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        let file = try await client.saveFile(Self.config, "memory/a.md", "hello world", nil, "add a")

        #expect(file.sha == "new-sha")
        #expect(file.content == "hello world") // 로컬 payload 결합

        let bodyJSON = try decodeRequestBody()
        #expect(bodyJSON["sha"] == nil)
        #expect(bodyJSON["message"] as? String == "add a")
        let encoded = Data("hello world".utf8).base64EncodedString()
        #expect(bodyJSON["content"] as? String == encoded)
    }

    @Test("saveFile: sha 지정 시 body에 sha 포함 (업데이트)")
    func saveFileUpdateIncludesSha() async throws {
        let responseBody = """
        {"content":{"name":"a.md","path":"memory/a.md","sha":"updated-sha","type":"file","encoding":null,"content":null}}
        """
        stubStatus(200, body: responseBody)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        _ = try await client.saveFile(Self.config, "memory/a.md", "new content", "old-sha", "update a")

        let bodyJSON = try decodeRequestBody()
        #expect(bodyJSON["sha"] as? String == "old-sha")
    }

    // MARK: - deleteFile

    @Test("deleteFile: body에 sha + message 포함")
    func deleteFileIncludesShaAndMessage() async throws {
        stubStatus(200, body: #"{"commit":{}}"#)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        try await client.deleteFile(Self.config, "memory/a.md", "some-sha", "remove a")

        let bodyJSON = try decodeRequestBody()
        #expect(bodyJSON["sha"] as? String == "some-sha")
        #expect(bodyJSON["message"] as? String == "remove a")

        let method = URLProtocolStub.lastRequest?.httpMethod
        #expect(method == "DELETE")
    }

    // MARK: - Error mapping

    @Test("401 → GitHubError.unauthorized")
    func mapsUnauthorized() async throws {
        stubStatus(401, body: #"{"message":"Bad credentials"}"#)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_bad")

        await #expect(throws: GitHubError.unauthorized) {
            _ = try await client.listContents(Self.config, "memory")
        }
    }

    @Test("404 → GitHubError.notFound")
    func mapsNotFound() async throws {
        stubStatus(404, body: #"{"message":"Not Found"}"#)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        await #expect(throws: GitHubError.notFound) {
            _ = try await client.loadFile(Self.config, "memory/missing.md")
        }
    }

    @Test("403 + X-RateLimit-Remaining:0 → GitHubError.rateLimited")
    func mapsRateLimited() async throws {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "X-RateLimit-Remaining": "0"
                ]
            )!
            return (http, Data(#"{"message":"rate limit"}"#.utf8), nil)
        }
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        await #expect(throws: GitHubError.rateLimited) {
            _ = try await client.listContents(Self.config, "memory")
        }
    }

    @Test("422 → GitHubError.conflict (sha mismatch)")
    func mapsConflict() async throws {
        stubStatus(422, body: #"{"message":"sha mismatch"}"#)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        await #expect(throws: GitHubError.conflict) {
            _ = try await client.saveFile(Self.config, "memory/a.md", "x", "stale-sha", "update")
        }
    }

    @Test("5xx → GitHubError.server(status:)")
    func mapsServerError() async throws {
        stubStatus(503, body: #"{"message":"unavailable"}"#)
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        await #expect {
            _ = try await client.listContents(Self.config, "memory")
        } throws: { error in
            guard case GitHubError.server(let status, _) = error else { return false }
            return status == 503
        }
    }

    @Test("URLError → GitHubError.network")
    func mapsNetworkError() async throws {
        URLProtocolStub.setHandler { request in
            let dummy = HTTPURLResponse(url: request.url!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (dummy, nil, URLError(.timedOut))
        }
        let client = GitHubClient.live(session: Self.makeSession(), pat: "ghp_test")

        await #expect {
            _ = try await client.listContents(Self.config, "memory")
        } throws: { error in
            guard case GitHubError.network = error else { return false }
            return true
        }
    }

    // MARK: - Helpers

    static func makeSession() -> URLSession {
        URLProtocolStub.makeSession()
    }

    private func stubStatus(_ status: Int, body: String) {
        URLProtocolStub.setHandler { request in
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (http, Data(body.utf8), nil)
        }
    }

    private func decodeRequestBody() throws -> [String: Any] {
        guard let data = URLProtocolStub.lastRequest?.httpBodyStream?.readAllData()
                ?? URLProtocolStub.lastRequest?.httpBody else {
            throw DecodeErr.noBody
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodeErr.notJSON
        }
        return json
    }

    enum DecodeErr: Error { case noBody, notJSON }
}

private extension InputStream {
    func readAllData() -> Data {
        open()
        defer { close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while hasBytesAvailable {
            let read = self.read(buffer, maxLength: bufferSize)
            if read > 0 { data.append(buffer, count: read) }
            else { break }
        }
        return data
    }
}

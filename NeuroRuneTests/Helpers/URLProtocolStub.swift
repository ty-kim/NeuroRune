//
//  URLProtocolStub.swift
//  NeuroRuneTests
//
//  URLSession 기반 HTTP 요청을 테스트에서 가로채기 위한 stub.
//  테스트마다 `Stub()` 인스턴스를 만들면 각자의 session + handler를 갖는다.
//  X-URLProtocolStub-ID 헤더로 라우팅해 Swift Testing 병렬 실행에서도 격리.
//

import Foundation
import os

typealias StubResponseHandler = @Sendable (URLRequest) -> (HTTPURLResponse, Data?, Error?)

nonisolated final class URLProtocolStub: URLProtocol {

    struct Stub {
        let id: String
        let session: URLSession

        init() {
            id = UUID().uuidString
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [URLProtocolStub.self]
            config.httpAdditionalHeaders = [URLProtocolStub.stubIDHeader: id]
            session = URLSession(configuration: config)
            URLProtocolStub.register(id: id)
        }

        func setHandler(_ handler: @escaping StubResponseHandler) {
            URLProtocolStub.setHandler(handler, for: id)
        }

        var lastRequest: URLRequest? {
            URLProtocolStub.lastRequest(for: id)
        }
    }

    private struct SessionStubState: Sendable {
        var handler: StubResponseHandler?
        var lastRequest: URLRequest?
    }

    private struct StubState: Sendable {
        var sessions: [String: SessionStubState] = [:]
    }

    private static let state = OSAllocatedUnfairLock<StubState>(initialState: StubState())
    private static let stubIDHeader = "X-URLProtocolStub-ID"

    fileprivate static func setHandler(_ handler: @escaping StubResponseHandler, for id: String) {
        state.withLock {
            var session = $0.sessions[id] ?? SessionStubState()
            session.handler = handler
            $0.sessions[id] = session
        }
    }

    fileprivate static func lastRequest(for id: String) -> URLRequest? {
        state.withLock { $0.sessions[id]?.lastRequest }
    }

    fileprivate static func register(id: String) {
        state.withLock {
            $0.sessions[id] = SessionStubState()
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let currentRequest = self.request
        guard let stubID = currentRequest.value(forHTTPHeaderField: Self.stubIDHeader) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotLoadFromNetwork))
            return
        }

        let handler = URLProtocolStub.state.withLock { state -> StubResponseHandler? in
            var session = state.sessions[stubID] ?? SessionStubState()
            session.lastRequest = currentRequest
            state.sessions[stubID] = session
            return session.handler
        }

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotLoadFromNetwork))
            return
        }

        let (response, data, error) = handler(request)

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

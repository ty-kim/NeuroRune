//
//  URLProtocolStub.swift
//  NeuroRuneTests
//
//  URLSession 기반 HTTP 요청을 테스트에서 가로채기 위한 stub.
//  URLProtocol은 sync 계약이라 actor로 감쌀 수 없으므로
//  OSAllocatedUnfairLock으로 shared state를 보호한다.
//

import Foundation
import os

typealias StubResponseHandler = @Sendable (URLRequest) -> (HTTPURLResponse, Data?, Error?)

final class URLProtocolStub: URLProtocol {

    private struct StubState: Sendable {
        var handler: StubResponseHandler?
        var lastRequest: URLRequest?
    }

    private static let state = OSAllocatedUnfairLock<StubState>(initialState: StubState())

    static func setHandler(_ handler: @escaping StubResponseHandler) {
        state.withLock { $0.handler = handler }
    }

    static var lastRequest: URLRequest? {
        state.withLock { $0.lastRequest }
    }

    static func reset() {
        state.withLock {
            $0.handler = nil
            $0.lastRequest = nil
        }
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let currentRequest = self.request
        let handler = URLProtocolStub.state.withLock { state -> StubResponseHandler? in
            state.lastRequest = currentRequest
            return state.handler
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

//
//  STTDomainTests.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  STTResult, STTError, NCPCredentials 도메인 테스트.
//

import Foundation
import Testing
@testable import NeuroRune

struct STTResultTests {
    @Test func STTResult_text_기본_필드() {
        let r = STTResult(text: "hello world")
        #expect(r.text == "hello world")
    }

    @Test func STTResult는_동일_내용_동등() {
        #expect(STTResult(text: "a") == STTResult(text: "a"))
        #expect(STTResult(text: "a") != STTResult(text: "b"))
    }
}

struct STTErrorTests {
    @Test func isRetryable_세_케이스는_false() {
        #expect(STTError.microphonePermissionDenied.isRetryable == false)
        #expect(STTError.audioTooLong.isRetryable == false)
        #expect(STTError.cancelled.isRetryable == false)
    }

    @Test func isRetryable_나머지는_true() {
        #expect(STTError.recordingFailed("x").isRetryable == true)
        #expect(STTError.network("x").isRetryable == true)
        #expect(STTError.unauthorized.isRetryable == true)
        #expect(STTError.rateLimited.isRetryable == true)
        #expect(STTError.server(status: 500, message: "x").isRetryable == true)
        #expect(STTError.decoding("x").isRetryable == true)
    }

    @Test func userMessageKey_각_케이스별_고유_키() {
        #expect(STTError.microphonePermissionDenied.userMessageKey == "stt.error.mic_permission")
        #expect(STTError.recordingFailed("").userMessageKey == "stt.error.recording")
        #expect(STTError.audioTooLong.userMessageKey == "stt.error.audio_too_long")
        #expect(STTError.network("").userMessageKey == "stt.error.network")
        #expect(STTError.unauthorized.userMessageKey == "stt.error.unauthorized")
        #expect(STTError.rateLimited.userMessageKey == "stt.error.rate_limited")
        #expect(STTError.server(status: 500, message: "").userMessageKey == "stt.error.server")
        #expect(STTError.decoding("").userMessageKey == "stt.error.decoding")
        #expect(STTError.cancelled.userMessageKey == "stt.error.cancelled")
    }

    @Test func Equatable_동일_케이스_동일_값() {
        #expect(STTError.cancelled == STTError.cancelled)
        #expect(STTError.recordingFailed("a") == STTError.recordingFailed("a"))
        #expect(STTError.recordingFailed("a") != STTError.recordingFailed("b"))
        #expect(STTError.server(status: 500, message: "x") == STTError.server(status: 500, message: "x"))
        #expect(STTError.server(status: 500, message: "x") != STTError.server(status: 503, message: "x"))
    }
}

struct NCPCredentialsTests {
    @Test func 둘다_있으면_유효() {
        let c = NCPCredentials(apiKeyID: "id1", apiKey: "secret1")
        #expect(c.isValid == true)
    }

    @Test func 하나라도_비면_무효() {
        #expect(NCPCredentials(apiKeyID: "", apiKey: "x").isValid == false)
        #expect(NCPCredentials(apiKeyID: "x", apiKey: "").isValid == false)
    }

    @Test func 공백만_있으면_무효() {
        #expect(NCPCredentials(apiKeyID: "   ", apiKey: "x").isValid == false)
        #expect(NCPCredentials(apiKeyID: "x", apiKey: " \n ").isValid == false)
    }

    @Test func Equatable() {
        let a = NCPCredentials(apiKeyID: "id", apiKey: "key")
        let b = NCPCredentials(apiKeyID: "id", apiKey: "key")
        let c = NCPCredentials(apiKeyID: "id2", apiKey: "key")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func Keychain_키_이름_고정() {
        #expect(NCPCredentials.KeychainKey.apiKeyID == "ncp.apiKeyID")
        #expect(NCPCredentials.KeychainKey.apiKey == "ncp.apiKey")
    }
}

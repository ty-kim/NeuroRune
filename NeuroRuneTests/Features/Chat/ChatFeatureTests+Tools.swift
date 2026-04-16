//
//  ChatFeatureTests+Tools.swift
//  NeuroRuneTests
//
//  Created by tykim
//
//  Tool 호출 (read_memory / write_memory) 관련 ChatFeature 테스트.
//  - write_memory 승인 gate
//  - tool use lifecycle (activeToolCalls)
//  - 멀티턴 루프
//

import Testing
import Foundation
import ComposableArchitecture
@testable import NeuroRune

extension ChatFeatureTests {

    // MARK: - Write Approval

    @Test("writeApprovalRequested는 pendingWrite 세팅")
    func writeApprovalRequestedSetsPending() async {
        let req = ChatFeature.WriteRequest(
            id: "w1", role: .global, path: "runes/new.md",
            content: "body", commitMessage: "init"
        )
        let store = TestStore(initialState: makeState()) { ChatFeature() }

        await store.send(.writeApprovalRequested(req)) {
            $0.pendingWrite = req
        }
    }

    @Test("writeApproved는 pendingWrite를 nil로 + gate.setApproval 호출")
    func writeApprovedClearsAndCallsGate() async {
        let setId = LockIsolated<String?>(nil)
        let setDecision = LockIsolated<WriteDecision?>(nil)
        var state = makeState()
        state.pendingWrite = ChatFeature.WriteRequest(
            id: "w1", role: .global, path: "p",
            content: "c", commitMessage: "m"
        )

        let store = TestStore(initialState: state) {
            ChatFeature()
        } withDependencies: {
            $0.writeApprovalGate.setApproval = { @Sendable id, decision in
                setId.setValue(id)
                setDecision.setValue(decision)
            }
        }

        await store.send(.writeApproved(id: "w1")) {
            $0.pendingWrite = nil
        }
        await store.finish()
        #expect(setId.value == "w1")
        #expect(setDecision.value == .approve)
    }

    @Test("writeRejected는 pendingWrite를 nil로 + gate.setApproval(reject)")
    func writeRejectedClearsAndCallsGate() async {
        let setDecision = LockIsolated<WriteDecision?>(nil)
        var state = makeState()
        state.pendingWrite = ChatFeature.WriteRequest(
            id: "w1", role: .global, path: "p",
            content: "c", commitMessage: "m"
        )

        let store = TestStore(initialState: state) {
            ChatFeature()
        } withDependencies: {
            $0.writeApprovalGate.setApproval = { @Sendable _, decision in
                setDecision.setValue(decision)
            }
        }

        await store.send(.writeRejected(id: "w1", reason: "nope")) {
            $0.pendingWrite = nil
        }
        await store.finish()
        #expect(setDecision.value == .reject(reason: "nope"))
    }

    // MARK: - Tool Use Lifecycle

    @Test("toolUseRequested 액션은 activeToolCalls에 추가된다")
    func toolUseRequestedAddsToActive() async {
        let store = TestStore(initialState: makeState()) {
            ChatFeature()
        }

        await store.send(.toolUseRequested(id: "t1", name: "read_memory", input: ["path": "MEMORY.md"])) {
            $0.activeToolCalls = [
                ChatFeature.ToolCallStatus(id: "t1", name: "read_memory", input: ["path": "MEMORY.md"])
            ]
        }
    }

    @Test("toolUseCompleted 액션은 activeToolCalls에서 제거한다")
    func toolUseCompletedRemovesFromActive() async {
        var state = makeState()
        state.activeToolCalls = [
            ChatFeature.ToolCallStatus(id: "t1", name: "read_memory", input: ["path": "a.md"]),
            ChatFeature.ToolCallStatus(id: "t2", name: "read_memory", input: ["path": "b.md"]),
        ]
        let store = TestStore(initialState: state) {
            ChatFeature()
        }

        await store.send(.toolUseCompleted(id: "t1")) {
            $0.activeToolCalls = [
                ChatFeature.ToolCallStatus(id: "t2", name: "read_memory", input: ["path": "b.md"])
            ]
        }
    }

    // MARK: - Multi-turn Tool Loop

    @Test("멀티턴 루프는 tool 실행 전 toolUseRequested, 완료 후 toolUseCompleted 발행")
    func multiTurnDispatchesToolUseLifecycleActions() async {
        let callCount = LockIsolated<Int>(0)

        let store = TestStore(initialState: makeState(inputText: "hi")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable _, _, _, _, _ in
                let n = callCount.value
                callCount.setValue(n + 1)
                return AsyncThrowingStream { continuation in
                    if n == 0 {
                        continuation.yield(.toolUseRequest(
                            id: "t1",
                            name: "read_memory",
                            inputJSON: #"{"role":"global","path":"x.md"}"#
                        ))
                    } else {
                        continuation.yield(.textDelta("done"))
                    }
                    continuation.finish()
                }
            }
            $0.githubClient.loadFile = { @Sendable _, _ in
                GitHubFile(path: "x.md", sha: "s", content: "x", isDirectory: false)
            }
            $0.githubCredentialsClient.load = { @Sendable role in
                GitHubCredentials(role: role, pat: "p", owner: "o", repo: "r")
            }
            $0.conversationStore.save = { @Sendable _ in }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation
                .appending(Self.userMsg("hi"))
                .appending(Self.assistantMsg())
            $0.inputText = ""
            $0.isStreaming = true
        }

        await store.receive(.toolUseRequested(
            id: "t1",
            name: "read_memory",
            input: ["role": "global", "path": "x.md"]
        )) {
            $0.activeToolCalls = [
                ChatFeature.ToolCallStatus(id: "t1", name: "read_memory", input: ["role": "global", "path": "x.md"])
            ]
        }
        await store.receive(.toolUseCompleted(id: "t1")) {
            $0.activeToolCalls = []
        }
        await store.receive(.streamChunkReceived("done")) {
            var msgs = $0.conversation.messages
            msgs[msgs.count - 1] = Self.assistantMsg("done")
            $0.conversation.messages = msgs
        }
        await store.receive(.streamFinished) {
            $0.isStreaming = false
        }
        await store.finish()
    }

    @Test("sendTapped는 toolUseRequest 받으면 read_memory 실행하고 다음 라운드로 이어감")
    func multiTurnExecutesReadMemoryAndContinues() async {
        let callCount = LockIsolated<Int>(0)
        let secondRoundMessageCount = LockIsolated<Int?>(nil)
        let toolFetchPath = LockIsolated<String?>(nil)

        let store = TestStore(initialState: makeState(inputText: "hi")) {
            ChatFeature()
        } withDependencies: {
            $0.date = .constant(Self.fixedDate)
            $0.llmClient.streamMessage = { @Sendable msgs, _, _, _, tools in
                let n = callCount.value
                callCount.setValue(n + 1)
                if n == 1 {
                    secondRoundMessageCount.setValue(msgs.count)
                }
                return AsyncThrowingStream { continuation in
                    if n == 0 {
                        continuation.yield(.textDelta("checking"))
                        continuation.yield(.toolUseRequest(
                            id: "t1",
                            name: "read_memory",
                            inputJSON: #"{"role":"global","path":"runes/profile.md"}"#
                        ))
                    } else {
                        continuation.yield(.textDelta(" done"))
                    }
                    _ = tools
                    continuation.finish()
                }
            }
            $0.githubClient.loadFile = { @Sendable _, path in
                toolFetchPath.setValue(path)
                return GitHubFile(path: path, sha: "s", content: "fetched body", isDirectory: false)
            }
            $0.githubCredentialsClient.load = { @Sendable role in
                GitHubCredentials(role: role, pat: "p", owner: "o", repo: "r-\(role.rawValue)")
            }
            $0.conversationStore.save = { @Sendable _ in }
        }

        await store.send(.sendTapped) {
            $0.conversation = $0.conversation
                .appending(Self.userMsg("hi"))
                .appending(Self.assistantMsg())
            $0.inputText = ""
            $0.isStreaming = true
        }

        // Round 1 text
        await store.receive(.streamChunkReceived("checking")) {
            var msgs = $0.conversation.messages
            msgs[msgs.count - 1] = Self.assistantMsg("checking")
            $0.conversation.messages = msgs
        }

        // tool lifecycle
        await store.receive(.toolUseRequested(
            id: "t1",
            name: "read_memory",
            input: ["role": "global", "path": "runes/profile.md"]
        )) {
            $0.activeToolCalls = [
                ChatFeature.ToolCallStatus(id: "t1", name: "read_memory", input: ["role": "global", "path": "runes/profile.md"])
            ]
        }
        await store.receive(.toolUseCompleted(id: "t1")) {
            $0.activeToolCalls = []
        }

        // Round 2 text (after tool execution + new turn)
        await store.receive(.streamChunkReceived(" done")) {
            var msgs = $0.conversation.messages
            msgs[msgs.count - 1] = Self.assistantMsg("checking done")
            $0.conversation.messages = msgs
        }

        await store.receive(.streamFinished) {
            $0.isStreaming = false
        }

        await store.finish()
        #expect(callCount.value == 2)
        #expect(toolFetchPath.value == "runes/profile.md")
        // Round 2: [user text, assistant(text+tool_use), user(tool_result)] = 3
        #expect(secondRoundMessageCount.value == 3)
    }
}

# Sprint 1 — Chat (Apr 11-15)

Sprint 1 범위: Anthropic API 클라이언트 + Keychain 키 저장 + 채팅 세션 영속화 + 마크다운 렌더링 + 세션 단위 모델 선택.

## Workflow

- TDD cycle: Red → Green → Refactor
- 본 파일의 unmarked `[ ]` 테스트를 순서대로 구현한다
- "go"라고 하면 다음 unmarked 테스트 하나를 구현 → 해당 테스트만 통과하는 최소 코드 작성 → 전체 테스트 재실행
- 구조 변경(Tidy First)과 동작 변경은 별도 커밋
- 테스트는 Swift Testing, 외부 I/O는 `URLProtocol` 기반 stub 사용
- 테스트 통과 + 경고 0 상태에서만 커밋 제안

## 아키텍처 레이어 (의존성 순서)

```
Domain (Message, Conversation, LLMModel, LLMError)
    ↑
Client Protocol (LLMClient, KeychainClient, ConversationStore)
    ↑
Client Impl (AnthropicClient, LiveKeychainClient, LiveConversationStore)
    ↑
TCA Feature (ChatFeature, OnboardingFeature, ModelPickerFeature)
    ↑
View (ChatView, OnboardingView, 마크다운 렌더링)
```

각 Phase는 아래에서 위로 쌓는다. 하위 레이어가 통과한 뒤 다음 Phase로.

---

## Phase 1 — Domain Models

순수 값 타입. 외부 의존성 없음. 가장 쉽게 Red→Green.

- [x] `Message`는 role(`.user`/`.assistant`), content(String), createdAt(Date)를 가진다
- [x] `Conversation`은 id(UUID), title(String), messages([Message]), modelId(String), createdAt(Date)를 가진다
- [x] `Conversation.empty(modelId:)`는 messages가 빈 새 Conversation을 생성한다
- [x] `Conversation.appending(_:)`는 messages 끝에 Message가 추가된 새 Conversation을 반환한다 (immutable update)
- [x] `LLMModel`은 `id: String`, `displayName: String`을 저장하는 struct이다
- [x] `LLMModel.allSupported`는 opus46, sonnet46, haiku45 3개 상수를 포함한다
- [x] 각 상수의 id는 Anthropic API alias 형식이다 (`claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5`)

## Phase 2 — LLMError

네트워크/인증 실패를 명시적 타입으로 분리.

- [x] `LLMError`는 `.unauthorized`, `.rateLimited`, `.network(String)`, `.decoding(String)`, `.server(status: Int)` 케이스를 가진다
- [x] `LLMError`는 `Equatable` (auto-synthesized — 모든 associated value가 Equatable)

## Phase 3 — KeychainClient

API 키 저장/로드. 프로토콜 경계 확보.

- [x] `KeychainClient` 프로토콜은 `save(key:value:) throws`, `load(key:) throws -> String?`, `delete(key:) throws` 세 메서드를 가진다
- [x] `LiveKeychainClient.save` 후 `load`로 같은 값을 읽을 수 있다
- [x] `LiveKeychainClient.load`는 존재하지 않는 key에 대해 nil을 반환한다
- [x] `LiveKeychainClient.save`가 기존 값을 덮어쓴다
- [x] `LiveKeychainClient.delete` 후 `load`는 nil을 반환한다
- [x] 서로 다른 key는 독립적으로 저장된다
- [x] 각 테스트가 UUID 기반 고유 service로 격리 (tearDown 대체 패턴)

## Phase 4 — LLMClient 프로토콜

구현 이전에 경계부터.

- [x] `LLMClient` 타입(struct-with-closures)은 `sendMessage: @Sendable ([Message], LLMModel) async throws -> Message` 클로저를 가진다
- [x] TCA `DependencyKey`로 `LLMClient`를 등록할 수 있다 (liveValue, testValue, previewValue 포함)

## Phase 5 — AnthropicClient 구현

HTTP 계층. `URLSession`을 주입받고, 테스트는 `URLProtocol` stub으로.

- [x] `LLMClient.anthropic(session:apiKey:)` 팩토리가 `LLMClient` 인스턴스를 반환한다
- [x] `sendMessage` 호출 시 `POST https://api.anthropic.com/v1/messages`로 요청한다
- [x] 요청 헤더에 `x-api-key: <저장된 키>`가 포함된다
- [x] 요청 헤더에 `anthropic-version: 2023-06-01`이 포함된다
- [x] 요청 헤더에 `content-type: application/json`이 포함된다
- [x] 요청 body의 `model` 필드가 전달된 `LLMModel.id`와 일치한다
- [x] 요청 body의 `messages` 배열이 전달된 `[Message]`를 role/content 형태로 직렬화한다
- [x] 요청 body에 `max_tokens` 필드가 포함된다 (기본 4096)
- [x] 200 응답의 `content[0].text`를 `Message(role: .assistant, content: ..., createdAt: ...)`로 파싱한다
- [x] 401 응답은 `LLMError.unauthorized`를 throw한다
- [x] 429 응답은 `LLMError.rateLimited`를 throw한다
- [x] 5xx 응답은 `LLMError.server(status:)`를 throw한다
- [x] URLError는 `LLMError.network`로 wrap된다
- [x] 잘못된 JSON 응답은 `LLMError.decoding`으로 wrap된다

## Phase 6 — ConversationStore

세션 영속화. SwiftData로 구현하되 프로토콜 뒤에 둠.

- [x] `ConversationStore` struct는 `save/load/loadAll/delete` 클로저를 가진다 (struct-with-closures, async throws)
- [x] `ConversationStore.liveBacked(container:)`.save 후 .load(id:)로 같은 Conversation을 읽을 수 있다
- [x] .loadAll()은 저장된 모든 Conversation을 반환한다
- [x] .loadAll()은 `createdAt` 내림차순으로 정렬해서 반환한다
- [x] .delete(id:) 후 .load(id:)는 nil을 반환한다
- [x] .save가 같은 id에 대해 호출되면 기존 Conversation을 업데이트한다 (upsert)
- [x] 각 테스트는 in-memory SwiftData 컨테이너를 사용한다 (테스트 인프라 패턴)

## Phase 7 — OnboardingFeature (TCA)

첫 실행 시 API 키 입력.

- [x] `OnboardingFeature.State`는 `apiKeyInput: String`, `isValid: Bool`, `error: String?`을 가진다
- [x] `.apiKeyChanged(String)` 액션이 `apiKeyInput`을 업데이트한다
- [x] 빈 문자열일 때 `isValid`는 false
- [x] `sk-ant-`로 시작하는 문자열일 때 `isValid`는 true
- [x] `.saveTapped` 액션이 `KeychainClient.save(key: "anthropic_api_key", value: apiKeyInput)`을 호출한다
- [x] `KeychainClient.save` 실패 시 `error`에 메시지를 세팅한다
- [x] 저장 성공 시 `.saveSucceeded` 액션을 발행한다

## Phase 8 — ChatFeature (TCA)

메인 채팅 루프.

- [x] `ChatFeature.State`는 `conversation: Conversation`, `inputText: String`, `isStreaming: Bool`, `error: LLMError?`를 가진다
- [x] `.inputChanged(String)` 액션이 `inputText`를 업데이트한다
- [x] `.sendTapped` 액션은 inputText가 비어있으면 아무것도 하지 않는다
- [x] `.sendTapped` 액션이 user Message를 conversation에 추가하고 inputText를 비운다
- [x] `.sendTapped` 액션이 `isStreaming = true`로 바꾸고 `LLMClient.sendMessage` effect를 트리거한다
- [x] `.messageReceived(Message)` 액션이 assistant Message를 conversation에 추가하고 `isStreaming = false`로 바꾼다
- [x] `.errorOccurred(LLMError)` 액션이 `error`를 세팅하고 `isStreaming = false`로 바꾼다
- [x] 메시지 추가 후 `ConversationStore.save` effect가 트리거된다

## Phase 9 — ModelPickerFeature (TCA)

세션 단위 모델 선택.

- [x] `ModelPickerFeature.State`는 `availableModels: [LLMModel]`, `selectedModel: LLMModel`을 가진다
- [x] `availableModels`는 `.opus46`, `.sonnet46`, `.haiku45` 3개를 포함한다
- [x] `.modelSelected(LLMModel)` 액션이 `selectedModel`을 업데이트한다
- [x] ChatFeature가 새 Conversation을 시작할 때 `selectedModel`이 `conversation.modelId`에 고정된다
- [x] 기존 Conversation을 이어갈 때 `conversation.modelId`가 그대로 유지된다 (mid-session 모델 변경 X) — `Conversation.modelId`가 `let`이므로 컴파일러가 보장, 별도 테스트 불필요

## Phase 10 — 마크다운 렌더링 (수동 검증)

`swift-markdown-ui` 추가 후 렌더링. 테스트 자동화 범위 밖, 시뮬레이터 수동 확인.

- [x] `swift-markdown-ui` SPM 의존성 추가 + 빌드 성공
- [x] `MessageView`가 assistant 메시지를 마크다운으로 렌더링한다 (수동 확인: 코드 블록, 인라인 코드, bold, 리스트)
- [x] 다크모드에서도 동일 가독성 (수동 확인)
- [x] 긴 코드 블록이 가로 스크롤된다 (수동 확인)
- [x] 런치 스크린: DarkNavy 배경 + LaunchIcon(Mannaz 룬) 중앙 표시 (실기기 확인 완료, 시뮬레이터는 캐시 이슈)

## Phase 11 — 통합 + Manual Smoke Test

모든 레이어 연결. 시뮬레이터에서 실제 사용.

- [x] 첫 실행 시 Onboarding 화면이 뜬다
- [x] API 키 입력 후 ChatFeature로 전환된다
- [x] 메시지 전송 → Claude 응답 표시 → 세션 저장 플로우가 동작한다
- [x] 앱 재실행 후 이전 세션이 목록에 뜬다
- [x] 새 세션 시작 시 모델 선택 가능

---

## 완료 기준 (Sprint 1)

- [x] 모든 Phase 1~9의 unit test가 통과한다
- [x] 경고 0
- [x] Phase 10, 11 수동 smoke test 통과
- [x] 본인이 실기기에서 실제로 한 번 이상 대화 완수 (dogfooding 최초 사용)

---

# Sprint 2 — Streaming + Memory (Apr 13~)

Sprint 2 범위: SSE 스트리밍 응답 + Extended Thinking + GitHub 메모리 동기화 + 메모리 컨텍스트 주입.

## Phase 12 — SSE 스트리밍 응답

non-streaming → streaming 전환. `URLSession.bytes(for:)` + SSE 파싱.

- [x] `LLMClient`에 `streamMessage: @Sendable ([Message], LLMModel) async throws -> AsyncThrowingStream<String, Error>` 추가
- [x] `AnthropicClient`에서 `"stream": true` 요청 body 추가
- [x] SSE 라인 파싱: `data:` 프리픽스 → JSON → `content_block_delta.delta.text` 추출
- [x] `message_stop` 이벤트에서 스트림 종료
- [x] 에러 이벤트(`error` type) 처리
- [x] `ChatFeature`에 `.streamChunkReceived(String)` 액션 추가
- [x] `.streamChunkReceived`가 conversation의 마지막 assistant 메시지에 텍스트를 append한다
- [x] ChatView에서 토큰 단위 실시간 렌더링 (기존 ProgressView 대체)
- ~~non-streaming fallback 유지~~ — 제거 결정 (12d). YAGNI, 스트리밍 단일 경로로 단순화

## Phase 13 — Extended Thinking

thinking 파라미터 + thinking 블록 파싱.

- [x] 요청 body에 `thinking: { type: "adaptive" }` + `output_config: { effort: ... }` 추가 (Opus 4.7은 adaptive only, Opus/Sonnet 4.6은 adaptive 권장. manual `budget_tokens`는 deprecated)
- [x] 응답에서 `thinking` 블록과 `text` 블록 분리 파싱 — SSEParser가 text_delta 외 ignored 처리, thinking_delta 자동 무시 (별도 처리 불필요)
- [x] 스트리밍 시 thinking 블록 → text 블록 순서 처리 — 위와 동일, ignored
- ~~thinking 내용 표시 여부 설정 (접기/펼치기 또는 숨김)~~ — 현재 숨김 고정. Sprint 4(consolidation) 직전 사용자 패턴 보고 재검토
- [x] `LLMModel`에 effort 지원 여부 속성 추가 (`supportsEffort: Bool`) + `EffortLevel` enum (low/medium/high/max)
- [x] `Conversation.effort: EffortLevel?` 영속화 + ChatFeature 전달 (13b)
- [x] ModelPicker Effort Picker + gauge 뱃지, ChatView 헤더에 effort 표시 (13c)

## Phase 14 — GitHub 메모리 동기화

PAT 기반 GitHub REST API. 메모리 파일(.md) CRUD.

- [x] `GitHubClient` struct-with-closures 정의 (DependencyKey)
- [x] PAT/owner/repo/branch/path를 Keychain에 JSON 묶음 저장 (GitHubCredentialsClient)
- [x] `GET /repos/{owner}/{repo}/contents/{path}` — 메모리 파일 목록 조회
- [x] `GET /repos/{owner}/{repo}/contents/{path}` — 개별 파일 내용 조회 (Base64 디코딩)
- [x] `PUT /repos/{owner}/{repo}/contents/{path}` — 파일 생성/수정 (sha 포함 upsert)
- [x] `DELETE /repos/{owner}/{repo}/contents/{path}` — 파일 삭제
- [x] 메모리 파일 목록 View (MemoryListView) + 삭제
- [x] 메모리 파일 편집 View (MemoryEditView) — 모바일 편집은 저빈도 용도. 주된 편집은 데스크톱
- [x] 메모리 파일 생성 View (MemoryCreateView) — 이동 중 통찰 저장용
- [x] commit message 자동 생성 ("Update <filename>", "Create <filename>")
- [x] 404 → 빈 상태로 해석 (경로 미존재 시 사용자 혼란 방지)

## Phase 15 — 메모리 컨텍스트 주입

채팅 시 메모리 파일을 시스템 프롬프트에 삽입 + Claude가 tool_use로 추가 파일 동적 로드.

**접근 방식 결정**: P2(MEMORY.md 자동 주입) + P3-read(tool_use로 추가 파일 lazy load).
편집은 Sprint 3 consolidation으로 분리 (CLAUDE.md "자동 commit X" 원칙 유지).

- [x] `AnthropicClient` 요청 body에 `system` 필드 추가 (Builder + 2 tests)
- [x] LLMClient.streamMessage에 system 파라미터 plumbing (3c2)
- [x] ChatFeature가 .global + .local MEMORY.md 자동 fetch해 system으로 주입 (slice 1, 3 tests)
- [x] AnthropicRequestBuilder에 tools 필드 + LLMTool 도메인 (slice 2, 2 tests)
- [x] AnthropicSSEParser가 tool_use 이벤트 인지 (slice 3a, 5 tests)
- [x] streamMessage 반환 타입 LLMStreamEvent + AnthropicClient가 tool_use 블록 조립 (slice 3b)
- [x] APIContentBlock 도메인 + 직렬화 (slice 3c1, 5 tests)
- [x] Builder가 APIMessage 사용 + apiMessages 옵션 (slice 3c2, 2 tests)
- [x] LLMClient.streamMessage 시그니처에 APIMessage + tools (slice 3c3)
- [x] ChatFeature 멀티턴 루프 + read_memory tool 활성 (slice 3c4, 1 integration test)
- ~~메모리 파일 선택 UI~~ — 자동 주입 + tool 동적 로드 패턴으로 교체 (사용자 큐레이션 = MEMORY.md 인덱스)
- [ ] 토큰 사용량 표시 (주입된 컨텍스트 크기 인지) — dogfooding 후 필요성 재평가

## Phase 16 — Tool 호출 transparency UI

Claude가 read_memory tool 부를 때 사용자에게 보이도록.

- [x] 채팅 UI에 tool 호출 칩 표시 (예: "📖 global/runes/profile.md")
- [x] 멀티턴 진행 표시 (칩 내부 spinner)
- [x] 스트리밍 중 tool_use 인식 → ChatFeature에서 toolUseRequested/Completed 액션 발행
- ~~(옵션) 채팅 메시지에 tool 호출 inline annotation~~ — 칩으로 충분, dogfooding 후 재평가

## Phase 17 — write_memory tool + 쓰기 확인 modal

Claude가 메모리 파일을 직접 쓸 수 있게. 안전장치는 사용자 confirm.

- [x] `LLMTool.writeMemory` 정의 (role/path/content/commit_message) (17.1)
- [x] tool_use 처리는 read와 동일 경로 (파서/클라이언트 변경 불요, 기존 인프라 재사용)
- [x] `WriteApprovalGate` dependency (continuation 기반, 17.2, 2 tests)
- [x] ChatFeature: write_memory 받으면 gate.requestApproval로 await (17.3, 3 tests)
- [x] Confirm modal: role/path/commit/content 표시 → accept/reject (17.5, xcstrings 7키)
- [x] accept → sha 조회 후 github.saveFile → tool_result 반환 → 라운드 재개
- [x] reject → tool_result에 "User rejected" → 라운드 재개
- ~~diff(기존 vs 신규) 표시~~ — 초기 버전은 신규 content만. dogfooding 후 재평가

---

## 완료 기준 (Sprint 2)

- [x] 스트리밍 응답이 토큰 단위로 실시간 표시된다
- [x] Extended thinking 옵션이 동작한다 (effort 파라미터)
- [x] GitHub 메모리 파일을 앱에서 조회/편집/커밋할 수 있다
- [x] 메모리 파일이 채팅 컨텍스트에 주입된다 (MEMORY.md 자동 + read_memory tool)
- [x] tool 호출이 채팅 UI에 transparency로 보인다 (Phase 16)
- [x] Claude가 write_memory로 메모리 변경 (Phase 17, confirm modal 거침)
- [x] 기존 테스트 전체 통과 + 새 테스트 추가 (179 tests)

---

# Sprint 3 — Rate Limit UX, Voice & Consolidation

## Phase 18 — Rate Limit 상태 노출 ✅

Anthropic API 응답 헤더의 `anthropic-ratelimit-*`를 파싱해 남은 쿼터를 UI에 표시. Opus 4.6 Max tier의 타이트한 output 한도 대응.

### Domain
- [x] `RateLimitState.Quota`는 `limit: Int`, `remaining: Int`, `resetsAt: Date`를 가진다
- [x] `Quota.percentRemaining`은 0.0~1.0 범위의 Double을 반환한다
- [x] `RateLimitState`는 `requests`, `tokens`, `inputTokens`, `outputTokens` 4개 Quota 옵셔널을 가진다
- [x] `RateLimitState.parse(from: HTTPURLResponse)`는 헤더에서 4개 Quota를 추출한다
- [x] 누락된 헤더 그룹은 해당 Quota nil
- [x] `anthropic-ratelimit-*-reset` ISO8601 문자열을 Date로 파싱한다
- [x] 파싱 실패 시 해당 Quota는 nil (에러 던지지 않음)

### Client 통합
- [x] `AnthropicClient.send`는 응답 시 `RateLimitState`를 스트림 이벤트(`LLMStreamEvent.rateLimitUpdate`)로 노출한다
- [x] 성공/실패 모두 헤더 파싱 수행 (429는 `LLMError.rateLimited(_, state:)`로 전달 — Phase 19에서 확장)
- [x] `LLMClient` 프로토콜의 이벤트 스트림에 rate limit 전달

### TCA
- [x] `ChatFeature`에 `rateLimitUpdated(RateLimitState)` 액션 추가
- [x] State에 `rateLimit: RateLimitState?` 저장
- [x] 각 응답 후 reducer가 상태 갱신

### UI
- [x] `RateLimitBadge` 컴포넌트: 토큰 remaining 기준 색상 구분
  - remaining >= 20% → 표시 안 함
  - 5~20% → 노란 경고 배지 "토큰 62% 사용"
  - < 5% → 빨간 배지 "재설정까지 25초" 카운트다운
- [x] ChatView 상단에 조건부 노출
- [x] Output 한도를 우선 표시 (Opus 4.6 Max output-tokens가 가장 먼저 고갈)
- [ ] 배지 탭 시 상세 (requests/tokens/input/output 4개 Quota 전체) — 추후

## Phase 19 — 공통 에러 복구 UI + 수동 재시도 ✅ (테스트 포함 완료)

429만 특별 취급하지 않고 네트워크·서버·디코딩·기타 에러까지 **통합 재시도 UX**.

### Error 모델
- [x] `LLMError.rateLimited`는 `retryAfter: TimeInterval?`와 `state: RateLimitState?`를 가진다 (헤더 없으면 둘 다 nil)
- [x] `LLMError.isRetryable`은 `.cancelled`에서만 false, 나머지는 true
- [x] `AnthropicClient.send`는 429 응답에서 `retry-after` 헤더를 파싱한다
- [x] `LLMError.cancelled` 케이스 신규 추가 (기존에 없었음)

### 실패 메시지 상태
- [ ] ~~`Message`는 `status: .streaming / .completed / .failed(LLMError) / .cancelled` 상태를 가진다~~ — **스킵**. SwiftData 마이그레이션 비용 높고, 현재 ChatFeature.error + conversation 구조로 충분. 향후 재검토
- [x] ChatFeature는 실패 시 원본 요청(마지막 user 메시지)을 보존한다 (재전송용) — `conversation.messages.last`로 대체

### UI
- [x] `ErrorBubbleView` 컴포넌트: 에러 종류별 안내 문구
  - `.rateLimited`: "토큰 한도 초과" + 카운트다운 (retryAfter 있을 때)
  - `.network`: "연결 확인"
  - `.server(5xx)`: "서버 오류"
  - `.decoding`: "응답 해석 실패"
  - `.unknown`: (별도 케이스 없이 .network/.server 분류)
- [x] isRetryable == true면 `[재시도]` 버튼 표시, 탭 시 마지막 user 메시지 재전송
- [x] `.cancelled`는 재시도 버튼 없이 닫기만 (`.isRetryable == false` 분기)
- [x] `[닫기]` 버튼은 항상 표시 — error 해제
- [ ] 429의 retryAfter 카운트다운 중엔 재시도 버튼 비활성 — 현재 버튼 항상 활성, 카운트다운 표시만. 향후 disable 토글 추가 가능
- [x] 재시도 탭 시 에러 버블이 사라지고 로딩 버블로 전환 (error=nil + sendTapped 재전송)
- [x] 기존 `ChatErrorBanner` 제거 → `ErrorBubbleView`로 완전 대체

### 테스트
- [x] `LLMErrorTests`: `.cancelled` 케이스, `isRetryable`, `rateLimited` variants (retryAfter/state 구분)
- [x] `AnthropicClientTests`: 429 retry-after 파싱, 429 rate limit 헤더 → state
- [x] `ChatFeatureTests`: `errorDismissed`, `errorOccurred`가 rateLimit 추출, `errorOccurred(.rateLimited(_, nil))`는 기존 rateLimit 유지, `retryTapped` 3변형 (정상/마지막이 user 아님/빈 메시지)
- [x] `ErrorBubbleViewTests`: `formatCountdown` (1분 미만, m:ss, 10분 이상)

## Phase 20 — 스트리밍 중 취소 ✅

### Client
- [x] `LLMClient.stream`은 `AsyncThrowingStream<LLMStreamEvent, Error>`을 반환한다 (기존)
- [x] Task.cancel 시 URLSession 작업이 정리된다 (AnthropicClient의 `continuation.onTermination` → `task.cancel()` 경로 기존 확보)
- [x] 취소 예외(`CancellationError`)는 스트림 소비자에서 중복 액션 없이 흡수된다

### TCA
- [x] `ChatFeature.CancelID.streaming` 정의
- [x] send 이펙트에 `.cancellable(id: CancelID.streaming, cancelInFlight: true)` 적용
- [x] State에 `isStreaming: Bool` 플래그 (기존)
- [x] `stopTapped` 액션 → `.cancel(id: CancelID.streaming)` 후 `.streamFinished`로 기존 완료/저장 경로 재사용 (isStreaming guard 포함)
- [x] ~~`streamCancelled(partial:)` 액션~~ — 불필요. `streamFinished` 경로 재사용 (partial은 state.conversation에 이미 누적)

### Message 모델
- [ ] ~~`Message.status`에 `.cancelled` 케이스~~ — Phase 19에서 SwiftData 마이그레이션 비용으로 스킵한 것과 동일 사유로 보류
- [x] 취소된 메시지의 partial 내용은 content에 보존 — `streamChunkReceived`가 누적한 상태를 그대로 저장

### UI
- [x] `isStreaming == true`일 때 Send 버튼 → **Stop 버튼 (`stop.circle.fill`)** 전환
- [x] Stop 버튼 tint red + 진동 피드백 (medium impact)
- [x] ChatView가 `onStop: { send(.stopTapped) }`를 ChatInputBar에 전달
- [x] submit(키보드 return)이 streaming 중엔 guard로 차단 — 의도치 않은 중복 전송 방지
- [ ] 스트리밍 중 assistant 버블에 파형/커서 인디케이터 — 미구현 (추후)
- [ ] 취소된 메시지 버블은 "[중단됨]" 배지 노출 — Message.status 미구현으로 보류
- [ ] (선택) `[이어 받기]` 버튼 — 보류

### i18n
- [x] `a11y.chat.stopButton` 5개 언어 추가

### 테스트
- [x] `stopTappedNoOpWhenNotStreaming` — isStreaming=false일 때 no-op
- [x] `stopTappedCancelsStreamAndPreservesPartial` — chunk 수신 액션을 명시적으로 receive해서 타이밍 의존 제거

## Phase 21 — Groq Whisper STT (음성 입력)

한글 음성 입력. SFSpeechRecognizer 한글 정확도 부족 대안.

- [x] STT 도메인 타입 (`STTResult`, `STTError`, `GroqCredentials`)
- [x] `GroqCredentialsClient` — Keychain 기반 Groq API 키 영속화
- [x] `STTClient` struct-with-closures 정의 (DependencyKey) + Groq Whisper HTTP 구현 + 에러 매핑
- [x] `AudioRecorder` 프로토콜 스캐폴드
- [x] ChatInputBar 마이크 버튼 + ChatFeature STT 파이프라인 (Mock wiring)
- [x] `NSMicrophoneUsageDescription` Info.plist 선언
- [x] `AudioRecorder.liveValue` — AVAudioRecorder 실구현 (16kHz mono WAV, 60s cap)
- [x] 마이크 권한 요청 런타임 처리 + 거부 시 안내 UI (`STTErrorBanner` + 설정 앱 딥링크)
- [x] Mock → live wiring 전환 — `@Dependency` default가 liveValue로 해석 (별도 코드 변경 불필요)
- [x] 변환 결과를 ChatInputBar에 삽입 — `.transcribed` → `state.inputText` append 경로 (실기기 검증은 dogfooding 항목)
- [x] Groq 키 입력 UI — `GroqCredentialsFeature/View` + ConversationList gear Menu
- [ ] 실기기 dogfooding (시뮬레이터 마이크 한계)

## Phase 22 — Azure Neural TTS (응답 읽어주기)

assistant 메시지를 Azure Neural TTS로 합성·재생. BYOK(키+region), MP3 반환 → AVAudioPlayer 재생.

**이유**: AVSpeechSynthesizer 기본음 품질 한계 → Azure Neural(SunHi/InJoon 등) 실측 선호. STT(Groq) ↔ TTS(Azure) 분리는 품질 우선.

### Slice 1 — AzureCredentials ✅
- [x] `AzureCredentials` 도메인 (`apiKey`, `region`), `KeychainKey`, `isValid`
- [x] `AzureCredentialsClient` Keychain 영속화 (load/save/clear) — `GroqCredentialsClient` 패턴
- [x] `AzureCredentialsFeature` (apiKey/region 2필드, save/clear/loadExisting)
- [x] `AzureCredentialsView` (Form + SecureField + region 입력)
- [x] ConversationList gear Menu에 "Azure TTS 키" 항목
- [x] 로컬라이즈 8개 키 (5개 언어): `azure.*` + `settings.azureKey`
- [x] `AzureCredentialsClientTests` 4건

### Slice 2 — SpeakerClient + Azure 합성 ✅
- [x] `SpeakerClient` struct-with-closures: `synthesize(text:voice:language:rate:pitch:) → Data`(MP3)
- [x] `SpeechError`: unauthorized / rateLimited / server / network / decoding / playbackFailed / cancelled + `userMessageKey`·`isRetryable`
- [x] `SpeakerClient.azureNeural(session:credentials:)` — SSML 빌더 + REST POST
- [x] SSML 빌더 + XML 이스케이프, `<prosody rate pitch>`, pitch `(p-1.0)*100%` 변환
- [x] `X-Microsoft-OutputFormat: audio-16khz-32kbitrate-mono-mp3` 헤더
- [x] `liveValue`: credentials 로드 후 azureNeural 위임, 키 없으면 `.unauthorized`
- [x] 11개 유닛 테스트 (URLProtocolStub, SSML 빌더, 에러 매핑)

### Slice 3 — AudioPlayer dependency ✅
- [x] `AudioPlayer` struct-with-closures: `play(Data) async throws`, `stop()`, `isPlaying() → Bool`
- [x] `LiveAudioPlayer` actor + `PlayerDelegateAdapter`(nonisolated NSObject)
- [x] `AVAudioSession` `.playback` 활성/비활성 관리, 중첩 재생 시 기존 stop 먼저
- [x] delegate completion → continuation resume, stop 호출은 `SpeechError.cancelled` 전달
- [x] `testValue` / `previewValue`

### Slice 4 — Message.id [structural] ✅
- [x] `Message`에 `let id: UUID` 추가 (default `UUID()`)
- [x] `MessageEntity.id: UUID?` 옵셔널 컬럼 — lightweight migration, 기존 row는 load 시 `UUID()` 부여
- [x] `EntityMapping` 양방향 id 보존
- [x] `Message` Equatable은 role/content/createdAt만 (id 제외 — UI 태그)

### Slice 5 — MessageView 🔊 + ChatFeature ✅
- [x] `ChatFeature.State.speakingMessageID: UUID?`, `speakError: SpeechError?`
- [x] Actions: `speakTapped`, `speakingStarted`, `speakingFinished`, `stopSpeakTapped`, `speakErrorOccurred`, `speakErrorDismissed`
- [x] `ChatFeature+Speak.swift` extension (reduceSpeak 위임)
- [x] `CancelID.speaking` 추가, cancelInFlight로 기존 재생 교체
- [x] `speakTapped`: 스트리밍 중 no-op, 같은 메시지 재탭은 토글 off, 로케일 기반 기본 voice
- [x] `MessageView` assistant 버블: `speaker.wave.2.fill` / `pause.fill`, 재생 중 배경 tint
- [x] streaming/빈 content면 버튼 숨김
- [x] `SpeechErrorBanner` + ChatView overlays 연결
- [x] 로컬라이즈 10개 키 (`speech.error.*`, `speech.banner.title`, `a11y.message.play/stopAudio`)

### Slice 6 — SpeechTextSanitizer ✅
- [x] `Utilities/SpeechTextSanitizer.swift` — `speechPlainText(from:) → String`
- [x] 코드블록 → "[코드]", 이미지/링크 text만, 인라인 코드/강조/헤더/인용 마커 제거, 공백·개행 정규화
- [x] `ChatFeature+Speak`가 synthesize 전 적용, 빈 결과면 no-op
- [x] 11개 유닛 테스트

### Slice 7 — 음성 설정 (ChatView 우상단 Menu + 상세 sheet) ✅
- [x] `SpeechSettings` 값 타입 + `AzureVoice.presets` (ko-KR 4, en-US 2)
- [x] `SpeechSettingsClient` UserDefaults 영속화 (load/save)
- [x] ChatView 우상단 toolbar: `speaker.wave.2` (off) / `speaker.wave.3` (on) Menu
- [x] Menu 구성: 자동 재생 Toggle + voice Section 체크마크 + "상세 설정…" 버튼
- [x] `SpeechSettingsView` sheet: 속도·피치 Slider (0.5~1.5, 0.05 step)
- [x] ChatFeature 8개 action (load/loaded/voiceSelected/autoSpeakToggled/rateChanged/pitchChanged/settingsTapped/Dismissed)
- [x] SpeakerClient 호출 시 state.speechSettings로 voice/rate/pitch 전달 (로케일 기본 voice 제거)
- [x] 로컬라이즈 9개 키 (settings.tts.*, a11y.chat.ttsSettings)

### Slice 8 — autoSpeak + streamFinished 연동 + i18n ✅
- [x] `streamFinished` 처리 시 `autoSpeak == true` + 마지막 assistant(비어있지 않음)면 `speakTapped(id)` 자동 발행
- [x] 유닛 테스트 7건: autoSpeak on/off/user-last/empty-assistant 분기, streaming no-op, 토글 off, loadSpeechSettings roundtrip
- [x] i18n 커버: `a11y.message.play/stopAudio`, `a11y.chat.ttsSettings`, `settings.tts.*`, `speech.error.*`, `speech.banner.title` (5개 언어)

### 완료 기준 (Phase 22)
- [ ] assistant 메시지 🔊 탭 → Azure TTS 합성 → MP3 재생
- [ ] 재생 중 다른 메시지 탭 → 기존 중단 + 새로 시작
- [ ] stop 버튼으로 중단 가능
- [ ] ChatView Menu에서 voice/autoSpeak 변경 즉시 적용
- [ ] "상세 설정" sheet에서 rate/pitch 변경 적용
- [ ] autoSpeak on 상태에서 스트리밍 완료 시 자동 재생
- [ ] 키 없으면 SpeechErrorBanner + 설정 메뉴에서 입력 가능
- [ ] 기존 테스트 전체 통과 + 신규 테스트 추가

## Phase 23 — Consolidation

CLAUDE.md "Sprint 3 — Consolidation" 섹션 참조.

**핵심**: 거친 대화 → 정제된 메모리 룬. 사용자가 수동으로 "Consolidate now" 탭 → LLM이 최근 대화 + 기존 메모리를 훑어 제안 카드 리스트 → accept/reject/edit.

**MVP 원칙**
- A안(수동 트리거)만. 백그라운드·GitHub Actions는 검증 후.
- "제안 없음"이 정상. 억지 정제 방지 프롬프트 필수.
- 수락률 30% 이상이면 가치 있음 → Phase 2(자동) 검토.

### 데이터 입력
- [ ] `ConsolidationInput`: `recentConversations: [Conversation]` (지난 7일 또는 최근 N=10)
- [ ] `existingMemory`: MEMORY.md 인덱스 + 참조된 메모리 파일 내용
- [ ] 수집 범위 결정: .global / .local 둘 다 or 하나만? — **.local만** MVP (global은 사용자 승인 후 확장)
- [ ] `ConsolidationCollector`: ConversationStore에서 최근 세션 fetch + GitHub에서 메모리 fetch

### 도메인 모델
- [ ] `ConsolidationProposal` 값 타입:
  - `id: UUID`
  - `action: ProposalAction` — `.create | .update | .delete | .skip`
  - `path: String` (예: `memory/rune_decision_pattern.md`)
  - `rationale: String` ("어느 대화 어떤 맥락에서")
  - `content: String?` (create/update 시 마크다운 본문)
  - `beforeContent: String?` (update 시 기존 본문)
- [ ] `ConsolidationProposal`은 `Sendable`, `Equatable`, `Identifiable`
- [ ] `ConsolidationResult`: `proposals: [ConsolidationProposal]`, `generatedAt: Date`

### 프롬프트 설계
- [ ] `ConsolidationPrompt.build(input:)` — system + user 프롬프트 빌더
- [ ] **안티바디 주입**: `feedback_ai_overpraise.md` 통째로 system에 삽입
- [ ] 출력 포맷 강제: JSON(아래 스키마) — 파싱 실패 시 에러
  ```json
  { "proposals": [
      { "action": "create|update|delete|skip",
        "path": "memory/...",
        "rationale": "...",
        "content": "..." }
  ] }
  ```
- [ ] 프롬프트 본문에 **"제안 없음이 정상. 억지로 만들지 마"** 명시
- [ ] 프롬프트에 **"매일 여러 패턴 발견 X. narrative pull은 약장수 모드"** 명시
- [ ] Prompt 상수는 `Localizable` 아님 — 영어/한국어 혼합 고정 문자열

### ConsolidationClient (DI)
- [ ] `ConsolidationClient` struct-with-closures:
  - `generate(ConsolidationInput) async throws -> ConsolidationResult`
- [ ] `liveValue`: LLMClient 재사용 (모델은 Claude Sonnet 기본, 사용자가 세션 모델과 별개로 선택 가능)
- [ ] JSON 응답 파싱 + 스키마 검증
- [ ] `testValue` / `previewValue` — 고정 제안 리스트 반환

### ConsolidationFeature (TCA)
- [ ] `ConsolidationFeature.State`: `isLoading: Bool`, `proposals: [ConsolidationProposal]`, `error: ConsolidationError?`, `resultAt: Date?`
- [ ] Actions: `consolidateTapped`, `generateStarted`, `generateFinished(ConsolidationResult)`, `generateFailed(ConsolidationError)`, `proposalAccepted(UUID)`, `proposalRejected(UUID)`, `proposalEditTapped(UUID)`
- [ ] accept 시 기존 write_memory 플로우 재사용 (GitHubClient role 기반 commit)
- [ ] reject 시 리스트에서 제거만 (미기록 = 다음 번에 또 제안 가능)

### UI
- [ ] ConversationList 좌상단 설정 메뉴에 **"Consolidate now"** 항목
- [ ] `ConsolidationView` sheet:
  - 로딩 스피너 ("대화·메모리 정제 중…")
  - 에러 배너
  - 제안 카드 리스트
- [ ] `ProposalCard`:
  - `action` 배지 (create=초록/update=주황/delete=빨강)
  - `path` + `rationale`
  - create: content 미리보기 (접힘/펼침)
  - update: before/after diff (기존 WriteApprovalModal 패턴 재사용)
  - [Accept] [Reject] [Edit]
- [ ] **빈 상태**: 제안 0개면 "정제할 새 패턴 없음. 조용한 morning이 좋은 morning." 메시지
- [ ] 로컬라이즈 5개 언어

### 보안·비용
- [ ] 입력 토큰 cap: 최근 대화가 거대하면 truncate 경고 + 사용자 확인
- [ ] rate limit 재사용 (기존 LLMClient 경로)
- [ ] GitHub commit 전 WriteApprovalGate 경유 (이중 확인)

### 검증 단계
- [ ] Phase 1(MVP): 수동 버튼만 — 본 섹션
- [ ] 1주 도그푸딩 — 수락률 기록
- [ ] 수락률 30%+ → Phase 2 (자동 야간) 검토
- [ ] 수락률 저조 → 프롬프트·안티바디 조정

### 의존(이미 완료)
- [x] LLMClient (Phase 5)
- [x] ConversationStore (Phase 6)
- [x] GitHubClient + PAT role 기반 (Phase 14)
- [x] write_memory tool + WriteApprovalGate (Phase 17)
- [x] feedback_ai_overpraise.md (global memory, 이미 존재)

## Phase 24 — 파일 첨부 (카메라, 사진, 파일)

멀티모달 입력. Claude Vision·Document 지원을 활용해 이미지·PDF·텍스트 첨부.

### Domain
- [ ] `Attachment` 모델: `id: UUID`, `kind: AttachmentKind`, `data: Data`, `mimeType: String`, `filename: String?`, `byteSize: Int`를 가진다
- [ ] `AttachmentKind` enum: `.image`, `.pdf`, `.text`
- [ ] `Attachment`는 `Sendable`, `Equatable`, `Identifiable`
- [ ] `Attachment.thumbnail`은 이미지는 self, PDF는 첫 페이지 렌더, text는 아이콘
- [ ] 이미지 크기 제한: 단일 5MB (Anthropic Vision 한도), 초과 시 자동 다운샘플 또는 에러
- [ ] PDF 크기 제한: 32MB
- [ ] `APIContentBlock` 확장: `.image(base64: String, mediaType: String)`, `.document(base64: String, mediaType: String)` 케이스 추가

### APIMessage 확장
- [ ] `APIMessage.content`는 `.blocks([APIContentBlock])` 케이스를 통해 텍스트+이미지 혼합 가능
- [ ] `Attachment → APIContentBlock` 변환 함수: base64 인코딩 포함
- [ ] ChatFeature.sendTapped는 첨부가 있으면 blocks 케이스로 전송

### AttachmentClient (DI)
- [ ] `AttachmentClient` struct-with-closures: `loadImage`, `loadCameraImage`, `loadDocument`
- [ ] `liveValue`: 각 picker를 제공하는 UIViewControllerRepresentable 래퍼
- [ ] `testValue` / `previewValue`
- [ ] 권한 거부 케이스 처리 (`AttachmentError.permissionDenied`)

### Picker UIs
- [ ] `PhotosPicker` (PhotosUI, iOS 16+) — 다중 선택 가능
- [ ] `CameraPickerView`: `UIImagePickerController` SwiftUI 래퍼
- [ ] `DocumentPickerView`: `UIDocumentPickerViewController` SwiftUI 래퍼 (.pdf, .txt, .md 등 UTType 지정)
- [ ] 각 picker 취소 시 no-op

### 권한
- [ ] `Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
- [ ] 카메라 거부 시 Settings 앱으로 이동 안내
- [ ] 사진 라이브러리는 PhotosPicker가 권한 자동 처리 (iOS 16+)

### ChatInputBar UI
- [ ] 입력창 왼쪽에 `+` (plus.circle) 버튼 추가
- [ ] 탭 시 ActionSheet/Menu: "카메라", "사진 라이브러리", "파일"
- [ ] 선택된 첨부는 입력창 상단에 **썸네일 행**으로 표시
- [ ] 각 썸네일 우상단 `xmark.circle.fill` 제거 버튼
- [ ] 이미지는 썸네일, PDF/텍스트는 아이콘 + 파일명
- [ ] 첨부 + 텍스트 둘 다 비어있으면 Send 비활성
- [ ] 전송 후 첨부 리스트 초기화
- [ ] 크기 초과 시 경고 토스트 (`error.attachment.too_large`)

### ChatFeature State
- [ ] `ChatState.pendingAttachments: [Attachment]`
- [ ] Actions: `attachmentAdded(Attachment)`, `attachmentRemoved(UUID)`, `attachmentsCleared`
- [ ] sendTapped 시 pendingAttachments + text로 APIMessage 구성 후 초기화

### 메시지 버블 표시
- [ ] 유저 메시지 버블에 첨부 있으면 상단에 썸네일 표시
- [ ] 이미지 탭 시 전체화면 뷰어 (QuickLook 활용)
- [ ] PDF 탭 시 `QLPreviewController`
- [ ] 첨부 없이 텍스트만 있으면 기존 버블 유지

### Consolidation 호환
- [ ] 첨부가 포함된 메시지는 마크다운 저장 시 base64 텍스트로 덤프 or 별도 파일 경로 참조 (결정 필요)
- [ ] 일단 첨부는 **세션 내에서만 live**, 영속화는 Phase 23(Consolidation) 이후 과제로 미룸

---

## 접근성 (지속적, 모든 Sprint)

- [ ] 새로 추가되는 View에 VoiceOver label/hint 적용
- [ ] 스트리밍 중 VoiceOver 알림 (실시간 텍스트 변경 공지)
- [ ] Dynamic Type 전체 View 검증
- [ ] 메모리 편집 View 접근성
- [ ] Sprint 3 추가 예정: 마이크 버튼 VoiceOver label, write 모달 접근성
- [ ] Sprint 3 RateLimitBadge: `.accessibilityLabel` + 상세 정보 제공 (카운트다운 포함)
- [ ] Sprint 3 ErrorBubble: 재시도/취소 버튼 VoiceOver hint, 에러 종류 음성 알림
- [ ] Sprint 3 Stop 버튼: `.accessibilityLabel("스트리밍 중단")` + Send 버튼과 구분
- [ ] Sprint 3 Attachment `+` 버튼: `.accessibilityLabel("첨부")` + 메뉴 각 항목 label
- [ ] Sprint 3 첨부 썸네일: `.accessibilityLabel(filename)`, 제거 버튼 hint
- [ ] Sprint 3 이미지 뷰어: VoiceOver로 이미지 설명 제공 (alt text 사용자 입력 옵션 고려)

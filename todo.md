# TODO

## Chat Scroll 근본 재설계

**배경**: `ChatMessageList`의 bottom scroll 로직이 수동 `ScrollViewReader` + sentinel + 여러 notification listener + `DragGesture` 조합으로 얽혀 있음. 두 번째 전송 공백, 스트리밍 중 키보드 up 등 핵심 시나리오를 커버 못 함. 2026-04-24 두 차례 시도(코덱스 reason 기반, minimal `defaultScrollAnchor`) 모두 실패·폐기.

**계획서**: `plan-chat-scroll-redesign.md` 참고 (시도 히스토리, 9개 요구 시나리오, 접근 후보 A~D, 방법론)

- [ ] **접근 A 프로토타입** — `safeAreaInset(edge: .bottom)` + `defaultScrollAnchor(.bottom)` 조합. 브랜치 `fix/chat-scroll-redesign-A-safearea`
  - [ ] `ChatInputBar`를 ScrollView의 safeAreaInset으로 배치
  - [ ] `keyboardDidShow` 리스너 / `ScrollViewReader` / `proxy.scrollTo` / sentinel 제거 가능 여부 실험
  - [ ] autoFollowBottom 제어는 `onScrollGeometryChange` (iOS 18+) 또는 `GeometryReader` 대안 고려
- [ ] **실기기 9개 시나리오 체크리스트** (plan 문서 템플릿 사용)
- [ ] **영상 녹화**로 상태 기록 — 회귀 판정 근거
- [ ] 실패 시 접근 B (`scrollPosition(id:)`), 그 후 D, C 순
- [ ] 성공 시 Tidy First 분리 커밋 + PR

**주의**:
- Reducer·state 건드리지 말 것. View 레이어 한정.
- AI가 "증상 완화" 프레이밍에 빠지지 않도록 사용자가 계속 근본 원인 질문 던질 것.
- 한 번에 하나의 축만 건드리기.

## UI Smoke Tests 복구 (3건)

Sprint 3 진입 시점에 `testLaunchPerformance`를 포함한 UI 테스트를 통째로 제거했음(PR #67). 이제 회귀 방지가 아닌 **기동 불능 감지** 목적의 smoke 테스트 3개만 다시 들인다. 3~5개 이하 유지, flaky 최소화.

### 선행 작업 (공통 인프라)

- [ ] `NeuroRuneUITests` target 재생성 (기존 targets에서 삭제된 상태)
- [ ] `LaunchArguments` / `LaunchEnvironment` 기반 Mock 주입 구조
  - `--ui-test-mock-llm` 같은 플래그로 `AnthropicClient` stub 활성화
  - `--ui-test-mock-stt` 로 `STTClient` stub 활성화
  - App entry point에서 `ProcessInfo.processInfo.arguments` 체크
- [ ] 각 화면에 `accessibilityIdentifier` 정리
  - 채팅 입력 필드, 전송 버튼, 메시지 버블(role 태깅), mic 버튼, 쓰기 승인 모달 버튼
- [ ] UI 테스트 시드 데이터 리셋 (SwiftData in-memory 옵션 or 앱 기동 시 clean)
- [ ] Continuation gate 패턴 활용 — wall-clock 대기 금지

### Smoke 1. 채팅 기본 플로우

- [ ] **목적**: 앱이 기동되고, 사용자가 메시지를 전송하면 assistant 응답 버블이 나타난다
- [ ] **스텝**:
  1. `--ui-test-mock-llm` 으로 앱 기동
  2. 채팅 입력 필드에 `"hello"` 입력
  3. 전송 버튼 탭
  4. user 버블에 `"hello"` 노출 확인
  5. assistant 버블에 stub 응답(`"hi"` 등) 노출 확인
- [ ] **Mock**: Anthropic 스트리밍 응답을 고정 delta 2~3개 + stop
- [ ] **주의**: 스트림 지연은 ImmediateClock + Continuation gate로 결정적으로

### Smoke 2. STT → autoSend → assistant 응답

- [ ] **목적**: 음성 입력이 transcribe되면 countdown 만료 시 자동 전송되고 assistant 응답이 온다
- [ ] **스텝**:
  1. `--ui-test-mock-llm --ui-test-mock-stt` 로 기동
  2. mic 버튼 탭 → recording 상태 UI 확인
  3. mic 버튼 다시 탭(또는 stub이 transcribed 이벤트 방출)
  4. 입력 필드에 transcribed 텍스트 주입 확인
  5. countdown 경과 후 자동 전송 (TestClock advance) → user/assistant 버블 확인
- [ ] **Mock**: `STTClient.transcribe`가 고정 문자열 반환
- [ ] **주의**: 시뮬레이터에서 실제 mic 동작 불가 → STTClient stub이 핵심. countdown은 ImmediateClock/TestClock으로 advance

### Smoke 3. memory write 승인 모달

- [ ] **목적**: assistant가 `write_memory` tool을 호출하면 승인 모달이 뜨고, accept 시 파일이 기록된다
- [ ] **스텝**:
  1. `--ui-test-mock-llm --ui-test-mock-github` 로 기동
  2. 임의 메시지 전송
  3. Mock Anthropic 응답이 `write_memory` tool_use 반환
  4. 승인 모달 노출 확인 (파일명 + diff)
  5. "Accept" 탭 → 모달 dismiss 확인
  6. 이어지는 turn에서 tool_result가 assistant 컨텍스트에 들어갔음을 UI로 간접 검증 (응답 버블 노출)
- [ ] **Mock**: Anthropic 응답이 tool_use(`write_memory`, filename, content) 포함. GitHubClient.saveFile도 stub
- [ ] **주의**: `WriteApprovalGate`는 실제 구현 사용 (승인 플로우 검증이 목적). diff 렌더링 LineDiff는 실제 로직 돌림

### 측정 목표

- [ ] UI smoke 3건 포함 전체 테스트 사이클 **40초 이내** 유지 (현재 19s + UI boot 오버헤드)
- [ ] CI 실행 시간 증가 30초 이내
- [ ] flaky 0건 (10회 연속 돌려 확인)

### 참고

- 이전 UI 테스트 삭제 경위: `git log -1 ae5db7a`
- TDD 사이클 속도 기준은 `CLAUDE.md#TEST TIDY FIRST` 참고
- 각 smoke 추가는 **structural → behavioral 분리 커밋** 원칙 유지

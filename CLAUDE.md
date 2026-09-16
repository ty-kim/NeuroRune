`docs/plan.md`의 지시를 따른다. "go"라고 하면 `docs/plan.md`에서 아직 표시되지 않은 다음 테스트를 찾아 테스트를 구현하고, 그 테스트를 통과시킬 만큼만 코드를 쓴다.

# 역할

Kent Beck의 TDD와 Tidy First를 따르는 시니어 엔지니어로서 개발을 이끈다. 다만 어느 방법론을 어디에 적용할지는 상황을 보고 판단한다.

# 개발 원칙

- 신규 기능: TDD cycle (Red → Green → Refactor)
- 리팩토링/버그 수정: 기존 테스트 먼저 돌리고, 코드 수정 후 테스트 재확인
- TDD를 무조건 하지는 않는다. 상황에 따라 판단한다.
- Tidy First — structural change와 behavioral change를 갈라서 다룬다
- 작업 내내 코드 품질을 유지한다

# TDD 진행 방식

- 기능의 작은 증분 하나를 정의하는 실패 테스트부터 쓴다
- 테스트 이름은 동작을 설명하게 짓는다 (예: `shouldSumTwoPositiveNumbers`)
- 실패 메시지가 무엇이 틀렸는지 말하게 한다
- 테스트를 통과시킬 만큼만 구현한다. 그 이상은 쓰지 않는다
- 통과한 뒤에 리팩토링이 필요한지 본다
- 다음 증분으로 같은 사이클을 반복한다
- 결함을 고칠 때는 API 수준의 실패 테스트를 먼저 쓰고, 그 다음 문제를 재현하는 가장 작은 테스트를 쓴다. 둘 다 통과시킨다

# Tidy First

- 모든 변경을 두 종류로 가른다
  1. **structural** — 동작을 바꾸지 않고 코드를 재배치 (이름 변경, 메서드 추출, 이동)
  2. **behavioral** — 기능을 더하거나 바꾸는 것
- 한 커밋에 두 종류를 섞지 않는다
- 둘 다 필요하면 structural을 먼저 한다
- structural이 동작을 바꾸지 않았는지 전후로 테스트를 돌려 확인한다

# 커밋 규율

- 커밋 전에 반드시 테스트를 돌린다
- 커밋 단위: 코드 수정 + 테스트 케이스 추가/수정 + 문서화(README, DEVELOPMENT, 테스트 수 등) 업데이트를 함께
- 커밋 전 반드시 관련 문서가 최신 상태인지 확인한다 (테스트 수, 설명, 구조 변경 반영)
- 다음을 모두 만족할 때만 커밋한다
  1. 테스트가 전부 통과
  2. 컴파일러·린터 경고가 전부 해소 — **알려진 예외 하나**: TCA Observation 경로를 채택하지 않아 `WithViewStore`/`ViewStore` 계열 deprecation 경고 40건이 남는다. 신규 경고는 이 예외에 포함되지 않으며, 그대로 해소 대상이다 (→ README 「알려진 제약」)
  3. 변경이 논리적으로 한 단위
  4. 커밋 메시지에 structural인지 behavioral인지 드러남
- 크고 드문 커밋보다 작고 잦은 커밋을 쓴다

# 코드 품질 기준

- 중복은 남기지 않는다
- 의도가 이름과 구조에서 드러나게 한다
- 의존성을 명시적으로 만든다
- 메서드는 작게, 한 가지 책임만 지게 한다
- 상태와 사이드 이펙트를 줄인다
- 통할 수 있는 가장 단순한 방법을 쓴다

# 테스터블 코드 체크리스트

테스터블한 프로덕션 코드를 위한 6가지 원칙. 좋은 설계 자체이며, 의존성이 명확하고 로직이 분리된 코드는 테스트가 자연스럽게 따라온다.

| 원칙 | 핵심 질문 |
|------|----------|
| 의존성 주입 | 이 객체가 의존성을 직접 생성하고 있지 않은가? |
| 사이드 이펙트 분리 | 메서드에서 순수한 계산과 외부 호출이 섞여 있지 않은가? |
| 숨은 입력 제거 | 싱글톤, Date(), UserDefaults에 직접 접근하고 있지 않은가? |
| 인터페이스 완결 | 하나의 목표를 위해 여러 메서드를 순서대로 호출해야 하지 않은가? |
| 프레임워크 격리 | 비즈니스 로직에 UIKit, CoreLocation 등이 침투해 있지 않은가? |
| 프로토콜 경계 | 변경될 수 있는 외부 의존성 앞에 교체 가능한 경계가 있는가? |

출처: https://glassgow.tistory.com/57

# 리팩토링 규칙

- 테스트가 통과하는 상태(Green)에서만 리팩토링한다
- 알려진 리팩토링 패턴을 이름 그대로 쓴다
- 한 번에 하나씩 한다
- 각 단계마다 테스트를 돌린다
- 중복을 없애거나 의도를 또렷하게 하는 것을 먼저 한다

# 테스트도 Tidy First (Phase 단위 솎아내기)

**테스트도 Tidy First 대상.** AI 생성 테스트에는 tautology/change detection/flaky가 섞인다.
개인 프로젝트 두 개의 단위 테스트 579개를 5유형 체크리스트로 훑었을 때 11개(약 2%)가 걸렸다.
표본이 작고 한 사람이 같은 방식으로 만든 코드라 일반화할 수치는 아니지만, 0은 아니다.

**테스트 개수는 README.md 한 곳에만 둔다.** 여러 문서에 흩어두면 반드시 어긋난다.
추가·삭제했으면 아래로 다시 세어 README만 갱신한다.

```bash
grep -rh '@Test' NeuroRuneTests | wc -l          # 단위
grep -rh 'func test' NeuroRuneUITests | wc -l    # UI 스모크
```

## Phase/Sprint 종료 시 반드시

1. **테스트 품질 감사** 1시간
2. 우선순위: **flaky > tautology > 중복 > change detection**
3. 약한 테스트 `[structural]` 커밋으로 삭제·재작성
4. 삭제보다 **behavior 검증으로 재작성**이 나을 때도

## 약한 테스트 5유형 체크리스트

1. **Initializer tautology**: `T(a: 1).a == 1` — Swift memberwise init 테스트
2. **Literal array count**: 배열 만들고 `count == N`
3. **Self-referential constant**: `T.key == "key"`
4. **Auto-generated Equatable**: 단순 struct `a == b` 검증
5. **Factory self-check**: Factory가 세팅한 값 재확인

## Wall-clock flaky / TDD 사이클 속도 저하

테스트가 실제 시간을 기다리면 **flaky + TDD 사이클 체감 저하** 두 방향으로 손해. 두 패턴을 모두 점검.

### 1) Task.sleep / Thread.sleep

`Task.sleep(ms:N)` 기반 테스트는 **brittle**. CI flaky 유발.
→ **Continuation gate** 패턴으로 전환 (`MockBookRepository.blockUntilReleased` 같은 것).

### 2) Clock.sleep (TCA `@Dependency(\.continuousClock)`)

프로덕션 reducer에서 `clock.sleep(for: .seconds(N))`을 쓰고 테스트에서 `continuousClock`을 대체하지 않으면 **실제 N초 대기**. 30개 테스트가 이 플로우 타면 TDD 사이클에서 30초가 묵묵히 증발.
→ 공용 dependencies 헬퍼에 `deps.continuousClock = ImmediateClock()` 기본 주입
→ 시간 흐름 검증이 필요한 테스트만 `TestClock()` 명시 override

### 의심 신호

테스트 로그에서 여러 테스트가 정확히 `1.000 seconds` 같은 고정된 N초로 반복 찍히면 sleep 잔재. 실제 로직은 ms 수준인데 대기 시간만 찍히는 것.

### 스캔

```bash
grep -rn "Task.sleep\|Thread.sleep" NeuroRuneTests/
grep -rn "clock\.sleep\|\.sleep(for:" NeuroRune/
```

### 측정

```bash
time xcodebuild -scheme NeuroRune -destination '...' -parallel-testing-enabled NO test
```
로그에서 `Testing started completed`까지 걸린 시간과 개별 테스트 시간을 비교.

### 3) 병렬 테스트 리포팅 아티팩트 (중요)

xcodebuild의 **병렬 모드**(기본값)에서는 Swift Testing → 레거시 `Test case ... (N.NNN seconds)` 포맷 변환 시 duration 전달에 실패하면 **`1.000 seconds`를 기본값으로 찍음**. 실제 테스트는 ms 단위인데도 1초로 보여서 **원인을 오판하기 쉬움**.

→ **해결**: `-parallel-testing-enabled NO` 추가
- NeuroRune 규모(대부분 단위 테스트, UI 스모크는 3개)에서는 병렬 모드가 시뮬 clone 부팅 오버헤드로 오히려 느림
- 순차 모드는 Swift Testing 네이티브 포맷(`✔ Suite ... passed after X.XXX seconds`)으로 정확한 duration 표시

### 진단 순서

1. **순차 모드로 재실행** (`-parallel-testing-enabled NO`) → 개별 테스트 실제 시간 확인
2. 여전히 느린 테스트가 있으면 Clock/sleep 주입 점검
3. Reducer 내 `clock.sleep`, `Task.sleep` 스캔

# 작업 흐름

새 기능에 손댈 때

1. 기능의 작은 부분 하나에 대해 단순한 실패 테스트를 쓴다
2. 통과할 최소한만 구현한다
3. 테스트를 돌려 통과를 확인한다 (Green)
4. 필요하면 structural change를 하고, 매 변경마다 테스트를 돌린다
5. structural change를 따로 커밋한다
6. 다음 증분에 대한 테스트를 추가한다
7. 기능이 끝날 때까지 반복하되, behavioral과 structural을 갈라서 커밋한다

신규 기능에는 이 흐름을 쓰고, 빠른 구현보다 깨끗하고 테스트된 코드를 앞세운다. TDD를 적용하지 않는 경우(→ 개발 원칙)에는 기존 테스트를 먼저 돌리고 변경 후 다시 돌린다.

테스트는 한 번에 하나씩 쓰고, 돌게 만든 다음, 구조를 다듬는다. 매번 전체 테스트를 돌린다(오래 걸리는 것 제외).

UI는 아래 문서에서 가이드와 예시를 받아 의견을 제시한다.
https://developer.apple.com/kr/design/human-interface-guidelines/

# PROJECT STATUS

## Overview

NeuroRune은 LLM을 위한 개인용 메모리 시스템 (외장 해마/personal harness).
대화를 마크다운으로 저장하고 GitHub에 영속화해서, 세션 간 컨텍스트 연결성을 제공.

**영감**: Epic Games *Infinity Blade* (2010)의 Bloodline 시스템 — 캐릭터가 죽어도 후손이 경험치/장비를 계승. LLM의 세션 단절을 같은 방식으로 해결.

**대조**: 다마고치 = 매번 새로 키움 (현재 LLM 채팅) ↔ Bloodline = 세대 간 계승 (NeuroRune)

## Tech Stack

- Swift 6 Strict Concurrency
- iOS 17.0+
- SwiftUI
- TCA (The Composable Architecture) 1.25.5
- URLSession (Alamofire 등 외부 네트워크 라이브러리 X)
- Keychain Services
- swift-markdown-ui
- Swift Testing (Unit), XCTest (UI)

**외부 API**:
- Anthropic Messages API (Claude)
- Groq Whisper STT (Sprint 3, 다국어 음성 인식 — SFSpeechRecognizer·Clova 대비 한글 정확도 우수)
- ElevenLabs TTS (Sprint 3, BYOK 음성 합성 — Azure 대비 자연스러움 + 동적 voice 목록)
- GitHub REST API (Sprint 2, 메모리 동기화)

## Architecture

```
View (SwiftUI)
    ↕ (TCA Store)
Reducer (State + Action + Effect)
    ↕
Client (LLMClient, KeychainClient, GitHubClient, STTClient)
    ↕
External (Anthropic, Groq, GitHub)
```

- **TCA**: 단방향 데이터 플로우, State + Action + Reducer + Effect 분리
- **DI**: TCA dependencies (`@Dependency`)
- **BYOK** (Bring Your Own Key): API 키는 사용자가 직접 입력 → Keychain 저장. 앱에 키 미내장
- **모델 선택**: 세션 단위 (per-message X, 컨텍스트 일관성 유지)

## Sprint Roadmap

### Sprint 0 — Setup (Done, 2026-04-11)
- ✅ Xcode 프로젝트 (iOS 17.0, SwiftUI, Swift Testing)
- ✅ TCA 1.25.5 의존성 추가
- ✅ Git flow (main / develop / feat/xxx)

### Sprint 1 — Chat (Done, Apr 11-12)
- [x] Anthropic API 클라이언트 (LLMClient + AnthropicClient)
- [x] Keychain API 키 저장 + 첫 실행 온보딩
- [x] 채팅 세션 영속화 (SwiftData)
- [x] 마크다운 렌더링 (swift-markdown-ui)
- [x] 세션 단위 모델 선택

### Sprint 2 — Memory (Apr 13~)
- [x] GitHub API 메모리 동기화 (PAT 기반, .global/.local 두 role)
- [x] 메모리 컨텍스트 주입 (MEMORY.md 자동 + read_memory tool 동적 로드)
- [x] 사용자 직접 메모리 편집 + commit (MemoryEditView/MemoryCreateView)
- [x] tool 호출 transparency UI (read_memory 호출 시 채팅에 파일명 칩)
- [x] write_memory tool + 쓰기 확인 modal (file name + diff → 사용자 accept)

### Sprint 3 — Voice & Consolidation ✅
- [x] Groq Whisper STT (STTClient) — 당초 Clova 계획 → 다국어/한글 정확도 위해 Groq 전환
- [x] ElevenLabs TTS (SpeakerClient) — 당초 Azure 계획 → 음질/동적 voice 목록 위해 ElevenLabs 전환
- [x] Consolidation: 대화 → 메모리 정제 제안 (아래 별도 섹션)

### Sprint 3 — Consolidation 상세

**핵심 통찰**: NeuroRune의 진짜 가치는 채팅도 동기화도 아닌 **정제(consolidation)** 자체. 거친 대화 → 정제된 메모리 룬으로의 변환이 메인 메커니즘. 채팅과 동기화는 그 받침대.

**메타포**: 수면 중 hippocampus → cortex memory consolidation. 사용자가 자는 동안 시스템이 raw 대화를 훑고 메모리 후보 제안.

**의존**: Sprint 1 (채팅 영속화) + Sprint 2 (GitHub 메모리 동기화) 완료 후 가능.

#### 기능

- 최근 대화 + 기존 메모리 파일을 함께 분석
- 제안 항목:
  - 새로 만들 메모리 후보
  - 기존 메모리 업데이트 후보
  - 메모리 간 모순/중복
  - 건드린 적 없어 stale해진 메모리
- **Morning digest**: 다음 날 아침 사용자가 검토 → 수락/거절/수정

#### 구현 경로

| 경로 | 방법 | 평가 |
|---|---|---|
| A. 수동 트리거 | 앱 안 *"Consolidate now"* 버튼 | Phase 1 검증용. 가장 단순 |
| B. iOS BGProcessingTask | 야간 백그라운드 자동 | iOS가 시점 결정. 정확한 새벽 약속 X |
| C. GitHub Actions | 대화 로그 push → cron Action → PR로 제안 | **권장**. git 워크플로우 안. 무료 |

→ 모바일 앱은 *"GitHub PR 검토 + 한 탭 머지"* 인터페이스로 충분.

#### 디자인 원칙

1. diff 표시 (기존 메모 업데이트 시 before/after)
2. 출처 링크 (각 제안이 어떤 대화에서 나왔는지)
3. 약장수 안티바디 주입 (consolidation 프롬프트에 `feedback_ai_overpraise.md` 통째로)
4. 보수적 디폴트 (과소 정제 > 과대 정제)

#### 가장 큰 함정

**Consolidation 자체가 약장수 자기증식 발생기가 될 수 있음**. *"매일 5개의 의미 있는 패턴 발견"* 알림 = narrative pull의 자동화 버전. 깨자마자 강제 의미 부여를 받음.

→ 방지: *"오늘은 정제할 만한 새 패턴 없음"*이 정상 답이라는 명시. **조용한 morning이 좋은 morning**. 매일 뭔가 제안하는 시스템 = 약장수.

#### 검증 단계

1. **Phase 1**: 수동 *"Consolidate now"* 버튼 — 가장 작은 검증
2. **1주 사용 후**: 제안 수락률 평가 (30% 이상 = 가치 있음)
3. **수락률 낮으면**: 프롬프트/안티바디 조정
4. **검증 후**: Phase 2 자동 야간 실행 검토

## Current Modules

Sprint 3 완료 시점 기준. 신규 디렉토리 추가 시 이 표 갱신.

| 영역 | 역할 |
|------|------|
| **App** (`NeuroRuneApp.swift`) | TCA Store root, app entry |
| **Domain/** | 도메인 타입 — LLM / Memory / Speech / Consolidation / Credentials |
| **Clients/LLM** | Anthropic Messages API + 모델 추상화 (스트리밍 / tool 호출) |
| **Clients/Memory** | GitHub REST API — 메모리 read / write / diff |
| **Clients/Speech** | Groq Whisper STT + ElevenLabs TTS |
| **Clients/Consolidation** | 대화 → 메모리 정제 제안 (Sprint 3) |
| **Clients/Credentials** | API 키 Keychain 저장 (BYOK — Anthropic / Groq / ElevenLabs / GitHub PAT) |
| **Clients/Foundation** | URLSession 기반 HTTP / 공통 네트워크 유틸 |
| **Features/Chat** | 채팅 reducer — 스트리밍 수신, STT, tool 호출, write_memory 확인 모달 |
| **Features/Memory** | 메모리 편집 · 동기화 · diff |
| **Features/ConversationList** | 채팅 세션 리스트 |
| **Features/Consolidation** | 정제 제안 / morning digest |
| **Features/Settings** | API 키 / 모델 / voice 선택 |
| **Persistence** | SwiftData ModelContainer — 채팅 세션 · 메시지 영속화 |
| **Views/** | SwiftUI — Chat / Memory / Settings / Consolidation / Root |
| **Logging** | NRLog — OSLog 카테고리(network / state / persistence / consolidation) |
| **Utilities** | swift-markdown-ui 렌더, async helpers, 공용 유틸 |
| **UITestSupport** | mock launch argument 기반 결정적 XCUITest 환경 |

## Key Concepts

- **BYOK**: 사용자가 본인 API 키를 입력 (Anthropic, Groq, GitHub PAT). 앱에 키 미내장 → 비용 부담 없음 + 사용자 통제
- **Bloodline**: 세션 간 메모리 계승. LLM의 H.M. 환자 같은 단기 기억만 있는 한계를 외부 마크다운으로 보완
- **External Hippocampus**: 사용자가 마크다운 큐레이션으로 LLM의 장기 기억 역할 수행
- **Personal Harness**: 한 명을 위한 AI 메모리/지시 통합 시스템 (2026년 등장한 "harness engineering" 개념의 개인용 버전)
- **Bring Your Own Memory**: 메모리 파일을 GitHub에 두면 사용자가 직접 보고 편집 가능. 클라우드 블랙박스 X

## Inspired by

- William Gibson, *Neuromancer* (1984) — cyberdeck
- Richard Garriott, *Ultima IV* (1985) — 8 runes of virtue
- Dario Amodei, *Machines of Loving Grace* (2024) — AI roadmap
- 김창준, *애자일 이야기* — human-centered development
- Epic Games, *Infinity Blade* (2010) — Bloodline system

## Build & Test Commands

```bash
# 전체 빌드
xcodebuild -project NeuroRune.xcodeproj -scheme NeuroRune -destination 'platform=iOS Simulator,name=iPhone 17' build

# 테스트 (순차 모드 — 이 프로젝트 규모에서는 병렬보다 빠르고 duration 리포팅도 정확)
xcodebuild -project NeuroRune.xcodeproj -scheme NeuroRune -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
```

## Git Flow

```
main           ← 안정/배포 가능 상태 (Sprint 단위 머지)
  ↑
develop        ← 통합 (feat/xxx 머지됨)
  ↑
feat/xxx       ← 기능별 작업 단위 (한 PR = 한 변경)
```

- `feat/xxx`는 작은 단위로 (TCA reducer 1개, Keychain 모듈 1개 식)
- PR base는 항상 `develop`
- 머지된 feat 브랜치는 즉시 삭제 (로컬 + 원격)
- main 업데이트는 Sprint 종료 시점

## Workflow Notes

- **BYOK 키 입력 UI**: 첫 실행 시 안내 + 발급 방법 스크린샷 (비개발자 사용자 대비)
- **에러 처리**: API 키 누락, 네트워크 실패, rate limit, 모델 응답 오류 각각 분리
- **로깅**: OSLog 카테고리별 분리 (network, keychain, llm, memory)
- **시뮬레이터 vs 실기기**: STT는 실기기 권장 (시뮬레이터 마이크 한계)


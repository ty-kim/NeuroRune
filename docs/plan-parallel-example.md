# Parallel Worktree Plan — 샘플

> Git worktree 기반 병렬 에이전트 실행 계획 템플릿.
> 예시: NeuroRune Sprint 2 (Memory) 병렬 버전.

---

## Sprint 2 — Memory (Parallel)

### 개요
사용자 GitHub repo에 대화 메모리 저장·편집·주입 기능 추가.
**순차 5일 → 병렬 2-3일 목표**.

---

## Phase 0 — Foundation (main, 단일)

**목적**: 이후 모든 작업의 공통 기반. 인터페이스·에러·도메인 타입 확정.

- [ ] `MemoryPathPolicy` 프로토콜 (`.global` / `.local` role)
- [ ] `MemoryError` enum (unauthorized / notFound / network / decoding)
- [ ] `MemoryEntry` 도메인 struct (path, content, role, commitSha)
- [ ] `GitHubClient` 프로토콜 (list / load / save / delete)
- [ ] `MockGitHubClient` (TestStore용)

**완료 조건**: `main` 컴파일 통과 + 프로토콜 단위 테스트 OK.
**예상 시간**: 0.5일 (4시간).
**담당**: 단일 세션 (인터페이스 판단 집중).

---

## Phase 1 — 병렬 실행 (worktree 4개)

### Agent 1 — `GitHubClientLive`
- **브랜치**: `exp/github-live`
- **파일**: `NeuroRune/Clients/GitHubClient/GitHubClientLive.swift` (신규)
- **작업**: PAT 기반 GitHub API 호출. list/load/save/delete 4개 메서드 완전 구현.
- **성공 조건**:
  - `GitHubClient` 프로토콜 완전 구현
  - 실제 repo 연동 테스트 통과
  - `[structural]`/`[behavioral]` 태그 유지
- **예상**: 4-6시간

### Agent 2 — `MemoryEditView` UI
- **브랜치**: `exp/memory-edit-ui`
- **파일**: `NeuroRune/Views/Memory/MemoryEditView.swift` (신규)
- **작업**: TextEditor + role selector + commit 버튼. Mock 바인딩.
- **성공 조건**:
  - Preview 동작 확인
  - 접근성 라벨
  - Dynamic Type 대응
- **예상**: 3-4시간

### Agent 3 — `MemoryEditFeature` (TCA Reducer)
- **브랜치**: `exp/memory-edit-feature`
- **파일**: `NeuroRune/Features/MemoryEdit/MemoryEditFeature.swift` (신규)
- **작업**: State/Action/Reducer. loadMemory / commitMemory / deleteMemory.
- **성공 조건**:
  - TestStore 기반 테스트 전부 통과
  - Dependency 주입 명확
- **예상**: 4-5시간

### Agent 4 — `MEMORY.md` 자동 주입
- **브랜치**: `exp/auto-inject`
- **파일**: `NeuroRune/Clients/LLMClient/SystemPromptBuilder.swift` (신규)
- **작업**: Claude API 요청 시 `MEMORY.md` 내용 자동 포함.
- **성공 조건**:
  - 실제 API 호출 시 주입 로그 검증
  - 200K 토큰 초과 시 잘라내기 정책
- **예상**: 2-3시간

---

## Phase 2 — 통합·순차 (병렬 X)

### 머지 순서 (충돌 리스크 낮은 것부터)
1. **Agent 4** (`exp/auto-inject`) — 독립, 충돌 위험 최소
2. **Agent 1** (`exp/github-live`) — Agent 3이 의존
3. **Agent 3** (`exp/memory-edit-feature`) — rebase 후 Agent 1 사용
4. **Agent 2** (`exp/memory-edit-ui`) — Agent 3 Feature와 결합

### 통합 작업
- [ ] `MemoryEditView` + `MemoryEditFeature` 결합
- [ ] `write_memory` tool 구현 (Agent 1 + Agent 4)
- [ ] End-to-end 통합 테스트 (실 GitHub repo)
- [ ] 에러 플로우 (401 / 404 / 네트워크 실패)

**예상**: 1일 (8시간)
**담당**: 단일 세션 (머지·통합 판단).

---

## 의존성 그래프

```
[Phase 0: Foundation]
         │
         ▼
┌────────┼────────┬──────────┐
▼        ▼        ▼          ▼
Agent 1  Agent 2  Agent 3    Agent 4
(Live)   (UI)    (Feature)   (AutoInject)

         │          │
         └──────────┘
              │
              ▼
       [Phase 2: 통합]
```

**병렬 가능**: Agent 1·2·3·4 서로 독립
**머지 의존**: Agent 3 ← Agent 1 (GitHubClientLive 사용)

---

## 충돌 리스크 매트릭스

| 조합 | 확률 | 겹치는 영역 | 대응 |
|---|---|---|---|
| 1 × 2 | 낮음 | 없음 | — |
| 1 × 3 | 중간 | GitHubClient 프로토콜 호출 | Phase 2 순차 머지 |
| 2 × 3 | 중간 | MemoryEdit 모듈 | TCA bind 시점 조율 |
| 1 × 4 | 낮음 | 다른 Client | — |
| 3 × 4 | 낮음 | 독립 모듈 | — |

---

## 시간·자원 트레이드오프

| 방식 | 시간 | 토큰 | 인지 부담 |
|---|---|---|---|
| 순차 | 5일 | 1× | 낮음 |
| 4 병렬 | 2-3일 | 4× | 높음 |
| **2-3 병렬 (권장)** | **3-4일** | **2-3×** | **중간** |

### 권장 실행 순서
- **Day 1 오전**: Phase 0 (단일)
- **Day 1 오후 ~ Day 2**: Agent 1 + Agent 4 병렬
- **Day 3**: Agent 2 + Agent 3 병렬 (Agent 1 머지 후 rebase)
- **Day 4**: Phase 2 통합

---

## Worktree 명령어

### 생성
```bash
# Phase 1 시작 — worktree 4개 생성
git worktree add ../NeuroRune-a1 -b exp/github-live
git worktree add ../NeuroRune-a2 -b exp/memory-edit-ui
git worktree add ../NeuroRune-a3 -b exp/memory-edit-feature
git worktree add ../NeuroRune-a4 -b exp/auto-inject
```

### 청소
```bash
# Phase 2 완료 후
git worktree remove ../NeuroRune-a1
git branch -d exp/github-live
git worktree remove ../NeuroRune-a2
git branch -d exp/memory-edit-ui
# ... 각 worktree 반복
```

### 확인
```bash
git worktree list
```

---

## 성공 기준 체크리스트

### Phase 0
- [ ] 프로토콜 컴파일 통과
- [ ] Mock GitHubClient 단위 테스트 OK
- [ ] `main` 브랜치 기준으로 Phase 1 시작 가능

### Phase 1 (각 agent)
- [ ] 브랜치별 단위 테스트 통과
- [ ] SwiftLint 위반 0
- [ ] `[structural]`/`[behavioral]` 태그 규율 유지
- [ ] 커밋 단위 Tidy First 준수

### Phase 2
- [ ] 전체 머지 완료 (충돌 해결)
- [ ] 통합 테스트 통과
- [ ] 실 GitHub repo E2E 확인
- [ ] VoiceOver·Dynamic Type 기본 통과
- [ ] Known Limitations 문서 업데이트

---

## 롤백·이탈 계획

### Phase 1 agent 실패 시
- `git worktree remove ../NeuroRune-aN` → 해당 agent 재시도
- 다른 agent 영향 없음 (격리 효과)
- 필요 시 수동 구현 전환

### Phase 2 머지 충돌 과다
- 순차 머지 중단
- 문제 브랜치 `rebase -i` 수동 해결
- 최악: 해당 기능 다음 Sprint 이월

### 토큰 예산 초과
- 4 병렬 → 2-3 병렬로 축소
- Agent 2·3 순차 전환 (UI·Feature 묶음)
- 일정 연기

### 인지 부담 과다
- 하루 3개 이상 동시 금지
- 머지 리뷰 일정 분산
- 휴식 확보

---

## Tidy First 규율 (각 worktree 공통)

- `[structural]`: 리팩토링·이동·이름 변경
- `[behavioral]`: 기능 추가·동작 변경
- 한 커밋에 섞지 말 것
- 구조 변경 먼저, 동작 변경 나중

### 커밋 메시지 예시
```
refactor: MemoryEditFeature State 분리 [structural]
feat: loadMemory action으로 GitHubClient 호출 [behavioral]
test: loadMemory 성공·실패 경로 추가 [structural]
```

---

## 템플릿 재사용

다른 Sprint·프로젝트 적용 시 바꿀 것:
- Phase 0 인터페이스 목록
- Agent 수 (2-5개 권장)
- 파일 경로
- 의존성 그래프
- 예상 시간

유지할 구조:
- Phase 0 → 1 → 2 3단 구조
- Agent별 파일 독립 할당
- 충돌 리스크 매트릭스
- 시간·토큰·인지 부담 3축
- 롤백 계획

---

## 장비 사양별 권장 병렬 수

| 장비 | RAM | 안정 병렬 | 극한 |
|---|---|---|---|
| MacBook Air M4 16GB | 16GB | 2-3 | 3-4 (스로틀) |
| MacBook Pro M5 Pro 48GB | 48GB | 5-7 | 8-10 |
| MacBook Pro M5 Max 64GB | 64GB | 7-10 | 12+ |

**실용 권장**: 인지 한계로 **3-5개**가 대부분 상한.

---

## 참고

- 이 템플릿은 보리스 체르니 (Anthropic) Claude Code 병렬 에이전트 데모 기반
- 실험 병렬 vs 기능 병렬 구분:
  - **실험 병렬**: 같은 문제의 3가지 해법 비교 (STT·TTS·아키텍처 선택)
  - **기능 병렬**: 독립 기능 동시 구현 (이 문서의 Sprint 2 케이스)

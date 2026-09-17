# 테스트 플레이북

`CLAUDE.md` 에서 분리한 참조 문서. **Phase 종료 시**, 또는 아래 증상이 나타났을 때 읽는다.

- 테스트가 느리거나 CI에서만 간헐 실패 → 「증상」 섹션
- Phase/Sprint 종료 → 「약한 테스트 5유형 체크리스트」
- 새 타입을 설계할 때 → 「테스터블 코드 체크리스트」

---

# 테스트 진단·감사 플레이북

**테스트도 Tidy First 대상.** AI 생성 테스트에는 tautology/change detection/flaky가 섞인다.
개인 프로젝트 두 개의 단위 테스트 579개를 5유형 체크리스트로 훑어, 11개를 제거하고 1개를 바로잡았다(약 2%).
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
3. 약한 테스트는 삭제·재작성하고 `[structural]` 커밋 후보로 묶는다
4. 삭제보다 **behavior 검증으로 재작성**이 나을 때도

## 약한 테스트 5유형 체크리스트

1. **Initializer tautology**: `T(a: 1).a == 1` — Swift memberwise init 테스트
2. **Literal array count**: 배열 만들고 `count == N`
3. **Self-referential constant**: `T.key == "key"`
4. **Auto-generated Equatable**: 단순 struct `a == b` 검증
5. **Factory self-check**: Factory가 세팅한 값 재확인

## 증상: 테스트가 느리다 / CI에서만 간헐 실패한다

테스트가 실제 시간을 기다리면 **flaky + TDD 사이클 체감 저하** 두 방향으로 손해. 두 패턴을 모두 점검.

### 1) Task.sleep / Thread.sleep

`Task.sleep(ms:N)` 기반 테스트는 **brittle**. CI flaky 유발.
→ **Continuation gate** 패턴으로 전환 (`MockBookRepository.blockUntilReleased` 같은 것).

### 2) Clock.sleep (TCA `@Dependency(\.continuousClock)`)

프로덕션 reducer에서 `clock.sleep(for: .seconds(N))`을 쓰고 테스트에서 `continuousClock`을 대체하지 않으면 **실제 N초 대기**. 30개 테스트가 이 플로우 타면 TDD 사이클에서 30초가 묵묵히 증발.
→ 공용 dependencies 헬퍼에 `deps.continuousClock = ImmediateClock()` 기본 주입
→ 시간 흐름 검증이 필요한 테스트만 `TestClock()` 명시 override

### 증상: sleep 잔재가 의심될 때 확인할 것

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

### 3) 증상: 여러 테스트가 정확히 `1.000` / `2.000 seconds`로 찍힌다 — 병렬 모드 리포팅 아티팩트

xcodebuild의 **병렬 모드**(기본값)에서는 Swift Testing → 레거시 `Test case ... (N.NNN seconds)` 포맷 변환 시 duration 전달에 실패하면 **`1.000 seconds`를 기본값으로 찍음**. 실제 테스트는 ms 단위인데도 1초로 보여서 **원인을 오판하기 쉬움**.

→ **해결**: `-parallel-testing-enabled NO` 추가. 테스트 플랜(`-testPlan`)은 `parallelizable`이 기본 꺼짐이라 플래그 없이도 순차로 돈다.
- NeuroRune 규모(대부분 단위 테스트, UI 스모크는 3개)에서는 병렬 모드가 시뮬 clone 부팅 오버헤드로 오히려 느림
- 순차 모드는 Swift Testing 네이티브 포맷(`✔ Suite ... passed after X.XXX seconds`)으로 정확한 duration 표시

### 진단 순서

1. **순차 모드로 재실행** (`-parallel-testing-enabled NO`) → 개별 테스트 실제 시간 확인
2. 여전히 느린 테스트가 있으면 Clock/sleep 주입 점검
3. Reducer 내 `clock.sleep`, `Task.sleep` 스캔

---

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

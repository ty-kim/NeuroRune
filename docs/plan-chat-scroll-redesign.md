# Chat Scroll Redesign Plan

## 배경

`ChatMessageList`의 bottom scroll 동작이 수동 `ScrollViewReader` + `sentinel` + 여러 notification listener + `DragGesture` 조합으로 얽혀 있음. 다음 문제를 동시에 만족해야 하는데 현재 구조는 한계 도달.

### 만족해야 할 요구사항

| # | 시나리오 | 기대 동작 |
|---|---|---|
| 1 | 앱 재진입 | 최하단 자동 표시 |
| 2 | 첫 전송 + 키보드 up | 공백 없이 bottom 유지 |
| 3 | 두 번째 전송 (원래 버그) | 공백 없음 |
| 4 | 스트리밍 중 토큰 유입 | bottom 유지 |
| 5 | 위로 스크롤 후 새 메시지 | auto-follow 꺼짐 |
| 6 | auto-follow 꺼진 상태에서 bottom까지 스크롤 | 재활성 |
| 7 | 스트리밍 중 입력창 탭 → 키보드 up | bottom 유지 |
| 8 | 키보드 애니메이션 중 | 공백 jitter 없음 |
| 9 | 전체 기간 | 위아래 바운스 없음 |

현재 원본(HEAD) 상태: 2·4·5·9는 OK, 1·3·7·8은 부분적/실패.

## 시도 히스토리 (2026-04-24)

### 시도 1. 코덱스의 `reason` 기반 추상화
- `scheduleBottomScroll(using:delay:)` → `scheduleBottomScroll(using:reason:)`
- `ChatBottomScrollTiming` 모듈로 reason → delay 매핑
- TDD 테스트 3건 추가
- **결과**: 증상 완화 실패 + 키보드 up 시 화면 위로 점프하는 신규 회귀. 폐기.
- **교훈**: 매직 delay 테이블은 근본 해결이 아님. reason마다 올바른 delay는 기기/iOS 버전마다 다름.

### 시도 3. 접근 A — `safeAreaInset(edge: .bottom)` (2026-04-24)
- `ChatView`의 VStack 해체. `ChatMessageList`에 `.safeAreaInset(edge: .bottom)`로 overlays + ChatInputBar 이전
- `ChatMessageList` 내부는 그대로 유지 (sentinel, `proxy.scrollTo`, `keyboardDidShow` 등)
- **결과**:
  - ✅ 1 (재진입) — `onAppear scheduleBottomScroll(delay: 50ms)` 덕분
  - ❌ 2, 3 (전송 공백), 4 (스트리밍 bottom), 7/8 (키보드 up) — scroll이 실제 visible bottom에 안 닿음
  - ❌ 5/6 (auto-follow)
  - ✅ 9 (바운스 없음)
- **원인 추정**: `safeAreaInset`이 가리는 영역까지 `proxy.scrollTo(sentinelID, .bottom)`이 scroll을 밀어넣어 실제 visible bottom에 안 닿음. `defaultScrollAnchor(.bottom)`도 inset 고려 안 하고 원래 bottom 기준. iOS 17에서 `safeAreaInset` + ScrollView 내부 수동 scrollTo 상호작용이 문서화 안 된 영역.
- **폐기**. 이 형태로는 쓸 수 없음.

### 시도 2. `defaultScrollAnchor(.bottom)` 기반 minimal 변경
- `scheduleBottomScroll` 헬퍼 제거, 즉시 `proxy.scrollTo` 호출
- `keyboardDidShow` / `onAppear` scroll 로직 제거 — `defaultScrollAnchor`에 위임
- **결과 1차**: 2/3 OK, 1(재진입) 실패, 7(스트리밍 중 키보드) 실패
- **결과 2차 (복구 추가)**: 1 해결, 7 처음만. 대신 **2/3 공백 재발 + 바운스 재발** — Task.yield 2번 + `pendingBottomScrollTask.cancel()` 제거가 jitter 방어선을 없앴음.
- **롤백**: `git restore`로 원본 복구.
- **교훈**:
  - `Task.yield × 2`는 content height 확정 대기 역할 (제거 시 stale scroll)
  - `pendingBottomScrollTask.cancel()`은 연속 scroll 중복 제거 (제거 시 바운스)
  - `defaultScrollAnchor(.bottom)`는 **content 확장 시만 자동 bottom 유지**. safe area 축소 + 기존 scroll offset 존재 조합에선 자동 복구 안 함

### 시도 4. 접근 D — 현재 구조 1~2줄 보강
- `keyboardDidShow` guard: `isInputFocused` → `autoFollowBottom`
- `keyboardWillShow` 리스너 신규 (jitter 완화 목적)
- **결과 1차 측정**: 7번(스트리밍 중 키보드) / 8번(키보드 jitter) 개선 보고 → 커밋
- **결과 2차 (다른 시나리오 실험 후 재검증)**: 8번 공백 **재현됨** — 1차 측정이 부정확했던 것. D는 실질 효과 불확실
- **조치**: D 커밋 리버트. 오늘 작업 전부 폐기, develop 원본으로 복귀
- **교훈**:
  - 한 번 측정으로 "개선" 단정 금지. 최소 **3회 반복 + 다른 시나리오 사이 검증**
  - 7번/8번 개선 주장도 편차일 가능성. 재검증 루틴 없으면 과대평가

### 시도 5. UIKit 브릿지 설계 (폐기 — 코덱스 리뷰)
- `UIViewControllerRepresentable` + `UIScrollView` + `UIStackView` + **per-message `UIHostingController`** 로 `ChatMessageList` 교체 설계
- `ChatScrollViewBridge.swift` Write 단계에서 리뷰 받음 → 파일 생성 전 폐기
- **코덱스 리뷰 핵심 3가지**:
  1. **ScrollView만 바꿔도 부모 레이아웃이 흔들리면 공백 남음** — VStack + overlays + InputBar 높이 변화까지 얽혀 있음. safeAreaInset 재실험 선행 필요
  2. **per-message `UIHostingController`는 재발명** — iOS 17 타겟이면 `UICollectionView + UIHostingConfiguration` (iOS 16+) 이 표준. diffable data source로 diff·lifecycle 대부분 처리
  3. **진짜 난제는 "bottom pin 정책"** — ScrollView 구현 자체가 아님. 아래 "핵심 통찰" 섹션 참고
- **조치**: 설계 단계 폐기

## 핵심 통찰 — 진짜 난제는 "bottom pin 정책"

ScrollView 구현 (SwiftUI vs UIKit) 선택은 수단. 진짜 풀어야 할 문제는 아래 5개 이벤트를 **정확히 구분**하고 각기 다른 반응을 정의하는 것.

### 5개 이벤트

| 이벤트 | bottom pin 기대 동작 |
|---|---|
| 1. 새 메시지 append | bottom으로 강제 이동 (autoFollow on) |
| 2. 마지막 assistant content 증가 (스트리밍) | autoFollow 상태면 bottom 유지 |
| 3. 키보드 frame 변경 (up/down) | autoFollow 상태면 bottom 유지 (user scroll 아님) |
| 4. overlay 높이 변경 (rate limit 배너 등) | autoFollow 상태면 bottom 유지 (user scroll 아님) |
| 5. 사용자 위로 스크롤 | autoFollow OFF |

### 핵심 분리선: programmatic scroll vs user scroll

`scrollViewDidScroll` (UIKit) 또는 `DragGesture` (SwiftUI) 하나만으로 autoFollowBottom을 판정하면:
- 키보드·overlay·inset 변화도 scroll offset을 바꿈 → **programmatic 변화가 "사용자 스크롤"로 오판됨** → autoFollow 꺼지는 회귀

해결:
- **`isUserDragging` 플래그** 별도 관리 (UIScrollViewDelegate `willBeginDragging` / `didEndDragging` 또는 SwiftUI DragGesture onChanged/onEnded)
- `autoFollowBottom` 판정은 `isUserDragging == true` 일 때만
- programmatic scroll(내 코드가 `setContentOffset` 호출)은 플래그 false 상태라 판정 안 됨

이 원칙은 **어느 접근으로 가도 공통**. A/B/C/D 전부 이 축을 먼저 설계해야 함.

## 재설계 목표

- 현재 수동 조합을 **한 개의 설계 축**으로 단순화
- 9개 시나리오 전부 통과
- Tidy First — 구조 변경과 behavior 변경 분리 커밋
- 회귀 방지를 위해 실기기 검증 + 시나리오별 영상 기록

## 접근 후보

### A. `safeAreaInset(edge: .bottom)` + `defaultScrollAnchor(.bottom)`

`ChatInputBar`(입력창)를 `ScrollView`의 `.safeAreaInset(edge: .bottom)`로 붙이고, ScrollView는 `.defaultScrollAnchor(.bottom)`만.

- SwiftUI가 자동으로 content 공간을 입력창 높이만큼 빼줌 → 키보드 up 시 safe area 자동 반영
- `keyboardDidShowNotification` 리스너 불필요
- `ScrollViewReader` + `proxy.scrollTo` 불필요 (anchor가 자동 처리)
- 가장 SwiftUI-native. 코드 최소

**우려**:
- 현재 `ChatInputBar`는 `ChatView` 레벨에서 별도로 배치. 리팩토링 범위 넓어질 수 있음
- autoFollowBottom 제어는 별도 필요 (사용자 위로 스크롤 감지)

### B. `scrollPosition(id:)` + sentinel id

```swift
@State private var visibleBottomID: String? = bottomSentinelID

ScrollView {
    LazyVStack { ... }
    .scrollTargetLayout()
    Color.clear.id(bottomSentinelID)
}
.defaultScrollAnchor(.bottom)
.scrollPosition(id: $visibleBottomID)
```

- sentinel id가 visible이면 autoFollowBottom = true (바인딩으로 자동)
- 사용자가 위로 스크롤하면 다른 id로 바뀜 → false

**우려**:
- iOS 17의 `scrollPosition(id:)`는 **top anchor 기본**. sentinel은 맨 끝이라 visible 판정이 직관적이지 않음
- iOS 18+에서 `anchor: .bottom` 파라미터 추가. 타겟 iOS 17이라 제약
- 실제 동작은 실험 전까지 불확실

### C. `UICollectionView + UIHostingConfiguration` (iOS 16+)

UIKit 브릿지 경로. 다만 **per-message `UIHostingController`는 쓰지 않음** (시도 5의 교훈).

- `UIViewControllerRepresentable`로 `UICollectionViewController` 노출
- `UICollectionViewDiffableDataSource` + `NSDiffableDataSourceSnapshot`으로 메시지 배열 변화 자동 처리
- 각 셀의 content는 `UIHostingConfiguration { MessageView(...) }`로 SwiftUI 재활용 (iOS 16+)
- 마지막 셀 스트리밍 업데이트는 `reconfigureItems` 로 처리
- keyboard는 `keyboardLayoutGuide` + scroll view의 `contentInsetAdjustmentBehavior` 로 자동 반영
- autoFollowBottom 판정은 UIScrollViewDelegate에서 **`isUserDragging` 플래그 + bottom 임계값** 조합

**장점**:
- bottom pin 5이벤트 모두 UIKit 수준에서 명확히 분리 가능
- scroll 타이밍 이슈(`Task.yield × 2` 등 추측 없음) 근본 해결
- diffable data source로 lifecycle 수동 관리 불필요

**우려**:
- 전체 리팩토링 1~2일 규모. overlays 배치까지 재설계 필요
- SwiftUI 쪽 onTap·dismiss 처리와 UIKit gesture 상호작용 경계 설계 필요

### D. 수동 제어 강화 (현재 구조 진화)

현재 수동 `scrollTo` 유지하되 **모든 트리거를 single source of truth로 일원화**.

- `GeometryReader` 기반 scroll offset 감지 (iOS 17 제약상 `onScrollPhaseChange` 없음)
- `isUserDragging` 플래그 도입 — DragGesture onChanged/onEnded로 set/reset
- keyboard notification 유지. programmatic 변경은 플래그 false 상태에서만 autoFollow 판정 스킵

**우려**:
- SwiftUI GeometryReader + preference key 조합이 항상 정확하지 않음
- 5이벤트 구분을 SwiftUI 레벨에서 구현하는 비용이 UIKit 대비 크고 모호

## 권장 접근 순서 (코덱스 리뷰 반영)

1. **A 재실험 — 이번엔 "제대로"**:
   - 이전 시도 3은 `ChatMessageList` 내부 수동 scrollTo·sentinel·keyboard listener를 **유지한 채** safeAreaInset만 추가해 혼합 상태 → 원인 추적 불가
   - 이번에는 **수동 scrollTo + sentinel + keyboard notification listener 전부 제거** + `defaultScrollAnchor(.bottom)` + safeAreaInset만 남기고 순수 SwiftUI 동작 검증
   - autoFollowBottom 제어는 별도 설계 (GeometryReader 또는 포기)
2. **C (UICollectionView + UIHostingConfiguration)**: A 불충분 시. UIKit 가더라도 per-message VC는 피함
3. **B (scrollPosition)**: iOS 17 제약이 커서 후순위
4. **D**: 증분 개선. 근본 해결 아님

## 시간 추정

| 단계 | 시간 |
|---|---|
| 접근 A 재실험 (제대로) | 2~3h |
| 접근 C 프로토타입 | 3~5h |
| 접근 C 프로덕션 교체 + 회귀 검증 | 1~2일 |
| 각 단계 9개 시나리오 실기기 + 영상 검증 | 접근별 1h 이상 |

**주의**: "9개 시나리오 30분" 추정은 낙관적. 각 시도마다 **최소 3회 반복 측정** + 다른 시나리오 사이 재검증 필요 (시도 4 8번 재현 교훈).

## 열린 질문

- **overlays 배치**: 메시지 리스트 밖(VStack 형제) vs 안(safeAreaInset 또는 컬렉션 supplementary view). 리스트 안에 넣으면 높이 변화가 scroll content와 함께 움직여 공백 발생 확률 감소. 밖이면 현재처럼 별도 레이어
- **"사용자가 위로 읽는 중" 판정 소유자**: View 레이어의 `isUserDragging` state (접근 A/D) vs UIScrollViewDelegate (접근 C). 후자가 정확
- **UI smoke 복구 우선순위**: scroll 재설계와 동시 진행 vs 스크롤 안정화 후에. 현재 UI 테스트 없음 → 회귀 감지 수동. smoke 2~3건이 재설계 실험의 pass/fail 판정에 도움

## 방법론

### 1. 각 접근마다 별도 브랜치
- `fix/chat-scroll-redesign-A-safearea`
- 실패 시 폐기, 원본 유지
- 성공 시 diff 최소화 + PR

### 2. 매 시도마다 9개 시나리오 전체 실기기 검증
- 시뮬 키보드 동작은 실기기와 미묘히 다름 — **실기기 필수**
- 결과 기록: 각 브랜치 README 또는 plan 하단에 표로
- **영상 녹화** (각 시나리오 10초 이하) — 회귀 판정 근거

### 3. Tidy First 엄격 적용
- 구조 변경 + behavior 변경 한 커밋에 섞지 말 것
- 리팩토링 먼저, 기능 변경 나중
- 각 커밋 후 9개 시나리오 전체 pass 유지

### 4. 테스트
- UI 테스트는 `todo.md`의 smoke test 3건에 **"두 번째 전송 공백" 시나리오 추가** 고려
- Unit 테스트는 reducer·state 변화만. scroll 동작은 UI 테스트 영역 (현재 없음)

### 5. 회귀 방지
- 매 접근 폐기 시 **왜 실패했는지** plan 하단에 기록
- 다음 접근이 같은 함정 반복하지 않도록

## 체크리스트 템플릿

각 접근 시도 시 복붙해서 실기기 결과 기록:

```
### 접근 X 결과 (YYYY-MM-DD)
- [ ] 1. 재진입 → 최하단
- [ ] 2. 첫 전송 공백 없음
- [ ] 3. 두 번째 전송 공백 없음
- [ ] 4. 스트리밍 중 bottom 유지
- [ ] 5. 위로 스크롤 후 auto-follow 꺼짐
- [ ] 6. bottom까지 스크롤 시 재활성
- [ ] 7. 스트리밍 중 키보드 up bottom 유지
- [ ] 8. 키보드 애니메이션 공백 없음
- [ ] 9. 위아래 바운스 없음
```

## 주의

- **Reducer·state 건드리지 말 것**. 이번 작업은 View 레이어 한정.
- 작업 중에 AI가 "증상 완화" 프레이밍에 빠지지 않도록 사용자가 계속 근본 원인 질문을 던져야 함.
- 한 번에 하나의 축만 건드리기. 복합 수정은 원인 추적 불가.

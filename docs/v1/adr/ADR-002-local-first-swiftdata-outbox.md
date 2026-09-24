# ADR-002 로컬 우선 저장: SwiftData 편집 원본 + Outbox + Firestore 투영

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-002 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §6.0.3, C-05, F-SOAP-01.5, F-SOAP-01.6, F-SOAP-04.2, F-PRIV-03.7, §9.6, §10.2.3, NFR-04, NFR-05, NFR-06, NFR-07, NFR-17, M-G3, AS-32 |
| 관련 에픽·스토리 | EP-05, EP-08, EP-10 / DF-014, DF-015, DF-018, DF-104, DF-107, DF-111, DF-118, DF-122, DF-206 |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [상태](#1-상태)
2. [맥락](#2-맥락)
3. [결정](#3-결정)
4. [결과](#4-결과)
5. [대안](#5-대안)
6. [PRD 근거](#6-prd-근거)
7. [재검토 조건](#7-재검토-조건)
8. [관련 스토리](#8-관련-스토리)
9. [변경 이력](#9-변경-이력)

## 1 상태

**Accepted** (2026-09-24, 소유자 CJH). PRD §10.2.3의 '편집 원본의 진실원은 SwiftData' 결정을 구체화했다. 세부 수치(백오프, 병렬도)는 V1-04 ASM-04-06, ASM-04-18이다.

## 2 맥락

- 현재 트레이너 앱은 로컬 저장이 없고 Firestore 캐시에만 의존한다. 저장 결과와 무관하게 450ms 뒤 '저장됨'을 표시하고(dfet:trainer_ios/DFETTrainer/Domain/TrainerStore.swift:177-191), 쓰기 오류는 print만 한다(dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:104).
- Runner 내장 트레이너는 UserDefaults 초안(dfet:ios/Runner/AppDelegate.swift:3368-3528)과 MethodChannel 동기화(:164-197)를 쓴다. 성공 여부를 `synced` 불리언 하나로만 돌려받는다.
- Firestore 오프라인 캐시만으로는 ① 규칙이 대기 쓰기를 거부하면 캐시에서 되돌려져 원본이 사라지고 ② '동의 → 부모 문서 → Storage → 경로' 순서를 표현할 수 없다(PRD §10.2.3, NFR-05).
- 세션 중 기록은 네트워크가 없어도 끊기면 안 된다(NFR-04, M-01).

## 3 결정

1. **편집 원본은 SwiftData(LocalStore)다.** 대상: SOAP Live·Review draft, 측정 draft, 체형 draft(사진 파일 참조), 대기 회원 등록, 현장 동의 캡처, Outbox, 로컬 바이너리 메타, TR-01 '오늘' 목록, 스테이션 프로필, 빠른 문구.
2. **모든 서버 반영은 `OutboxItem`으로 먼저 기록한다.** SyncEngine(actor)이 회원 단위로 다음 순서를 지킨다: ⓪ 대기 회원 create ① 현장 동의(`recordConsent`) ② 부모 문서 create·update(서버 커밋 확인) ③ Storage 업로드(크기·해시 대조) ④ 경로 기록 ⑤ 확정 전환.
3. **문서 ID는 클라이언트 자동 ID**(`DocumentID.make()`, 20자 `[A-Za-z0-9]`)라 오프라인에서도 확정되고 재시도가 멱등이다. create는 `setData`(merge 없음), update는 `updateData`(변경 키 + `updatedAt`)로 나눈다. `createdAt`은 create에서 한 번만 서버 시각으로 쓴다.
4. **syncState 5종**(`localSaved`, `syncing`, `synced`, `syncFailed`, `awaitingConsent`)을 로컬 항목에 저장하고 순수 함수 `SyncStateCalculator`로 계산한다. `synced`는 쓰기 completion 성공, `hasPendingWrites == false`, 업로드 대조가 모두 확인된 뒤에만 표시한다.
5. **규칙 거부 시 로컬 원본을 지우지 않는다.** 서버 읽기로 재조정한 뒤에도 거부면 `syncFailed`와 사유·재시도를 보인다. 일시 오류는 지수 백오프(2초 × 2^n, 최대 5분)이며 연속 5회면 `syncFailed`로 표시한다.
6. **오프라인 확정**은 노트를 '확정 대기'로 로컬 잠금하고, 동기화 때 `finalizedAt = serverTimestamp`를 기록한다. 거부되면 잠금을 푼다.
7. **SDK 오프라인 큐와 이중 큐를 만들지 않는다.** SyncEngine은 온라인일 때만 원격 호출을 보낸다. 재시작 시 `inFlight` 항목은 `waitForPendingWrites` + 서버 읽기로 재조정한다.
8. **Firestore 퍼시스턴스는 코드에서 명시**한다: `PersistentCacheSettings(sizeBytes: 100MB)`. 캐시는 읽기 가속용이다.
9. **로컬 파일 보호**: 앱 기본 데이터 보호 `NSFileProtectionComplete`, 디렉터리 `isExcludedFromBackup`. 업로드 확인 7일 뒤 원본 삭제, `awaitingConsent` draft는 7일 뒤 파기(AS-32). 저장소는 트레이너 uid별 파티션이다.
10. **저장소를 열지 못해도 종료하지 않는다.** `Quarantine/`으로 옮기고 복구 안내를 띄운다(반례 bodypath:ios/BodyScan/BodyScan/App/BodyScanApp.swift:32-33의 `fatalError`).

## 4 결과

**좋아지는 점**
- 네트워크·규칙 오류가 있어도 기록이 남고, 사용자는 실제 상태만 본다(NFR-04, NFR-06).
- 순서 보장으로 Storage 규칙(부모 문서 교차 조회)과 동의 규칙이 성립한다.
- SyncEngine이 프로토콜에만 의존해 가짜 원격으로 macOS에서 순서·재시도·상태 계산을 테스트할 수 있다.

**비용·위험**
- 로컬과 서버 두 벌의 모델을 매핑하는 코드가 늘어난다. 코덱은 교차 픽스처로 검증한다(ADR-005).
- `NSFileProtectionComplete`라 기기가 잠기면 동기화가 멈춘다. 백그라운드 동기화는 v1 범위 밖이다.
- 재조정 로직(서버 읽기)은 읽기 비용을 조금 더 쓴다.

**후속 작업**
- DF-014 LocalStore 스키마 v1, DF-015 SyncEngine, DF-104 FirebaseData 원격 구현, DF-107 에뮬레이터 통합 CI와 오류 주입, DF-111 오프라인 동의, DF-122 확정 대기, DF-018 로그아웃 경고.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| Firestore 오프라인 캐시만 사용 | 코드가 가장 적음 | 규칙 거부 시 대기 쓰기가 되돌려져 원본 유실, 업로드 순서 표현 불가 |
| Core Data | 성숙한 도구 | iOS 17 전제에서는 SwiftData가 간결하고 BodyPath와도 맞음 |
| JSON 파일 큐 | 단순 | 쿼리·스키마 이관이 약하고 부분 쓰기 손상 위험 |
| UserDefaults 초안(Runner 방식) | 이미 구현됨 | 크기 제한, 보호 속성 없음, 동기화 결과를 표현 못 함 |

## 6 PRD 근거

§6.0.3, C-05, F-SOAP-01.5, F-SOAP-01.6, F-SOAP-04.2, F-PRIV-03.7, §9.6, §10.2.3, NFR-04, NFR-05, NFR-06, NFR-07, NFR-17, M-G3, AS-32. 설계 반영 위치: [V1-04 §9~§11](../04_ARCHITECTURE.md#9-로컬-우선-저장-swiftdata), SwiftData 필드는 [V1-05 §12](../05_DATA_MODEL_AND_RULES.md#12-트레이너-앱-로컬-swiftdata-스키마).

## 7 재검토 조건

- P1a 실기기 측정(DF-140)에서 `localSaved` p95가 300ms를 넘으면 저장 경로(필기 직렬화)를 재설계한다.
- 잠금 상태 백그라운드 동기화가 필요하다는 현장 요구가 나오면 데이터 보호 등급을 다시 결정한다.
- SwiftData 결함으로 데이터 유실이 1건이라도 보고되면 Core Data 전환을 검토한다.

## 8 관련 스토리

DF-014, DF-015, DF-018, DF-104, DF-107, DF-111, DF-118, DF-122, DF-206.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |

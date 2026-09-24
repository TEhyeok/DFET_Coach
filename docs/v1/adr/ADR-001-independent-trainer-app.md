# ADR-001 독립 트레이너 앱: trainer_app/ + XcodeGen + TrainerCore·TrainerKit 로컬 패키지

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-001 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | D2, §10.1, §10.2.1, §10.2.2, NFR-01, NFR-03, NFR-12, NFR-14, MIG-09, G-02, Q-22, RISK-03 |
| 관련 에픽·스토리 | EP-05, EP-01, EP-13 / DF-008, DF-011, DF-017, DF-034, DF-039, DF-142, DF-904, DF-930 |
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

**Accepted** (2026-09-24, 소유자 CJH). D2(소유자 확정)를 구현 구조로 옮긴 결정이다. 패키지 2분할은 [V1-04 ASM-04-01](../04_ARCHITECTURE.md#251-가정asm-04-nn)을 반영했다.

## 2 맥락

- 트레이너 코드가 두 벌이다. 성숙한 UI는 Flutter Runner 안 `dfet:ios/Runner/AppDelegate.swift`(9,657줄, MethodChannel `dfet/native_trainer_home` :65-66, `dfet/native_soap_workspace` :30-31)에 있고, uid 기반 데이터 계층은 `trainer_ios/`에만 있다(dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:158-220).
- `trainer_ios`는 초기 커밋(2026-05-27) 이후 변경이 없는 데모 기반이다. 데모 보드, 하드코딩 x축(dfet:trainer_ios/DFETTrainer/DesignSystem/ChartsAndPencil.swift:20-26), Preview 기본 저장소(dfet:trainer_ios/DFETTrainer/Domain/TrainerStore.swift:37)가 섞여 있다.
- 현재 trainer_ios는 iOS 16.0, `TARGETED_DEVICE_FAMILY "1,2"`, 위젯 확장을 포함한다(dfet:trainer_ios/project.yml:5, :22-23, :39). 회원 앱 Runner는 iOS 15.5다(dfet:ios/Podfile:2). BodyPath는 iOS 17 전제다(bodypath:ios/BodyScan/project.yml:4-5).
- NFR-03은 Feature 모듈의 Firebase import 0건을 요구한다. grep만으로는 우회가 쉽다.
- 구현 대부분을 AI 에이전트가 병렬로 맡는다. 에이전트가 시뮬레이터 없이도 순수 로직을 검증할 수 있어야 한다.

## 3 결정

1. **새 폴더 `trainer_app/`에 D-FET Trainer를 만든다.** 번들 ID `kr.co.dfet.trainer`(dfet:trainer_ios/project.yml:34)와 팀 MT27Z7369H(:9)를 재사용한다. iOS 17.0, iPad 전용(`TARGETED_DEVICE_FAMILY "2"`)이 기본이며, Q-22에서 iPhone 배포 이력이 확인되면 `"1,2"`로 바꾸고 compact 제한 기능(열람, Live 한 줄)만 둔다.
2. **XcodeGen으로 프로젝트를 생성하고 `DFETTrainer.xcodeproj`를 커밋한다.** CI는 `xcodegen generate --spec trainer_app/project.yml` 뒤 `git diff --exit-code`로 최신 여부를 검증한다(BodyPath와 같은 방식, bodypath:.github/workflows/detail-capture.yml:37-47). xcodegen 버전은 `trainer_app/.xcodegen-version`에 고정한다.
3. **코드는 로컬 SPM 패키지 두 개로 나눈다.**
   - `Packages/TrainerCore`(iOS 17 + macOS 14): TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics. `swift test`로 macOS에서 검증한다.
   - `Packages/TrainerKit`(iOS 17): LocalStore, FirebaseData, PostureVision, DesignSystem, Feature* 11개.
   - 나누는 이유: 한 패키지에 UIKit 타깃이 있으면 macOS `swift test`가 그 타깃까지 빌드하다 실패한다(2026-09-24 프로브로 확인).
4. **Firebase는 FirebaseData 타깃에서만 import한다.** App 타깃은 `FirebaseBootstrap.configure(_:)`를 호출한다. Feature에 Firebase 제품을 링크하지 않아 위반이 컴파일 오류가 된다.
5. **`trainer_ios/`는 이식 원본으로 동결한다.** 신규 코드를 넣지 않고 P1a 종료 PR(DF-142)에서 삭제하며 이력은 태그 `archive/trainer_ios-final`로 보존한다.
6. **Runner 내장 트레이너는 P0부터 동결**(규제·크래시·데이터 유실 수정만, `freeze-exception` 라벨)하고 P3에 제거한다(MIG-09).
7. **위젯 확장과 App Group은 v1에서 넣지 않는다**(AS-DEV-05, NFR-14).

폴더 구조와 `Package.swift`·`project.yml` 사양은 [V1-04 §5, §6.3](../04_ARCHITECTURE.md#63-패키지프로젝트-사양).

## 4 결과

**좋아지는 점**
- 이식 코드와 데모·결함 코드가 섞이지 않아 리뷰와 에이전트 작업의 기준선이 분명하다.
- 모듈 경계를 컴파일러가 강제한다(NFR-03).
- 순수 로직(코덱, 확정 요건, 자세 산식, Outbox 순서)을 시뮬레이터 없이 빠르게 테스트한다.
- Feature 단위 타깃이라 여러 에이전트가 병렬로 작업해도 충돌이 적다.
- 생성된 `.xcodeproj`를 커밋하므로 xcodegen이 없는 환경에서도 열 수 있다.

**비용·위험**
- 패키지가 둘이라 의존 선언이 늘어난다. 스파인 문서의 일부 경로(`Packages/TrainerKit/Sources/TrainerDomain` 등)는 `Packages/TrainerCore/...`로 읽어야 한다.
- 번들 ID 재사용은 App Store Connect 이력(Q-22)에 묶인다. iPhone 지원 빌드가 배포된 적 있으면 iPad 전용으로 바꿀 수 없다.
- 이식 동안 Runner 동결로 요구가 쌓일 수 있다(RISK-03). 동결 예외 절차로 관리한다.

**후속 작업**
- DF-008 골격과 trainer-app CI, DF-017 AppShell, DF-011 static-guards, DF-034 plist 주입, DF-039 이식 지도, DF-142 trainer_ios 삭제, DF-904 Q-22 확인, DF-930 동결 선언.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| trainer_ios 제자리 재작성 | 폴더·프로젝트 재사용 | 데모 코드와 섞여 기준선이 흐려지고 결함(§10.3)을 옮길 위험 |
| Runner 내장 화면 분할 | 성숙한 UI 그대로 | 회원 앱 iOS 15.5 제약과 릴리스 주기에 묶이고 BodyPath(iOS 17)와 맞지 않음 |
| 단일 타깃 + 폴더 구조 | 설정 단순 | 모듈 경계가 grep에만 의존 |
| 단일 TrainerKit 패키지 | 스파인과 경로 일치 | macOS `swift test` 불가(순수 테스트도 시뮬레이터 필요) |
| Tuist | 모듈 선언 풍부 | 새 도구 도입 비용. XcodeGen은 두 저장소가 이미 사용 |

## 6 PRD 근거

D2, §10.1 구성도, §10.2.1 출처별 이식 범위, §10.2.2 분할 이식 계획, NFR-01, NFR-03, NFR-12, NFR-14, MIG-09, G-02, Q-22, RISK-03.

## 7 재검토 조건

- Q-22 결과 iPhone 배포 이력이 있음 → `TARGETED_DEVICE_FAMILY "1,2"`와 compact 제한 기능 명세 추가.
- SwiftPM이 플랫폼별 타깃을 지원하게 되거나 순수 타깃 테스트를 시뮬레이터로만 돌려도 되는 경우 → 단일 패키지로 합칠지 재검토.
- Q-03에서 iPad LiDAR 촬영이 결정됨 → BodyPathCore 계산 코어 의존 추가(ADR-012).

## 8 관련 스토리

DF-008, DF-011, DF-017, DF-034, DF-039, DF-142, DF-904, DF-930.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |

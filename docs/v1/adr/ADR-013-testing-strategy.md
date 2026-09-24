# ADR-013 테스트 전략: 계약 픽스처 + 에뮬레이터 + 합성 데이터

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-013 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §12.5, §9.4 규칙 테스트 매트릭스, §9.5 Storage 테스트, §7.9, NFR-04~NFR-07, AC-IA-01, AC-A11Y-01~03, M-G4, G-03 |
| 관련 에픽·스토리 | EP-01, EP-03 / DF-022, DF-035, DF-023, DF-031, DF-107, DF-140, DF-141, DF-223 |
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

**Accepted** (2026-09-24, 소유자 CJH).

## 2 맥락

- 현재 규칙 테스트에는 soap_notes 케이스가 0건이고 describe는 임상, 프로필, 작업공간, 커뮤니티, Storage뿐이다(dfet:functions/test/firestore-rules.test.js:67, :105, :151, :209, :226).
- CI는 에뮬레이터로 규칙 테스트와 Functions e2e를 돌린다(dfet:.github/workflows/ci.yml:53, :55). firebase.json에는 firestore(18080)·storage(19199) 에뮬레이터만 설정돼 있다(dfet:firebase.json:37-50).
- 스테이징 프로젝트가 없다(AS-DEV-02). 실데이터는 G-04·G-09 전에 쓸 수 없다.
- 트레이너 앱 호환 테스트는 Swift → Swift 왕복뿐이다(PRD §9.3).

## 3 결정

테스트는 여덟 층으로 구성한다.

| 층 | 대상 | 도구 | 실행 |
|---|---|---|---|
| ① 순수 로직 단위 | TrainerCore, functions `core`, Dart 모델 | `swift test`(macOS), `node:test`, `flutter test` | 매 PR |
| ② 계약 교차 | SOAP v2 왕복, 자세 산식 벡터, 판정 T01~T25(P3) | `contracts/fixtures`, `contracts/vectors` | 매 PR |
| ③ 규칙 에뮬레이터 | R-01~R-31, S-01~S-08 | `firebase emulators:exec --only firestore,storage` | 매 PR(G-03) |
| ④ Functions e2e | 동의, 재정렬, 삭제 연쇄, 파기, 초대, 요약 | `--only functions,firestore,storage` | 매 PR |
| ⑤ 트레이너 앱 통합 | Outbox 순서, 규칙 거부·네트워크 오류 주입, syncFailed, 오프라인 복구 | 시뮬레이터 + 에뮬레이터(`demo-dfet`, auth·functions 포트 추가) | 경로 PR + 야간 |
| ⑥ UI | `--preview-*` 시나리오, 접근성 감사, §8.4 상태 매트릭스 스냅샷 | XCUITest, swift-snapshot-testing(테스트 전용), Flutter 골든 | 매 PR |
| ⑦ 실기기 수동 | 촬영, 4방향, Split View, 비행기 모드, 프록시 관찰, Instruments | V1-T09 기록 | 단계마다 |
| ⑧ 이관 리허설 | MIG-03~06 적용 → 롤백 → 재적용, 멱등 | 에뮬레이터 + 레거시 픽스처 | 경로 PR |

운영 원칙
- 모든 개발·테스트 데이터는 가상 회원 합성 데이터만 쓴다. 실데이터, `output/`, `tmp/`, 운영 export를 열람하지 않는다.
- S-09(교차 서비스 규칙 실환경)는 소유자가 가상 데이터로 확인한다(DF-038).
- 오류 주입은 FirebaseData의 원격 프로토콜을 감싸는 `FaultInjectingRemoteWriter`(IntegrationTests 전용)와 에뮬레이터 규칙 변형으로 한다. 앱 본체에 테스트 훅을 두지 않는다.

## 4 결과

**좋아지는 점**
- 규칙·동기화·계약 회귀를 매 PR에서 잡는다(M-G4).
- 에이전트가 운영 데이터 없이 증빙을 만들 수 있다.

**비용·위험**
- macOS 러너 시간이 늘어난다(trainer-app, emulator-it).
- 에뮬레이터와 실환경 차이(교차 서비스 규칙, App Check)는 수동 확인에 의존한다.

**후속 작업**
- DF-022·DF-035 규칙 테스트, DF-023 Storage 테스트, DF-031 이관 CI, DF-107 통합 CI, DF-141·DF-226 스냅샷, DF-140·DF-223 실기기.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| 실기기 수동 위주 | 준비 적음 | 회귀를 잡지 못함 |
| 스테이징 프로젝트 E2E | 실환경에 가까움 | v1에는 스테이징 없음(AS-DEV-02) |
| Swift 스냅샷 자체 헬퍼(ImageRenderer) | 의존성 없음 | 유지 비용 큼 |

## 6 PRD 근거

§12.5, §9.4 규칙 테스트 매트릭스, §9.5 Storage 테스트, §7.9, NFR-04~NFR-07, AC-IA-01, AC-A11Y-01~03, M-G4, G-03. 설계 반영 위치: [V1-10 테스트 계획](../10_TEST_PLAN.md), [V1-04 §19.1](../04_ARCHITECTURE.md#191-환경).

## 7 재검토 조건

- 스테이징 프로젝트가 생기면 ⑤ 일부를 실환경 E2E로 옮긴다.
- 에뮬레이터 IT가 불안정(flaky)해 2주 연속 재시도가 필요하면 야간 전용으로 내린다.

## 8 관련 스토리

DF-022, DF-035, DF-023, DF-031, DF-107, DF-140, DF-141, DF-223.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |

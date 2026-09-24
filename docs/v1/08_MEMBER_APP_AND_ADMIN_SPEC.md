# 회원 앱·관리자 웹 명세

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-08 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §8.2(회원 앱 IA), §8.3(관리자 웹), §8.4(상태), §8.5·§8.6(디자인·접근성), §6.5.0·F-VIZ-06·F-VIZ-07·§6.5.8(시각화), F-SOAP-05(Share), §6.6 F-LINK-02·03·05, §6.7 F-PRIV-01~07, §7.1·§7.6·§7.7, §9.2·§9.4·§9.6, §10.5·§10.7, §11.5·§11.6·§11.10(MIG-04·05·09), §12.3, 부록 B.8, 부록 C |
| 관련 에픽·스토리 | EP-06, EP-07, EP-08, EP-12, EP-16, EP-17, EP-18, EP-21, EP-22 / DF-007, DF-025(AD-01 부분), DF-027, DF-028(목록만), DF-029, DF-032, DF-101, DF-131, DF-135, DF-136, DF-220, DF-221, DF-306, DF-307, DF-308, DF-315, DF-316, DF-317, DF-318, DF-331, DF-383, DF-384, DF-385, DF-387, DF-389 |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [범위와 읽는 법](#1-범위와-읽는-법)
2. [현행 진단(검증된 코드 사실)](#2-현행-진단검증된-코드-사실)
3. [회원 앱 공통 설계](#3-회원-앱-공통-설계)
4. [회원 앱 화면 명세(MB-01~MB-06)](#4-회원-앱-화면-명세mb-01mb-06)
5. [회원 앱 공통 위젯](#5-회원-앱-공통-위젯)
6. [회원 SOAP 조회 결함 처리](#6-회원-soap-조회-결함-처리)
7. [P0 규제 문구 수정과 Runner 동결](#7-p0-규제-문구-수정과-runner-동결)
8. [admin_web 공통 설계](#8-admin_web-공통-설계)
9. [관리자 화면 명세(AD-01~AD-07)](#9-관리자-화면-명세ad-01ad-07)
10. [테스트 계획](#10-테스트-계획)
11. [스토리·파일 대응표](#11-스토리파일-대응표)
12. [가정(ASM-08-NN)·충돌·열린 질문](#12-가정asm-08-nn충돌열린-질문)
13. [변경 이력](#13-변경-이력)

---

## 1 범위와 읽는 법

### 1.1 이 문서가 정하는 것

| 대상 | 정하는 것 | 정하지 않는 것(정본 위치) |
|---|---|---|
| 회원 앱(Flutter, `lib/`) | MB-01~MB-06 화면, 라우트, 상태(provider), 문구 키, 오류·오프라인 표시, 접근성, 분석 이벤트 호출 지점, 공통 위젯 개조, 회원 SOAP 조회 결함 처리, P0 규제 문구 교체(회원 앱 4개 파일) | 저장소 메서드 시그니처와 callable 요청·응답([06_API_SPEC.md §9](06_API_SPEC.md#9-회원-앱-dart-계약), [§6](06_API_SPEC.md#6-신규-functions-상세-명세)), 컬렉션 필드·규칙([05_DATA_MODEL_AND_RULES.md](05_DATA_MODEL_AND_RULES.md)), seriesKey·conditionKey 산식([09_ALGORITHMS_SPEC.md](09_ALGORITHMS_SPEC.md)), 금지어 JSON 구조·린트 동작([12_COPY_ANALYTICS_AND_LINT.md](12_COPY_ANALYTICS_AND_LINT.md)) |
| 관리자 웹(`admin_web/`) | AD-01~AD-07 화면, 페이지·라우트 파일, zod 스키마, 검증 규칙, 역할 판정, 감사 호출, 내비게이션 | callable 처리 절차(06), 규칙 헬퍼(05 §7), 이관 실행(11) |
| Runner 내장 트레이너 | 동결 정책과 P0 규제 수정 목록(위치·대체어) | 새 트레이너 앱 화면([07_TRAINER_APP_SPEC.md](07_TRAINER_APP_SPEC.md)), MIG-09 제거 절차([11_MIGRATION_RUNBOOK.md](11_MIGRATION_RUNBOOK.md)) |

- **PRD가 정본이다.** 충돌하면 PRD가 우선한다. 이 문서에서 찾은 충돌과 가정은 [§12](#12-가정asm-08-nn충돌열린-질문)에 적었다.
- 저장소·callable 시그니처는 06이 정본이다. 이 문서는 06의 이름을 그대로 쓰고, 화면이 필요로 하는 추가분만 제안한다(ASM-08-03, ASM-08-04).

### 1.2 단계별 배포 묶음

| 단계 | 회원 앱 | 관리자 웹 | 스토리 |
|---|---|---|---|
| P0(S02~S05) | 플래그 8키 파서, 규제 문구 4개 파일 교체, 'SOAP 노트' 행 숨김(ASM-08-01), SOAP v2 코덱(테스트용) | AD-07 플래그 8키, AD-01 인계 안내·감사 metadata | DF-007, DF-027, DF-029, DF-025(AD-01) |
| P1a 진입 전(S06) | — | AD-03 동의 문서 버전 | DF-032 |
| P1a(S06~S14) | 공통 차트 규칙 위젯(Flutter) | 관리자 판정 claim 통일, 원 기록 열람 감사, 감사 목록 병합 조회, 권리 요청 P1a 스크립트 연계 | DF-131, DF-101, DF-136, DF-135 |
| P1b(S14~S18) | — | AD-05 지표 카탈로그, bodyChange kind 검증 | DF-220, DF-221 |
| P2(S19~S26) | MB-01~MB-06, 회원 SOAP 조회 코드 삭제 | AD-02 대기 회원·초대, AD-06 감사·권리 요청 | DF-306, DF-307, DF-308, DF-315, DF-316, DF-331, DF-317, DF-318 |
| P3(S27~S32) | 배지·'측정 오차 범위' 밴드(inHouse만), 트레이너 계정 안내(MIG-09) | AD-04 정책 운영(편집·승인·활성화·롤백), 역할 claim 분리, `lidarBeta` 복귀 | DF-383, DF-387, DF-384, DF-385, DF-389 |

스프린트 배치는 [03_RELEASE_AND_SPRINT_PLAN.md](03_RELEASE_AND_SPRINT_PLAN.md)를 따른다. 외부 게이트(G-04·G-05b·G-08 등)는 플래그 개방과 실데이터만 막고 합성 데이터 코딩은 막지 않는다.

### 1.3 표기

| 표기 | 뜻 |
|---|---|
| `dfet:경로:줄` | D-FET 저장소 코드 근거. 2026-09-24 작업 트리(브랜치 `feature/integrated-care-2026`, 미커밋 포함)에서 직접 열어 확인했다. MIG-01(DF-901) 뒤 main에서 줄 번호가 달라질 수 있다(ASM-08-02) |
| **[신규]** / **[수정]** / **[삭제]** | 파일 단위 변경 종류 |
| 문구 키 `mb05.error.invalidOrExpired` | [§3.8](#38-문구-체계와-문구-키) 문구 표의 키. 사용자 문장은 이 표가 정본이고 코드에는 키 상수로만 참조한다 |
| `messageKey` | callable 오류 키([06 §3.6](06_API_SPEC.md#36-오류-코드messagekey-카탈로그)). 회원 앱은 키를 문구로 바꿔 표시한다 |
| 합성 값 | 모든 예시는 가상 회원 데이터다. uid는 `synthMember0001`·`synthTrainerA` 형식, 문서 ID는 `SYNTH…`([V1-10 §5.2](10_TEST_PLAN.md#52-합성-식별자표시명-규약)) |

---

## 2 현행 진단(검증된 코드 사실)

### 2.1 회원 앱 구조

| 항목 | 사실 | 근거 | v1 영향 |
|---|---|---|---|
| 라우터 | `mobileRouterProvider`가 로그인·온보딩·역할 분기를 redirect로 처리한다. 트레이너·관리자는 `/trainer`로 보낸다 | dfet:lib/router/app_router.dart:33-103, :58-63 | 회원 화면 라우트만 추가한다. 직원 계정은 회원 화면에 오지 않는다 |
| 플래그 게이트 | `featureFlags`가 로드되면 gut·blood·insights 라우트를 `/home/report`로 돌린다 | dfet:lib/router/app_router.dart:78-90 | 같은 위치에 memberShare 게이트를 더한다([§3.6](#36-라우트)) |
| 4탭 셸 | `StatefulShellRoute.indexedStack` 4개 브랜치(`/home/dashboard`, `/home/record`, `/home/report`, `/home/myPage`) + `AdaptiveHomeShell` | dfet:lib/router/app_router.dart:124-161 | 4탭 유지(PRD §8.2). 새 화면은 리포트·내 정보 아래에만 |
| 상세 화면 패턴 | `parentNavigatorKey: _rootNavigatorKey` + `_DetailScaffold(title, child)` | dfet:lib/router/app_router.dart:162-169, :301-318 | MB-02~MB-06 라우트가 같은 패턴을 쓴다 |
| 리포트 허브 | `_ReportSection(keyName, label, child)` 목록을 careType·플래그로 만든 뒤 세그먼트로 보인다. 플래그 로드 전에는 `AppFeatureFlags.disabled()` | dfet:lib/screens/report_hub_screen.dart:31-59, :32-33 | `body` 섹션을 `insights` 뒤에 추가(MB-01) |
| 내 정보 탭 | `IOSProfileScreen`의 `IOSActionRow` 목록. 'SOAP 노트' 행은 `AppColors.success`(초록)로 `MemberSoapNotesScreen`을 push | dfet:lib/screens/ios_profile_screen.dart:117-128 | '트레이너 기록'(MB-03)으로 대체. 색은 중립(PRD §8.2) |
| 행 위젯 | `IOSActionRow({icon, title, subtitle, onPressed, color = AppColors.brandPrimary})` | dfet:lib/widgets/ios_adaptive_sheet.dart:87-101 | 새 행 3개가 재사용 |
| 플래그 모델 | `AppFeatureFlags`는 gut·blood·insights 3키. 없으면 false | dfet:lib/services/clinical_repository.dart:4-33, 구독 :41-45, provider dfet:lib/state/clinical_state.dart:10-12 | 8키로 확장(DF-027, [06 §9.1](06_API_SPEC.md#91-기능-플래그-확장p0-df-027)) |
| 회원 프로필 | `UserProfile`에 `trainerId`가 없다. `toMap()`은 role·isPremium 등을 함께 쓴다 | dfet:lib/models/user_profile.dart:39-66, :135-158 | 읽기 전용 `trainerId`를 추가하되 `toMap()`에는 넣지 않는다(규칙 dfet:firestore.rules:84-91 화이트리스트 밖) |
| callable 호출 | `FirebaseFunctions.instanceFor(region: 'asia-northeast3')` | dfet:lib/screens/settings_screen.dart:857-859, dfet:lib/services/community_service.dart:21 | 새 callable 전부 같은 방식 |
| 의존성 | fl_chart 0.69, cloud_functions 6.0.2, uuid, shared_preferences가 이미 있다. 푸시(`firebase_messaging`)·분석 SDK·딥링크 패키지는 없다 | dfet:pubspec.yaml:42, :54, :30-66 | 새 의존성 없이 구현한다(PRD §10.5). 공유 알림은 앱 내 '새 기록' 표시로 대신한다(Q-DEV-03) |
| 문자열 | ARB·l10n 파일이 없다. 화면 파일에 한글 리터럴이 흩어져 있다 | `find . -name '*.arb'` 결과 0건 | 새 화면은 문구 상수 파일 하나로 모은다(ASM-08-05) |

### 2.2 재사용 컴포넌트와 개조 필요점

| 컴포넌트 | 현행 동작(근거) | 회원 v1 사용 | 필요한 개조 |
|---|---|---|---|
| `DfetReportHeader` | `axis == null`이면 4축 아이콘 묶음 `_IntegratedAxisMark`를 그린다(dfet:lib/design_system/d_fet_evidence.dart:224-227, :234-259) | MB-01·MB-02 머리 | **4축 표식을 그리면 안 된다**(F-VIZ-06.7, AC-VIZ-07.3). `mark` 매개변수 추가([§5.1](#51-dfetreportheader-개조)) |
| `DfetEvidenceRibbon` | 제목이 '판정 근거와 데이터 상태'로 고정(:337), 정책 null이면 '정책 미승인'(:289-292) | MB-01·MB-02 하단 | 회원 표면에는 '판정'을 쓸 수 없다(부록 C.3). `title`·`pendingPolicyLabel` 매개변수 추가([§5.2](#52-dfetevidenceribbon-개조)) |
| `DfetEvidenceLabel` | tone neutral·pending·restricted(:9-75) | 출처 칩 바탕 | 없음. `SourceGradeChip`이 감싼다 |
| `DfetMetricValue` | 값이 없으면 `pendingLabel='산정 준비 중'`(:78-151, :83) | 지표 값 | 회원 화면은 값이 없는 highlight를 렌더하지 않으므로 pendingLabel을 쓰지 않는다. `axis: null` 고정 |
| `BloodTrendChart` | x축이 날짜가 아닌 순번(:97-99), `isCurved: true`(:101), 2점 미만 문구 고정(:27-29), 기준 범위 음영(:53-62) | 사용하지 않음 | 개조 대신 DF-131의 `SeriesTrendChart`를 새로 쓴다([§5.4](#54-seriestrendchart-df-131)). 혈액 화면은 그대로(D4) |
| `RangeBar` | 경계 하나만 있으면 다른 경계를 임의로 만든다(:26-27). 빈 문구 '승인된 정상범위가 없습니다'(:20-24) | P3 inHouse 밴드 설명에만 | P3(DF-383)에서 쓸 때 임의 경계 생성 끄기, 빈 문구 매개변수화. 회원 화면에 '정상범위' 문구 금지(부록 C.1) |
| `ComparisonCard` | 제목·값·라벨 3칸(dfet:lib/widgets/clinical/comparison_card.dart:4-58) | MB-02 전후 수치 | 배지 슬롯(`trailing`) 추가는 P3(DF-383). P2는 그대로 |
| `ProgressEfficacyCard` | 고정 임계 0.05 | **사용 금지**(MDC가 아님, PRD §6.5.8) | — |
| `DfetSignalRail`, `AxisRadarChart`, `HealthTimeline` | 4축 전용 | **사용 금지**(F-VIZ-06.7, F-VIZ-07.5) | — |

### 2.3 회원 SOAP 조회 결함

| # | 결함 | 근거 |
|---|---|---|
| 1 | 회원 쿼리가 `where('memberId', ==, uid)`만 걸고 `isSharedWithMember == true`를 걸지 않는다. 규칙은 문서별 조건 `memberId == uid && isSharedWithMember == true`라 목록 쿼리를 증명하지 못해 거부된다(정적 분석, 에뮬레이터 미확인) | dfet:lib/services/firestore_service.dart:601-603; dfet:firestore.rules:140-145 |
| 2 | 이메일 쿼리 `where('memberEmail', ==, email)`는 규칙의 어느 조건도 증명하지 못한다 | dfet:lib/services/firestore_service.dart:623-634 |
| 3 | 두 쿼리를 한 `try`로 묶고 실패하면 `[]`를 돌려준다. 화면은 '공유한 SOAP 노트가 없습니다'로 보인다(오류를 빈 목록으로 삼킴) | dfet:lib/services/firestore_service.dart:650-653; dfet:lib/screens/member_soap_notes_screen.dart:35-46 |
| 4 | 네이티브 트레이너가 쓰는 `memberId`는 로컬 `member-UUID`라 회원 uid와 같을 수 없다 | dfet:ios/Runner/AppDelegate.swift:3839 |
| 5 | 공유되면 회원이 `diagnosis`·트레이너 메모까지 든 원문 전체를 읽는 구조다 | dfet:firestore.rules:140-145; PRD §6.6 현행 결함 표 |

처리 방침은 [§6](#6-회원-soap-조회-결함-처리)에 있다. 요지는 **고쳐서 살리지 않고, P0에 진입점을 숨기고, P2에 `memberSummaries`(MB-03)로 교체**하는 것이다.

### 2.4 관리자 웹 구조

| 항목 | 사실 | 근거 | v1 영향 |
|---|---|---|---|
| 스택 | Next.js 16.2.12, React 19.2.8, zod 4.4.3, firebase 12.17.0, firebase-admin 14.2.0, Node 22 | dfet:admin_web/package.json:6, :17-23 | 새 의존성 없음 |
| 역할 판정 | `readRole`: `admin === true` 또는 `role === 'admin'` → admin, `trainer === true` 또는 `role === 'trainer'` → trainer, `role === 'lab_operator'` | dfet:admin_web/lib/auth.ts:18-23 | DF-101에서 claim만 보도록 통일(ADR-018) |
| 페이지 가드 | 서버 컴포넌트가 `requireConsoleUser(['admin'])` | dfet:admin_web/lib/auth.ts:44-51 | 새 페이지 전부 같은 방식 |
| 메뉴 권한 | `roleCanAccess`: admin 전부, trainer는 `/dashboard`, `/users`, `/requests`, `/clinical/reports`, lab_operator는 수집 2개 | dfet:admin_web/lib/auth.ts:53-61 | 새 메뉴는 admin 전용(목록 추가 불필요) |
| 메뉴 | `nav` 배열(section, label, href, icon) | dfet:admin_web/components/console-shell.tsx:9-24 | '개인정보' 섹션 추가([§8.4](#84-내비게이션)) |
| POST 라우트 패턴 | `assertSameOrigin` → `getConsoleUser` 역할 확인 → zod parse → Admin SDK → `writeAudit` → `{ok:true}` / `{error}` 400 | dfet:admin_web/app/api/admin/feature-flags/route.ts:12-29 | 새 라우트 전부 같은 순서 |
| 감사 | `writeAudit(actor, action, target, metadata)`가 `actorEmail`, `target` 맵, `createdAt`을 쓴다 | dfet:admin_web/lib/audit.ts:6-21 | DF-136에서 PRD 형식 이벤트 함수 추가(06 ASM-06-30) |
| 감사 화면 | `auditLogs orderBy createdAt desc limit 300`만 조회 | dfet:admin_web/app/(console)/audit/page.tsx:10 | 새 이벤트(`at`만 가짐)가 목록에서 빠진다. 병합 조회로 고친다([§9.6](#96-ad-06-감사-로그권리-요청)) |
| 플래그 | zod 3키, `set()`(merge 없음)으로 문서 전체를 덮어씀. 편집기도 3키 | dfet:admin_web/app/api/admin/feature-flags/route.ts:10, :20-24; dfet:admin_web/components/feature-flag-editor.tsx:6, :27 | 8키 필수로 바꾸지 않으면 저장할 때마다 새 5키가 지워진다([§9.7](#97-ad-07-기능-플래그)) |
| 배정 | 라우트가 트랜잭션으로 `trainers.memberIds`와 `users.trainerId`·`assignedTrainerId`를 함께 바꾼다. 감사 metadata는 `trainerUid`뿐 | dfet:admin_web/app/api/admin/assignments/route.ts:10-62 | 인계 안내·`handover` 추가(AD-01) |
| 배정 화면 | 트레이너 목록은 `users where isTrainer == true`, 회원 300명 | dfet:admin_web/app/(console)/assignments/page.tsx:9-16 | 동의 ④ 표시 열 추가 |
| 역할 변경 | `/api/admin/roles`가 claim(`role`, `admin`, `trainer`)과 `users`·`trainers`·`admins` 문서를 함께 바꾼다. 트레이너 해제 시 `trainers.approvalStatus = 'revoked'`, `memberIds`는 그대로 | dfet:admin_web/app/api/admin/roles/route.ts:24-76 | 해제 전 담당 회원 수 경고(AD-01) |
| 회원 상세 | trainer 역할이면 `isAssignedMember`로 범위 제한. `soap_notes where memberId == uid`를 건수만 표시하고 감사가 없다 | dfet:admin_web/app/(console)/users/[uid]/page.tsx:17-21, :30, :71 | `healthRecordRead` 기록, v2 `memberUid` 병행 집계(DF-136) |
| 정책 설정 | `policyKind` enum gut·blood·integrated, insightPolicyVersions는 integrated만. 승인본만 내용 검증. 승인본 수정 거부, 활성화 시 같은 kind 다른 활성 문서 비활성 | dfet:admin_web/app/api/clinical/config/route.ts:10-25, :27-87, :110-121 | bodyChange 추가(DF-221). **승인본 재활성화(롤백) 경로가 없다** → P3 활성화 전용 라우트([§9.4](#94-ad-04-변화-판정-정책bodychange)) |
| 브라우저 SDK | `clientAuth = getAuth(app)`가 로그인 세션을 가진다 | dfet:admin_web/lib/firebase-client.ts:15-16 | 관리자 전용 callable(`exportMemberData`, `submitRightsRequest`)은 브라우저에서 호출한다(06 §7.3) |
| 테스트 | `node --test test/*.test.mjs` | dfet:admin_web/package.json:14 | 순수 검증 모듈을 `.ts`로 두고 Node 22 형 제거로 테스트한다(ASM-08-18) |

---

## 3 회원 앱 공통 설계

### 3.1 파일 배치

기존 구조(`lib/models`, `lib/services`, `lib/state`, `lib/screens`, `lib/widgets`)를 따른다(repoLayout, PRD §10.5).

| 경로 | 종류 | 내용 | 단계·스토리 |
|---|---|---|---|
| `lib/contracts/generated/{metric_catalog,vocab,contracts_version}.g.dart` | [신규·생성물] | 지표 카탈로그·어휘 상수. 손으로 고치지 않는다 | P0, DF-004 |
| `lib/contracts/generated/feature_flag_keys.dart` | [신규·생성물] | 플래그 키 상수 8개 | P0, DF-027 |
| `lib/contracts/generated/analytics_events.g.dart` | [신규·생성물] | 허용 이벤트·속성 상수 | P0, DF-033 |
| `lib/copy/member_copy.dart` | [신규] | 회원 화면 문구 상수(`abstract final class MemberCopy`). 금지어 린트 회원 세트 대상([§3.8](#38-문구-체계와-문구-키)) | P0(골격, DF-029), P2 |
| `lib/models/member_summary.dart` | [신규] | `MemberSummary`, `SummaryHighlight`, `SummaryMdc`, `SummaryComparedTo` | P2, DF-315 |
| `lib/models/consent.dart` | [신규] | `ConsentType`, `ConsentAction`, `ConsentChannel`, `ConsentState`, `ConsentStateEntry`, `ConsentRecord`, `ConsentDocumentVersion`, `ConsentSelection` | P2, DF-307 |
| `lib/models/rights_request.dart` | [신규] | `RightsRequest`, `RightsRequestType`, `RightsRequestStatus` | P2, DF-307 |
| `lib/models/soap_note_v2.dart` | [신규] | `SoapNoteV2Codec`(교차 픽스처 테스트용, 회원 화면에서 쓰지 않음) | P0, DF-007 |
| `lib/services/dfet_functions_exception.dart` | [신규] | callable 오류 정규화(06 §9.2) | P2, DF-306 |
| `lib/services/member_summary_repository.dart` | [신규] | 06 §9.3 + 피드 메타(ASM-08-03) | P2, DF-315 |
| `lib/services/consent_repository.dart` | [신규] | 06 §9.3 | P2, DF-307 |
| `lib/services/invite_repository.dart` | [신규] | 06 §9.3 | P2, DF-306 |
| `lib/services/rights_request_repository.dart` | [신규] | 06 §9.3 | P2, DF-307 |
| `lib/services/member_analytics.dart` | [신규] | `MemberAnalytics` 인터페이스 + `DebugMemberAnalyticsSink`(ASM-08-06) | P2, DF-306 |
| `lib/state/member_summary_state.dart` | [신규] | 요약 목록·단건·사진 URL·'새 기록' 표시 provider | P2, DF-315·DF-316 |
| `lib/state/consent_state.dart` | [신규] | 동의 상태·이력·문서·권리 요청·초대 코드 provider와 컨트롤러 | P2, DF-306·DF-307 |
| `lib/screens/body_report/body_report_screen.dart` | [신규] | MB-01(리포트 탭 세그먼트 본문) | P2, DF-316 |
| `lib/screens/body_report/body_report_detail_screen.dart` | [신규] | MB-02 | P2, DF-316 |
| `lib/screens/body_report/widgets/{highlight_row,before_after_photos,report_footnote}.dart` | [신규] | MB-01·MB-02 조각 | P2, DF-316 |
| `lib/screens/trainer_records/trainer_records_screen.dart` | [신규] | MB-03 | P2, DF-315 |
| `lib/screens/trainer_records/trainer_record_detail_screen.dart` | [신규] | MB-04 | P2, DF-315 |
| `lib/screens/invite_code_screen.dart` | [신규] | MB-05 | P2, DF-306 |
| `lib/screens/consent/consent_center_screen.dart` | [신규] | MB-06 본 화면(동의 5종) | P2, DF-307 |
| `lib/screens/consent/consent_document_sheet.dart` | [신규] | 동의 문서 다섯 고지 항목 시트 | P2, DF-307 |
| `lib/screens/consent/consent_history_screen.dart` | [신규] | 이력 | P2, DF-307 |
| `lib/screens/consent/in_person_reconfirm_section.dart` | [신규] | 현장 동의 재확인 | P2, DF-308 |
| `lib/screens/consent/rights_request_screen.dart` | [신규] | 권리 요청 | P2, DF-307 |
| `lib/widgets/clinical/source_grade_chip.dart` | [신규] | 출처 칩(F-VIZ-07.1) | P1a, DF-131 |
| `lib/widgets/clinical/series_trend_chart.dart` | [신규] | 공통 추이 차트(F-VIZ-07) | P1a, DF-131 |
| `lib/widgets/clinical/change_statement.dart` | [신규] | 회원 변화 문장 판단(순수 함수)과 표시 위젯(부록 B.8) | P2, DF-316. 배지 모양 P3 DF-383 |
| `lib/services/clinical_repository.dart` | [수정] | `AppFeatureFlags` 8키 | P0, DF-027 |
| `lib/router/app_router.dart` | [수정] | MB 라우트·플래그 게이트 | P2, DF-331 |
| `lib/screens/report_hub_screen.dart` | [수정] | `body` 세그먼트 | P2, DF-316 |
| `lib/screens/ios_profile_screen.dart` | [수정] | P0: 'SOAP 노트' 행 제거. P2: '트레이너 기록'·'트레이너 연결'·'동의·내 정보 요청' 행 | P0 DF-029, P2 DF-315·DF-306·DF-307 |
| `lib/models/user_profile.dart` | [수정] | 읽기 전용 `trainerId` | P2, DF-306 |
| `lib/design_system/d_fet_evidence.dart` | [수정] | `DfetReportHeader.mark`, `DfetEvidenceRibbon.title`·`pendingPolicyLabel` | P2, DF-316 |
| `lib/state/soap_note_state.dart` | [수정] | 회원 분기 제거 | P2, DF-315 |
| `lib/services/firestore_service.dart` | [수정] | `loadMemberSoapNotes` 삭제 | P2, DF-315 |
| `lib/screens/member_soap_notes_screen.dart` | [삭제] | MB-03으로 대체 | P2, DF-315 |
| `lib/screens/{guide_screen,onboarding_screen,profile_setup_screen,create_request_screen}.dart` | [수정] | 규제 문구 교체 | P0, DF-029 |

### 3.2 모델

필드 정본은 [05 §4.10~§4.15](05_DATA_MODEL_AND_RULES.md#410-membersummariessummaryid-신규-p2-서버-작성-ep-17)다. 회원 앱은 **읽기 모델만** 가진다(쓰기는 callable).

```dart
// lib/models/member_summary.dart
enum SummarySourceType { soapNote, bodyReport, unknown }
enum SummaryStatus { shared, revoked, unknown }

/// 회원 화면이 렌더하지 않는 출처 등급(F-VIZ-06.4, §7.1 '회원 UI 라벨' 칸이 비어 있는 등급)
const kMemberHiddenSourceGrades = {'photoAuto', 'observedSection', 'modelEstimate', 'aiAppearance'};
/// 회원 요약에서 항상 제외하는 지표(F-SOAP-05.5, §7.6)
const kMemberHiddenMetricCodes = {'painNrs'};

class SummaryMdc {                       // highlights[].mdc
  final double value; final String source; final String reference;
}
class SummaryComparedTo {                // highlights[].comparedTo
  final String refId; final DateTime measuredAt; final double value;
}

class SummaryHighlight {
  final String refId, metricCode, unit, side, sourceGrade, seriesKey;
  final double value;
  final DateTime measuredAt;
  final String? changeStatus, reasonCode, mdcSource;
  final SummaryMdc? mdc;
  final SummaryComparedTo? comparedTo;

  /// 필수 키(refId, metricCode, value(num), unit, side, sourceGrade, measuredAt, seriesKey) 중 하나라도
  /// 없거나 타입이 다르면 null. 호출자는 null을 버리고 AppLogger.warning('highlight skipped', {metricCode, reason})
  /// 만 남긴다(수치·ID 로그 금지, F-VIZ-06.4).
  static SummaryHighlight? tryParse(Map<String, dynamic> map);

  /// 회원 렌더 대상인가(F-VIZ-06.4). false면 화면에서 건너뛴다.
  bool get isMemberRenderable =>
      !kMemberHiddenSourceGrades.contains(sourceGrade) && !kMemberHiddenMetricCodes.contains(metricCode);
}

class MemberSummary {
  final String id, memberUid;
  final String? trainerId;
  final String? sharedByDisplayName;     // ASM-08-07(서버 스냅샷 필드 제안). 없으면 '담당 트레이너'
  final SummarySourceType sourceType;
  final List<String> sourceIds;
  final String title, body, nextPlan;
  final List<SummaryHighlight> highlights;   // tryParse 성공분만. isMemberRenderable 필터는 화면에서
  final List<String> sharedPhotoPaths;
  final String? policyVersion;
  final SummaryStatus status;
  final DateTime sharedAt;
  final DateTime? revokedAt;
  factory MemberSummary.fromMap(Map<String, dynamic> map, String id);
  bool get isShared => status == SummaryStatus.shared;
  /// MB-01 카드용: 렌더 가능한 highlight 중 앞 5개(F-VIZ-06.2)
  List<SummaryHighlight> get visibleHighlights =>
      highlights.where((h) => h.isMemberRenderable).take(5).toList(growable: false);
}
```

- `Timestamp`는 `DateTime`(로컬)로 바꾼다. 누락된 `sharedAt`은 문서 전체를 건너뛰고 경고만 남긴다(렌더 불가).
- 알 수 없는 `sourceType`·`status` 문자열은 `unknown`이고 목록에서 빠진다(앞으로 생길 값에 대한 방어).

```dart
// lib/models/consent.dart
enum ConsentType { required, healthData, bodyImaging, sharing, research }   // 와이어 값 = 이름(생성 상수와 대조 테스트)
enum ConsentAction { grant, withdraw }
enum ConsentChannel { memberApp, trainerDeviceInPerson }

class ConsentStateEntry { final bool granted; final String documentVersion; final String recordId; final DateTime updatedAt; }
class ConsentState {
  final Map<ConsentType, ConsentStateEntry> entries;          // 키가 없으면 미동의(PRD §9.2)
  bool isGranted(ConsentType t) => entries[t]?.granted == true;
  factory ConsentState.fromMap(Map<String, dynamic>? map);     // 문서 없음 → 빈 상태
}
class ConsentRecord {
  final String id; final ConsentType consentType; final ConsentAction action;
  final String documentVersion; final ConsentChannel channel;
  final DateTime recordedAt; final String recordedBy;
  final DateTime? reconfirmedAt; final String? reconfirmOf;
}
class ConsentDocumentVersion {
  final String id; final ConsentType consentType; final String version, title, purpose, retention, refusalNotice, privacyPolicyVersion;
  final List<String> items; final String? recipient; final DateTime? publishedAt;
}
class ConsentSelection { final ConsentType consentType; final ConsentAction action; final String documentVersion; }

// lib/models/rights_request.dart
enum RightsRequestType { access, rectification, erasure, suspension }
enum RightsRequestStatus { received, inProgress, completed, rejected }
class RightsRequest {
  final String id; final RightsRequestType type; final RightsRequestStatus status;
  final DateTime receivedAt, dueAt; final DateTime? completedAt;
}
```

- `documentVersion`은 불투명 문자열로 다룬다. 문서 ID는 `{consentType}--{version}`(V1-05 §4.13)이지만 앱은 불투명 문자열로 다룬다(C-08-06, ASM-08-40).

### 3.3 저장소와 오류

시그니처는 [06 §9.3](06_API_SPEC.md#93-저장소)을 그대로 쓴다. 이 문서가 더하는 것은 두 가지다.

1. **피드 메타(ASM-08-03).** 오프라인 표시(§8.4 '오프라인 · 최신이 아닐 수 있어요')에 Firestore 스냅샷의 `metadata.isFromCache`가 필요하다. 06의 `Stream<List<MemberSummary>> watchSummaries(uid)`는 그대로 두고, 같은 쿼리를 쓰는 `watchSummaryFeed`를 더한다.

   ```dart
   class SummaryFeed { final List<MemberSummary> items; final bool isFromCache; }

   // MemberSummaryRepository
   Stream<SummaryFeed> watchSummaryFeed(String uid) => _firestore
       .collection('memberSummaries')
       .where('memberUid', isEqualTo: uid)
       .orderBy('sharedAt', descending: true)
       .limit(100)                                            // ASM-08-08
       .snapshots(includeMetadataChanges: true)
       .map((s) => SummaryFeed(
             items: s.docs.map(_parseOrNull).whereType<MemberSummary>().toList(growable: false),
             isFromCache: s.metadata.isFromCache));
   Stream<List<MemberSummary>> watchSummaries(String uid) => watchSummaryFeed(uid).map((f) => f.items);
   ```

   `ConsentRepository`도 같은 방식으로 `watchStateFeed(uid)`를 둔다(MB-06 오프라인 표시).

2. **오류 전달.** 스트림 오류를 잡아 빈 값으로 바꾸지 않는다. `FirebaseException`은 그대로 흘리고, 화면이 `MemberLoadError.from(error)`로 분류한다.

   ```dart
   // lib/services/dfet_functions_exception.dart 에 함께 둔다
   enum MemberLoadErrorKind { permissionDenied, offline, notFound, unknown }
   class MemberLoadError {
     final MemberLoadErrorKind kind;
     static MemberLoadError from(Object e) => switch (e) {
       FirebaseException(code: 'permission-denied') => const MemberLoadError(MemberLoadErrorKind.permissionDenied),
       FirebaseException(code: 'unavailable') => const MemberLoadError(MemberLoadErrorKind.offline),
       FirebaseException(code: 'not-found') => const MemberLoadError(MemberLoadErrorKind.notFound),
       _ => const MemberLoadError(MemberLoadErrorKind.unknown),
     };
   }
   ```

callable 오류는 06의 `DfetFunctionsException`(`code`, `messageKey`, `retryable`)으로 받는다. 화면은 `messageKey`로 [§3.8](#38-문구-체계와-문구-키) 문구를 찾고, 모르는 키면 `common.<code>` 문구를 쓴다.

멱등 키: `recordConsent`·재확인은 `clientCaptureId`, `submitRightsRequest`는 `requestId`이며 둘 다 **사용자가 버튼을 누를 때 한 번** `const Uuid().v4()`로 만들고 같은 화면의 '다시 시도'에서 재사용한다(V1-06 §3.7). 화면을 닫으면 버린다(ASM-08-40).

### 3.4 상태(provider)

기존 패턴(`Provider` + `StreamProvider`, dfet:lib/state/clinical_state.dart:6-18)을 따른다. `currentUserProvider`가 null이면 빈 스트림을 돌려 로그아웃 상태를 처리한다.

```dart
// lib/state/member_summary_state.dart
final memberSummaryRepositoryProvider = Provider<MemberSummaryRepository>((ref) => MemberSummaryRepository());

/// MB-01·MB-03 공용 피드. revoked·unknown은 여기서 걸러 목록에 넣지 않는다(AC-VIZ-06.2, AC-SOAP-05.7)
final memberSummaryFeedProvider = StreamProvider.autoDispose<SummaryFeed>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const SummaryFeed(items: [], isFromCache: false));
  return ref.watch(memberSummaryRepositoryProvider).watchSummaryFeed(user.uid).map(
      (f) => SummaryFeed(items: f.items.where((s) => s.isShared).toList(growable: false), isFromCache: f.isFromCache));
});

final bodyReportSummariesProvider = Provider.autoDispose<AsyncValue<SummaryFeed>>((ref) =>
    ref.watch(memberSummaryFeedProvider).whenData((f) => SummaryFeed(
        items: f.items.where((s) => s.sourceType == SummarySourceType.bodyReport).toList(growable: false),
        isFromCache: f.isFromCache)));

/// MB-02·MB-04 단건. 목록에 없는 ID(해제·딥링크)도 열 수 있어야 하므로 문서를 직접 구독한다
final memberSummaryProvider = StreamProvider.autoDispose.family<MemberSummary?, String>((ref, id) =>
    ref.watch(memberSummaryRepositoryProvider).watchSummary(id));   // ASM-08-04: 06 getSummary의 스트림판

/// 공유 사진 URL. 화면 수명 동안만 보관(06: 캐시하지 않음). 키 = (summaryId, path)
final sharedPhotoUrlProvider = FutureProvider.autoDispose.family<Uri, ({String summaryId, String path})>((ref, k) =>
    ref.watch(memberSummaryRepositoryProvider).getSharedPhotoUrl(k.summaryId, k.path));

/// '새 기록' 표시: SharedPreferences 'dfet.member.summaries.lastSeenSharedAt.<uid>'(epoch ms)
final summaryLastSeenProvider = StateNotifierProvider<SummaryLastSeenNotifier, DateTime?>((ref) => …);
```

```dart
// lib/state/consent_state.dart
final consentRepositoryProvider = Provider((ref) => ConsentRepository());
final consentStateFeedProvider = StreamProvider.autoDispose<ConsentStateFeed>(…);        // memberConsentStates/{uid}
final consentRecordsProvider = StreamProvider.autoDispose<List<ConsentRecord>>(…);        // limit 50(ASM-08-08)
final publishedConsentDocumentsProvider = StreamProvider.autoDispose<Map<ConsentType, ConsentDocumentVersion>>(…);
    // 유형별 publishedAt 최신 1건. 같은 유형 published가 2건 이상이면 최신만 쓰고 경고 로그
final rightsRequestsProvider = StreamProvider.autoDispose<List<RightsRequest>>(…);        // 클라이언트에서 receivedAt↓ 정렬

/// 동의 변경 컨트롤러. 진행 중 버튼 비활성, 실패 시 messageKey 보관, clientCaptureId 재사용
final consentChangeControllerProvider =
    StateNotifierProvider.autoDispose<ConsentChangeController, ConsentChangeState>(…);
/// 초대 코드 입력 컨트롤러(MB-05)
final inviteRedeemControllerProvider =
    StateNotifierProvider.autoDispose<InviteRedeemController, InviteRedeemState>(…);
/// 권리 요청 제출 컨트롤러
final rightsRequestControllerProvider =
    StateNotifierProvider.autoDispose<RightsRequestController, RightsRequestSubmitState>(…);
```

- `rightsRequests`는 06 쿼리(`where memberUid == uid`)에 `orderBy`를 붙이지 않는다. 05 인덱스 목록에 `memberUid, receivedAt`이 없기 때문이다. 회원 한 명의 요청 수는 작으므로 클라이언트에서 정렬한다(ASM-08-09).

### 3.5 기능 플래그

`AppFeatureFlags` 확장은 06 §9.1 코드를 그대로 쓴다(DF-027). 이 문서가 정하는 노출 규칙:

| 진입점 | 조건 | 꺼졌을 때 | 근거 |
|---|---|---|---|
| 리포트 탭 `body` 세그먼트(MB-01), `/home/report/body/:id`(MB-02) | `flags.showsBodyReport`(= `memberShare && (bodyAssessment \|\| bodyComposition)`) | 세그먼트 없음, 라우트는 `/home/report`로 redirect | F-VIZ-06.8, AC-IA-02 |
| 내 정보 '트레이너 기록' 행, `/home/myPage/trainer-records/**`(MB-03·04) | `flags.memberShare` | 행 없음, 라우트는 `/home/myPage`로 redirect | §8.2, AC-IA-02, AC-IA-04 |
| 내 정보 '트레이너 연결' 행, 대시보드 안내 카드, `/home/myPage/invite`(MB-05) | `flags.memberShare` | 행·카드 없음, redirect | 스파인 featureFlags(memberShare에 MB-05 포함), 06 §6.12 플래그 |
| 내 정보 '동의·내 정보 요청' 행, `/home/myPage/consent/**`(MB-06) | **플래그 없음**(회원 앱 P2 릴리스부터 항상) | — | PRD §6.0.2(F-PRIV-*는 플래그와 무관) |

- 플래그 문서 로드 전·로드 실패 시에는 `AppFeatureFlags.disabled()`로 본다(기존 dfet:lib/screens/report_hub_screen.dart:32-33 패턴). 오류를 '켜짐'으로 해석하지 않는다.
- `AppFeatureFlags.enabled()`(임상 데모, dfet:lib/demo/clinical_demo_app.dart:38)는 기존 3키만 true, 새 5키는 false로 둔다. 데모에 체형·요약 합성 데이터가 없기 때문이다(ASM-08-10).

### 3.6 라우트

`lib/router/app_router.dart`에 추가한다. 모두 `parentNavigatorKey: _rootNavigatorKey`와 `_DetailScaffold` 패턴(:162-169)을 쓴다. 기존 명령형 push(`adaptivePageRoute`) 대신 go_router 경로를 쓰는 이유는 해제 요약 직접 열기(AC-VIZ-06.2)와 플래그 redirect를 한 곳에서 처리하기 위해서다.

| 경로 | 화면 | `_DetailScaffold.title` 문구 키 | 게이트 |
|---|---|---|---|
| `/home/report/body/:summaryId` | MB-02 `BodyReportDetailScreen(summaryId)` | `mb02.title` | `showsBodyReport` |
| `/home/myPage/trainer-records` | MB-03 `TrainerRecordsScreen()` | `mb03.title` | `memberShare` |
| `/home/myPage/trainer-records/:summaryId` | MB-04 `TrainerRecordDetailScreen(summaryId)` | `mb04.title` | `memberShare` |
| `/home/myPage/invite` | MB-05 `InviteCodeScreen()` | `mb05.title` | `memberShare` |
| `/home/myPage/consent` | MB-06 `ConsentCenterScreen()` | `mb06.title` | 없음 |
| `/home/myPage/consent/history` | `ConsentHistoryScreen()` | `mb06.history.title` | 없음 |
| `/home/myPage/consent/requests` | `RightsRequestScreen()` | `mb06.rights.title` | 없음 |

redirect 추가분(기존 :78-90 블록 바로 아래):

```dart
if (featureFlags != null) {
  final isBodyReportRoute = location.startsWith('/home/report/body/');
  final isShareRoute = location.startsWith('/home/myPage/trainer-records') || location == '/home/myPage/invite';
  if (isBodyReportRoute && !featureFlags.showsBodyReport) return '/home/report';
  if (isShareRoute && !featureFlags.memberShare) return '/home/myPage';
}
```

- 플래그가 아직 로드되지 않았으면(`featureFlags == null`) 새 경로도 redirect하지 않고 화면이 로딩을 보인다. 화면 본문은 플래그 provider를 다시 확인해 꺼져 있으면 빈 화면 대신 `mb.common.unavailable` 한 줄을 보인다.
- 해제 요약을 여는 테스트는 `router.go('/home/myPage/trainer-records/SYNTHrevoked001')`로 한다(딥링크 패키지가 없음, ASM-08-11).

### 3.7 오프라인·오류·빈 상태 공통 규칙

PRD §8.4 회원 앱 열을 화면 공통 위젯 `MemberStateView`(각 화면 파일 내부 private 위젯으로 둔다)로 구현한다.

| 상태 | 판정 | 표시 | 문구 키 |
|---|---|---|---|
| 로딩 | `AsyncLoading` | `CupertinoActivityIndicator` 가운데 | — |
| 빈 상태 | 쿼리 성공, 렌더 대상 0건 | 카드 한 장에 문장 한 줄. 버튼 없음 | 화면별(`mb01.empty` 등) |
| 불러오기 실패 | `AsyncError`(`MemberLoadError`) | 문장 + '다시 시도' 버튼(`ref.invalidate`) | `mb.common.loadFailed`, `mb.common.retry` |
| 오프라인 | `isFromCache == true`이고 데이터 있음 | 목록 위 얇은 배너 한 줄(목록은 그대로 표시) | `mb.common.offlineStale` |
| 오프라인 + 캐시 없음 | `isFromCache == true`이고 0건 | 빈 상태 대신 오프라인 문장 | `mb.common.offlineEmpty` |
| 동의 없음 | `ConsentState.isGranted(healthData) == false`(MB-01), `bodyImaging == false`(MB-02 사진) | 해당 영역 숨김 + MB-06으로 가는 한 줄 링크 | `mb01.noConsent`, `mb02.photo.noConsent` |
| 동작 실패(동의 변경·코드 입력) | callable 오류 | 입력 영역 아래 오류 문장 + '다시 시도' | messageKey별 |

- 권한 오류(`permission-denied`)도 빈 목록이 아니라 '불러오기 실패'다(PRD §8.4, §9.6).
- '추후 추가 예정'은 회원 앱에서 쓰지 않는다. 진입점을 숨긴다(§8.4).

### 3.8 문구 체계와 문구 키

- 새 회원 화면의 모든 사용자 문장은 `lib/copy/member_copy.dart`의 상수로만 둔다. 키 이름 규칙: `<화면>.<영역>.<의미>` → Dart 상수명 camelCase(`mb05.error.invalidOrExpired` → `MemberCopy.mb05ErrorInvalidOrExpired`).
- 이 파일은 금지어 린트의 **회원 세트** 대상이다(부록 C.3). '개선', '악화', '판정', '의미 있는', '진단', '치료', '교정', '재활', '정상', '예방'을 쓰지 않는다. 변화 문장은 부록 B.8 문장만 쓴다.
- 약어(SOAP, ROM, MMT, NRS, MDC, CVA, BIA)를 회원 문장에 쓰지 않는다. 지표명은 회원용 이름([§3.9](#39-지표출처-회원-표기))으로 쓴다.
- callable `messageKey` → 문구 매핑은 이 표가 회원 앱 정본이다(06 ASM-06-02가 DF-306에서 옮기라고 한 표).

**공통**

| 키 | 문구 |
|---|---|
| `mb.common.loadFailed` | 불러오기 실패. 잠시 후 다시 시도해 주세요. |
| `mb.common.retry` | 다시 시도 |
| `mb.common.offlineStale` | 오프라인 · 최신이 아닐 수 있어요 |
| `mb.common.offlineEmpty` | 오프라인이라 내용을 불러오지 못했어요. 인터넷에 연결된 뒤 다시 열어 주세요. |
| `mb.common.unavailable` | 지금은 사용할 수 없는 기능이에요. |
| `mb.common.offlineAction` | 인터넷에 연결된 뒤 다시 시도해 주세요. |
| `mb.common.actionFailed` | 처리하지 못했어요. 다시 시도해 주세요. |
| `common.invalid-argument` 외 코드 기본값 | `mb.common.actionFailed` 문구를 쓴다 |
| `common.unavailable`, `common.deadline-exceeded` | `mb.common.offlineAction` 문구를 쓴다 |
| `common.resource-exhausted` | 요청이 많아 잠시 후 다시 시도해 주세요. |

**MB-01·MB-02 체형·신체조성 리포트**

| 키 | 문구 |
|---|---|
| `mb01.segment` | 체형·신체조성 |
| `mb01.header.eyebrow` | BODY REPORT |
| `mb01.header.titleFallback` | 체형·신체조성 리포트 |
| `mb01.header.subtitle` | {M월 d일} 트레이너가 공유했어요 |
| `mb01.empty` | 아직 트레이너가 공유한 리포트가 없어요 |
| `mb01.noConsent` | 건강정보 동의가 꺼져 있어 리포트를 보여 드리지 않아요. 동의 상태 확인하기 |
| `mb01.section.metrics` | 오늘 확인한 수치 |
| `mb01.section.trainerNote` | 트레이너가 남긴 말 |
| `mb01.section.nextPlan` | 다음 계획 |
| `mb01.section.previous` | 이전 리포트 |
| `mb01.footnote.pendingPolicy` | 변화 비교 기준을 준비하고 있어요 |
| `mb01.ribbon.title` | 데이터 출처와 기준 |
| `mb01.ribbon.coverage` | 수치 {n}개 |
| `mb01.ribbon.pendingPolicy` | 비교 기준 준비 중 |
| `mb01.ribbon.detail` | 트레이너가 확인하고 공유한 수치만 보여 드려요. 수치마다 측정 방법과 날짜를 함께 적었어요. 사진으로 자동 추정한 값과 시험 중인 측정값은 보여 드리지 않아요. |
| `mb01.highlight.measuredAt` | {yyyy.M.d} 측정 |
| `mb01.highlight.comparedTo` | 비교 기록 {yyyy.M.d} · {value}{unit} |
| `mb02.title` | 리포트 상세 |
| `mb02.section.trend` | 수치 흐름 |
| `mb02.trend.single` | 기록이 하나뿐이라 흐름을 그릴 수 없어요 |
| `mb02.trend.break` | 측정 조건이 바뀐 지점 |
| `mb02.section.photos` | 전후 사진 |
| `mb02.photo.masked` | 얼굴을 가린 사진이에요 |
| `mb02.photo.loadFailed` | 사진을 불러오지 못했어요 |
| `mb02.photo.noConsent` | 신체 사진 동의가 꺼져 있어 사진을 보여 드리지 않아요 |
| `mb02.photo.before` / `mb02.photo.after` | 이전 / 이번 |
| `mb.revoked` | 트레이너가 공유를 해제했어요 |
| `mb.notFound` | 찾을 수 없는 기록이에요 |
| `summary.notShared`(messageKey) | 사진 영역을 렌더하지 않는다(문구 없음) |
| `summary.pathNotShared`, `summary.notOwner`, `summary.notFound` | 사진 영역을 렌더하지 않고 경고 로그만 남긴다 |
| `consent.bodyImagingRequired`(messageKey) | `mb02.photo.noConsent` |

**MB-03·MB-04 트레이너 기록**

| 키 | 문구 |
|---|---|
| `mb03.row.title` | 트레이너 기록 |
| `mb03.row.subtitle` | 트레이너가 공유한 세션 기록 요약과 리포트 |
| `mb03.title` | 트레이너 기록 |
| `mb03.filter.all` / `mb03.filter.soapNote` / `mb03.filter.bodyReport` | 전체 / 세션 기록 요약 / 체형·신체조성 리포트 |
| `mb03.empty` | 아직 트레이너가 공유한 기록이 없어요 |
| `mb03.item.meta` | {yyyy.M.d} · {트레이너 표시명} |
| `mb03.item.trainerFallback` | 담당 트레이너 |
| `mb03.item.new` | 새 기록 |
| `mb04.title` | 세션 기록 요약 |
| `mb04.section.metrics` | 오늘 확인한 수치 |
| `mb04.section.nextPlan` | 다음 계획 |
| `mb04.sharedAt` | {yyyy.M.d HH:mm} 공유 |
| `mb04.revokeNotice` | 트레이너가 공유를 해제하면 이 기록은 목록에서 사라져요. |

**MB-05 초대 코드**

| 키 | 문구 |
|---|---|
| `mb05.row.title` | 트레이너 연결 |
| `mb05.row.subtitle` | 센터에서 받은 초대 코드로 연결해요 |
| `mb05.row.connected` | 연결됨 |
| `mb05.card.title` | 담당 트레이너와 연결해 보세요 |
| `mb05.card.body` | 센터에서 받은 초대 코드를 입력하면 트레이너가 공유한 기록을 볼 수 있어요. |
| `mb05.title` | 트레이너 연결 |
| `mb05.age.label` | 만 14세 이상이에요 |
| `mb05.age.under14` | 만 14세 미만은 법정대리인 동의 절차를 아직 지원하지 않아요. |
| `mb05.code.label` | 초대 코드 8자리 |
| `mb05.code.hint` | 예: ABCD-2345 |
| `mb05.submit` | 연결하기 |
| `invite.invalidOrExpired` | 유효하지 않거나 만료된 코드예요. 트레이너에게 새 코드를 요청해 주세요. |
| `invite.tooManyAttempts` | 입력 시도가 많아요. 1시간 뒤 다시 시도해 주세요. |
| `invite.conflict` | 이미 다른 트레이너와 연결되어 있어요. 센터에 문의해 주세요. |
| `invite.profileMissing` | 프로필 설정을 먼저 마쳐 주세요. |
| `auth.staffAccountNotAllowed` | 트레이너·관리자 계정은 초대 코드를 사용할 수 없어요. |
| `flag.disabled` | `mb.common.unavailable` |
| `mb05.success` | 트레이너와 연결했어요. 현장에서 한 동의를 확인해 주세요. |

**MB-06 동의·내 정보 요청**

| 키 | 문구 |
|---|---|
| `mb06.row.title` | 동의·내 정보 요청 |
| `mb06.row.subtitle` | 동의 확인과 철회, 열람·정정·삭제 요청 |
| `mb06.row.reconfirmBadge` | 확인할 현장 동의 {n}건 |
| `mb06.title` | 동의·내 정보 요청 |
| `mb06.type.required` | 필수 동의(서비스 이용) |
| `mb06.type.healthData` | 건강정보 수집·이용 |
| `mb06.type.bodyImaging` | 신체 사진·영상 수집·이용 |
| `mb06.type.sharing` | 담당 트레이너가 바뀔 때 기록 넘기기 |
| `mb06.type.research` | 연구 참여(가명처리) |
| `mb06.status.granted` / `mb06.status.notGranted` | 동의함 / 동의하지 않음 |
| `mb06.version` | 문서 버전 {version} |
| `mb06.notice.purpose` / `.items` / `.retention` / `.recipient` / `.refusal` | 목적 / 수집 항목 / 보유기간 / 받는 사람 / 거부할 권리와 거부 시 제한 |
| `mb06.action.grant` / `mb06.action.withdraw` / `mb06.action.review` | 동의하기 / 철회하기 / 새 버전 확인하기 |
| `mb06.revision.banner` | {동의명} 문서가 바뀌었어요. 새 버전을 확인해 주세요. 확인 전에는 이전 버전이 유효해요. |
| `mb06.withdraw.required` | 필수 동의를 철회하려면 회원 탈퇴를 진행해야 해요. |
| `mb06.withdraw.requiredLink` | 탈퇴 안내 보기 |
| `mb06.withdraw.healthData` | 철회하면 트레이너가 새 건강 기록을 남길 수 없고, 공유받은 기록과 리포트가 바로 사라져요. 남아 있던 기록은 5영업일 안에 파기돼요. |
| `mb06.withdraw.bodyImaging` | 철회하면 신체 사진 촬영과 업로드가 멈추고 공유된 사진이 사라져요. 사진과 사진 위 표시점은 5영업일 안에 파기되고, 각도 수치는 건강정보 동의 범위에서 남아요. |
| `mb06.withdraw.sharing` | 철회하면 앞으로 담당 트레이너가 바뀔 때 기존 기록을 넘기지 않아요. 이미 넘겨진 기록은 지금 담당 트레이너가 계속 볼 수 있어요. |
| `mb06.withdraw.research` | 철회하면 이후 연구 자료에서 빠져요. 서비스 이용에는 영향이 없어요. |
| `mb06.withdraw.confirm` / `mb06.withdraw.cancel` | 철회하기 / 취소 |
| `mb06.reconfirm.title` | 현장에서 한 동의 확인 |
| `mb06.reconfirm.item` | {yyyy.M.d} 트레이너 기기에서 '{동의명}'에 동의했어요 |
| `mb06.reconfirm.due` | {yyyy.M.d}까지 확인해 주세요 |
| `mb06.reconfirm.yes` / `mb06.reconfirm.withdraw` | 맞아요 / 다르면 철회하기 |
| `mb06.history.title` | 동의 이력 |
| `mb06.history.row` | {yyyy.M.d HH:mm} · {채널} · {행위} · 문서 {version} |
| `mb06.history.channel.memberApp` / `.trainerDeviceInPerson` | 앱에서 / 트레이너 기기에서 |
| `mb06.history.action.grant` / `.withdraw` / `.reconfirm` | 동의함 / 철회함 / 다시 확인함 |
| `mb06.history.by.self` / `mb06.history.by.trainer` | 본인 / 담당 트레이너 |
| `mb06.rights.title` | 내 정보 요청 |
| `mb06.rights.type.access` / `.rectification` / `.erasure` / `.suspension` | 열람 요청 / 정정 요청 / 삭제 요청 / 처리정지 요청 |
| `mb06.rights.desc.access` | 트레이너 기록과 동의 기록을 파일로 받아 볼 수 있어요. 접수 후 10일 안에 처리해 드려요. |
| `mb06.rights.desc.rectification` | 잘못 적힌 기록은 트레이너가 추가 기록으로 바로잡아요. |
| `mb06.rights.desc.erasure` | 건강정보·사진 동의 철회와 같은 절차로 처리돼요. 계정 전체 삭제는 회원 탈퇴로 할 수 있어요. |
| `mb06.rights.desc.suspension` | 건강정보·사진 처리를 멈추는 요청이에요. 동의 철회와 같은 절차로 처리돼요. |
| `mb06.rights.submit` | 요청하기 |
| `mb06.rights.submitted` | 요청을 접수했어요. {yyyy.M.d}까지 처리해 드려요. |
| `mb06.rights.status.received` / `.inProgress` / `.completed` / `.rejected` | 접수됨 / 처리 중 / 완료 / 처리하지 않음 |
| `mb06.rights.empty` | 요청한 내역이 없어요 |
| `consent.documentNotPublished` | 동의 문서가 바뀌었어요. 최신 문서를 다시 불러왔어요. |
| `consent.requiredWithdrawNotSupported` | `mb06.withdraw.required` |
| `consent.requiredFirst` | 필수 동의를 먼저 해 주세요. |
| `rights.*` 기타 | `mb.common.actionFailed` |

### 3.9 지표·출처 회원 표기

- **출처 칩**(`SourceGradeChip`, PRD §7.1 '회원 UI 라벨'): `tape` 줄자로 잰 값, `device` 체성분계 측정, `photoManual` 사진으로 확인한 값, `trainerObserved` 트레이너 확인, `derived` 계산한 값, `selfReport` 직접 알려 준 값. 나머지 등급은 칩을 만들지 않고 행 자체를 렌더하지 않는다.
- **지표 이름**: 카탈로그 `nameKo`(예: '두개척추각(CVA)')에는 약어가 들어 있어 회원 문장에 쓸 수 없다. 회원용 이름 필드 `memberLabelKo`를 `contracts/metric-catalog.v1.json`에 더하는 것을 제안한다(ASM-08-12, C-08-03). 결정 전 회원 앱 기본값:

| metricCode | 회원 표기 | metricCode | 회원 표기 |
|---|---|---|---|
| `craniovertebralAngle` | 머리·목 정렬 각도 | `waistCircumference` | 허리둘레 |
| `shoulderTiltAngle` | 어깨 높이 차이 각도 | `hipCircumference` | 엉덩이둘레 |
| `headTiltFrontal` | 머리 기울기 | `thighCircumference` | 허벅지 둘레 |
| `pelvicTiltFrontal` | 골반 기울기 | `upperArmCircumference` | 위팔 둘레 |
| `weightKg` | 체중 | `calfCircumference` | 종아리 둘레 |
| `bodyFatPercent` | 체지방률 | `chestCircumference` | 가슴둘레 |
| `skeletalMuscleMassKg` | 골격근량 | `bmi` | 체질량지수 |
| `bodyFatMassKg` | 체지방량 | `romDeg` | 관절이 움직이는 범위 |
| `visceralFatLevel` | 내장지방 레벨 | `mmtGrade` | 근력 등급(0–5) |
| `totalBodyWaterL` | 체수분 | (카탈로그 밖 코드) | 행을 렌더하지 않고 경고 로그 |

- **측면**: `left` 왼쪽, `right` 오른쪽, `bilateral` 양쪽, `none` 표기 없음.
- **단위**: `deg` → `°`, `kg`, `%`, `cm`, `kg/m²`, `L`, `level` → '레벨', `grade` → '등급'. 값 형식은 카탈로그 정밀도를 따르고 기본은 소수 한 자리(`NumberFormat('0.0', 'ko_KR')`).
- 참고 등급(`reliabilityTier == 'reference'`) 지표는 이름 뒤에 '참고용' 칩을 붙인다(§6.5.0).

### 3.10 분석 이벤트

회원 앱에는 분석 SDK가 없다(§2.1). G-09 처리방침 공개 전에는 어차피 전송하지 않으므로(ADR-015) `MemberAnalytics` 인터페이스와 디버그 싱크만 두고, 전송 SDK 도입은 G-09 뒤 별도 결정으로 미룬다(ASM-08-06, Q-DEV-08-01).

```dart
// lib/services/member_analytics.dart
abstract interface class MemberAnalytics { void track(String event, Map<String, Object> props); }
class DebugMemberAnalyticsSink implements MemberAnalytics {
  @override void track(String event, Map<String, Object> props) {
    assert(AnalyticsEvents.isAllowed(event, props));     // 생성 상수(analytics_events.g.dart) 대조. 목록 밖이면 테스트 실패
    AppLogger.debug('[analytics] $event $props');
  }
}
final memberAnalyticsProvider = Provider<MemberAnalytics>((ref) => DebugMemberAnalyticsSink());
```

| 이벤트(PRD §5.5) | 호출 지점 | 속성 | 단계 |
|---|---|---|---|
| `invite_code_redeemed` | MB-05 callable 응답 뒤 | `result`: `success` \| `invalid`(서버가 사유를 묶으므로 expired·reused는 보내지 않음, 06 §11.1) | P2 |
| `change_status_rendered` | MB-01·MB-02에서 B.8 변화 문장이 처음 그려질 때 1회 | `surface: 'member'`(판정 결과는 보내지 않음) | P3 |

- 동의 변경은 이벤트로 보내지 않는다(PRD §5.5). 요약 열람은 이벤트가 아니라 서버 기록(M-06)이고, 06 `markSummaryViewed`가 승인되면 MB-02·MB-04가 첫 렌더 때 `markViewed`를 1회 호출한다(Q-DEV-04).

### 3.11 접근성

| 규칙 | 구현 |
|---|---|
| A-01 글자 크기 | `textScaler`를 막지 않는다. 200%에서 지표 행은 값·단위를 줄바꿈해 세로로 쌓고, 값을 말줄임하지 않는다(`maxLines` 지정 금지, AC-A11Y-02) |
| A-02 색 외 구분 | 출처는 칩 텍스트, seriesBreak는 점선 + `mb02.trend.break` 문구, 좌우 선은 실선(왼쪽)·점선(오른쪽) + 'L'/'R' 끝 라벨, 변화 문장은 글리프 + 문장 |
| A-03 수치 라벨 | `Semantics(label: '{회원 지표명} {값}{단위}, {측면}, 출처 {칩 문구}, {측정일}, {변화 문장 또는 "변화 비교 기준을 준비하고 있어요"}')`. 차트는 `Semantics(label: '{지표명} 흐름, {시작일}부터 {끝일}까지, 점 {n}개, 가장 낮은 값 {min}, 가장 높은 값 {max}, 끊긴 곳 {k}곳, 측정 오차 범위 {있음/없음}, 출처 {칩 문구}')` |
| A-04 탭 대상 | 44×44 이상(`meetsGuideline(iOSTapTargetGuideline)`) |
| 식별자 | 위젯 `Key('mb01.segment.body')` 형식. 화면별 표에 적었다 |
| 대비 | 텍스트 4.5:1, 그래픽 3:1(`meetsGuideline(textContrastGuideline)`) |

---

## 4 회원 앱 화면 명세(MB-01~MB-06)

각 화면 절은 같은 순서로 적는다: 목적·근거 → 진입·노출 → 레이아웃 → 데이터 → 상태 → 상호작용 → 식별자·접근성 → 수용 기준 대응 → 테스트.

### 4.1 MB-01 리포트 > 체형·신체조성

| 항목 | 내용 |
|---|---|
| 목적 | 트레이너가 공유한 체형·신체조성 리포트(`sourceType=bodyReport`)를 최신순으로 보여 준다 |
| PRD | §8.2 MB-01, F-VIZ-06.1~06.9, F-LINK-05.3·05.5, §7.6, 부록 B.8 |
| 스토리 | DF-316(P2, S21-S22). 배지 모양·밴드는 DF-383(P3) |
| 파일 | `lib/screens/body_report/body_report_screen.dart`, `lib/screens/body_report/widgets/{highlight_row,report_footnote}.dart`, `lib/screens/report_hub_screen.dart`[수정] |
| 플래그 | `showsBodyReport` |

**진입·노출.** `report_hub_screen.dart`의 섹션 목록(:34-59) 끝, `insights` 다음에 추가한다. careType과 무관하게 보인다(ASM-08-13).

```dart
if (flags.showsBodyReport)
  const _ReportSection(keyName: 'body', label: MemberCopy.mb01Segment, child: BodyReportScreen()),
```

- `insights` 섹션·`AxisRadarChart`·Today Signal·`DfetSignalRail`에는 아무것도 더하지 않는다(F-VIZ-06.7, AC-VIZ-06.5).

**레이아웃**(세로 스크롤, `ResponsiveConstrainedBox(maxWidth: 820)`)

```
┌ [오프라인 배너: mb.common.offlineStale] (isFromCache일 때만)
├ DfetReportHeader(mark: none)  eyebrow BODY REPORT / title=summary.title / subtitle=mb01.header.subtitle
├ 카드: mb01.section.metrics
│   HighlightRow × (1~5)   [회원 지표명]  [값 단위]  [측면]  [출처 칩]  [측정일]  [비교 기록]  [변화 문장(P3)]
├ 카드: mb01.section.trainerNote   summary.body (없으면 카드 생략)
├ 카드: mb01.section.nextPlan      summary.nextPlan (없으면 카드 생략)
├ DfetEvidenceRibbon(title: mb01.ribbon.title, source: 출처 칩 문구 모음, coverage: mb01.ribbon.coverage, policyVersion, pendingPolicyLabel: mb01.ribbon.pendingPolicy, detail: mb01.ribbon.detail)
├ ReportFootnote   mb01.footnote.pendingPolicy (조건은 §5.5 needsPendingFootnote)
├ 버튼 '자세히 보기' → MB-02(최신 요약)
└ mb01.section.previous: 이전 bodyReport 목록(제목 · 공유일) → 각 행 탭 시 MB-02
```

- 사진은 MB-01에 두지 않는다. 전후 사진은 MB-02에서만 보인다(요약 카드가 길어지지 않게, F-VIZ-06.2의 카드 구성에 사진 없음).
- 레이더·종합 점수·등급·규준 비교를 두지 않는다(F-VIZ-07.5, F-VIZ-07.8, AC-VIZ-07.2).

**데이터.** `bodyReportSummariesProvider`(목록), `consentStateFeedProvider`(동의 없음 판정). 최신 = 목록 첫 항목(`sharedAt` 내림차순).

**상태**(§8.4 매트릭스 MB-01 행: 빈 상태·동의 없음·산정 준비 중·판정 불가·오프라인)

| 상태 | 조건 | 화면 |
|---|---|---|
| 빈 상태 | 목록 0건이고 `healthData` 동의가 있음 | `mb01.empty` 카드 |
| 동의 없음 | 목록 0건이고 `healthData` 동의 없음(상태 문서 없음 포함) | `mb01.noConsent` 한 줄 + 탭하면 `/home/myPage/consent` |
| 산정 준비 중 | `summary.policyVersion == null` | 배지 없음, 하단 `mb01.footnote.pendingPolicy` |
| 판정 불가(조건 사유) | P3, highlight `changeStatus == indeterminate` + 조건 사유 | 행 안 '이번에는 비교할 수 없어요({사유})'(§5.5) |
| 오프라인 | `isFromCache` | 상단 배너, 내용 유지 |
| 불러오기 실패 | 스트림 오류 | `mb.common.loadFailed` + 다시 시도 |

- 목록이 있으면 동의 상태와 관계없이 목록을 보인다. 서버가 ② 철회 때 요약을 해제하므로(06 §6.2.4) 공유 문서가 곧 권한의 정본이다.
- highlight 중 `isMemberRenderable == false`(photoAuto, observedSection, modelEstimate, aiAppearance, painNrs)는 건너뛰고 수치 없는 경고만 남긴다(F-VIZ-06.4, AC-VIZ-06.6). 렌더 가능한 highlight가 0개인 요약은 카드의 수치 영역만 생략한다.

**식별자.** `Key('mb01.segment.body')`, `Key('mb01.latest')`, `Key('mb01.highlight.<index>')`, `Key('mb01.footnote')`, `Key('mb01.previous.<summaryId>')`.

**수용 기준 대응**

| 기준 | 확인 방법 |
|---|---|
| AC-VIZ-06.1 회원 코드에 원 기록 경로 0건 | static-guards 회원 경로 grep([§6.4](#64-정적-가드-범위)) |
| AC-VIZ-06.3 policyVersion 없음·literature → 배지 없음, 하단 한 줄 | `change_statement_test.dart` 표 기반 + 위젯 테스트 |
| AC-VIZ-06.5 통합 세그먼트 축 4개 유지 | 기존 `axis_radar_chart_test.dart` 회귀 + 세그먼트 목록 테스트 |
| AC-VIZ-06.6 observedSection·painNrs 미표시 | 픽스처 `contracts/fixtures/summaries/body_report_with_hidden.json` 렌더 → 해당 `Key` 0개 |
| AC-VIZ-07.1~07.3 | §5.3·§5.4 위젯 테스트 |
| AC-IA-01 상태 매트릭스 | 골든 6종(빈·동의 없음·산정 준비 중·판정 불가(P3)·오프라인·실패) × 라이트·다크 |
| AC-IA-02 플래그 off 진입점 0 | `showsBodyReport=false`에서 세그먼트 `Key` 0개 |
| AC-A11Y-01·02·03 | `meetsGuideline`, textScale 2.0 골든, 회색조 골든 |

### 4.2 MB-02 리포트 상세

| 항목 | 내용 |
|---|---|
| 목적 | 한 리포트의 지표 흐름과 전후 사진, 트레이너 문장, 다음 계획 |
| PRD | §8.2 MB-02, F-VIZ-06.2·06.5·06.6, F-VIZ-03(회원 적용분), F-VIZ-07, AC-VIZ-06.2·06.4 |
| 스토리 | DF-316(P2). 밴드·배지 DF-383(P3) |
| 파일 | `lib/screens/body_report/body_report_detail_screen.dart`, `lib/screens/body_report/widgets/before_after_photos.dart` |
| 경로·플래그 | `/home/report/body/:summaryId`, `showsBodyReport` |

**레이아웃**

```
┌ DfetReportHeader(mark: none)
├ mb01.section.metrics: HighlightRow × n
├ mb02.section.trend: highlight마다 SeriesTrendChart 1개(같은 metricCode+sourceGrade 묶음)
├ mb02.section.photos: BeforeAfterPhotos (조건부)
├ mb01.section.trainerNote / mb01.section.nextPlan
├ DfetEvidenceRibbon, ReportFootnote
```

**추이 데이터 구성**(F-VIZ-06.6, Q-19 기본값 '시계열 필드 없음, 누적')

1. `bodyReportSummariesProvider`의 모든 **shared** bodyReport에서 `isMemberRenderable` highlight를 모은다.
2. 이 요약의 highlight마다 `(metricCode, sourceGrade)`가 같은 점을 고른다. 출처 등급이 다르면 다른 차트다(§7.1, F-VIZ-07.2).
3. `refId`가 같은 점은 하나만 둔다(나중에 공유된 요약의 값을 쓴다).
4. 점을 `seriesKey`별 세그먼트로 나눈다. `seriesKey`가 바뀌면 선을 잇지 않고 끊김 표시를 둔다(seriesBreak). 좌우 지표(`side` left/right)는 `seriesKey`가 달라 별도 선이며, 실선·점선과 L/R 라벨로 구분한다(A-02).
5. `comparedTo`는 차트 점으로 넣지 않는다. 행 안 '비교 기록' 문구로만 보인다(ASM-08-14).
6. 점이 2개 미만이면 차트 대신 `mb02.trend.single`.

**전후 사진**(F-VIZ-06.5, AC-VIZ-06.4, AC-LINK-05.3)

| 조건 | 표시 |
|---|---|
| `sharedPhotoPaths` 비어 있음 | 사진 영역 자체를 렌더하지 않는다(제목도 없음) |
| `bodyImaging` 동의 없음(상태 문서 기준) | 사진 영역 대신 `mb02.photo.noConsent` 한 줄 |
| 그 밖 | 경로마다 `sharedPhotoUrlProvider((summaryId, path))` → `Image.network(url, fit: BoxFit.contain)`. 2장이면 나란히 두고 `mb02.photo.before`·`mb02.photo.after` 캡션, 그 밖에는 2열 격자(캡션 없음). 공통 캡션 `mb02.photo.masked` |
| URL 발급 실패 `summary.notShared`·`summary.pathNotShared`·`summary.notOwner` | 해당 사진 칸을 렌더하지 않고 경고 로그 |
| 이미지 다운로드 실패(403·네트워크) | 칸 안 `mb02.photo.loadFailed` + 다시 시도(provider invalidate로 새 URL 발급) |

- 겹쳐 보기·랜드마크 표시는 없다. 요약에는 좌표가 없다(F-VIZ-06.5).
- URL은 디스크에 저장하지 않는다. `Image.network`의 메모리 캐시만 쓴다.

**단건 상태**

| 조건 | 화면 |
|---|---|
| 문서 없음 | `mb.notFound` |
| `status == revoked` | `mb.revoked` 한 줄만(AC-VIZ-06.2). 내용 필드는 서버가 비웠다 |
| `sourceType != bodyReport` | `mb.notFound`(MB-04 경로로 열어야 함) |
| 로딩·오류·오프라인 | §3.7 |

**식별자.** `Key('mb02.chart.<metricCode>.<sourceGrade>')`, `Key('mb02.photos')`, `Key('mb02.photo.<index>')`, `Key('mb02.revoked')`.

**수용 기준 대응.** AC-VIZ-06.2(해제 요약 경로 열기 → `mb.revoked`), AC-VIZ-06.4(사진 경로 0개 → `Key('mb02.photos')` 없음), AC-A11Y-02(textScale 2.0에서 수치 말줄임 없음), AC-VIZ-07.5(회색조 골든에서 끊김·L/R 구분).

### 4.3 MB-03 내 정보 > 트레이너 기록

| 항목 | 내용 |
|---|---|
| 목적 | 공유 요약 목록(두 sourceType) |
| PRD | §8.2 MB-03, F-LINK-05.3·05.5, F-SOAP-05, AC-SOAP-05.6·05.7, AC-IA-04 |
| 스토리 | DF-315(P2, S21-S22), 플래그 노출은 DF-331 |
| 파일 | `lib/screens/trainer_records/trainer_records_screen.dart`, `lib/screens/ios_profile_screen.dart`[수정] |
| 경로·플래그 | `/home/myPage/trainer-records`, `memberShare` |

**내 정보 탭 변경**(dfet:lib/screens/ios_profile_screen.dart:117-128 자리)

```dart
if (flags.memberShare) ...[
  IOSActionRow(
    key: const Key('mb03.row'),
    icon: CupertinoIcons.doc_text,
    title: MemberCopy.mb03RowTitle,
    subtitle: MemberCopy.mb03RowSubtitle,
    color: context.wellness.textSecondary,          // 초록(AppColors.success) 금지, 중립(PRD §8.2)
    onPressed: () => context.push('/home/myPage/trainer-records'),
  ),
  const SizedBox(height: 8),
  // MB-05 행(§4.5)
],
// MB-06 행은 플래그와 무관(§4.6)
```

- 새 기록이 있으면 행 오른쪽에 `mb03.item.new` 점 표시를 둔다(아래 '새 기록' 규칙).

**레이아웃.** 상단 `CupertinoSlidingSegmentedControl`(전체 / 세션 기록 요약 / 체형·신체조성 리포트) → 목록. 행: 제목(1줄, 넘치면 2줄까지), `mb03.item.meta`, 새 기록 점.

- 체형·신체조성 필터와 bodyReport 행은 `showsBodyReport`일 때만 보인다. 꺼져 있으면 필터 세그먼트가 2개(전체·세션 기록 요약)로 줄고 bodyReport 행은 목록에서 빠진다(AC-IA-02).
- 행 탭: soapNote → `/home/myPage/trainer-records/:id`(MB-04), bodyReport → `/home/report/body/:id`(MB-02).
- 트레이너 표시명은 `sharedByDisplayName`이 있으면 쓰고, 없으면 `mb03.item.trainerFallback`. 회원은 트레이너의 `users`·`trainers` 문서를 읽을 수 없다(dfet:firestore.rules:76, :105-110). 서버 스냅샷 필드가 필요하다(ASM-08-07).

**'새 기록' 규칙**(푸시가 없으므로 S3 '새 항목 표시'로 대신, PRD §4.4)

- 저장: SharedPreferences `dfet.member.summaries.lastSeenSharedAt.<uid>`(epoch ms).
- 표시: `sharedAt > lastSeen`인 행에 점. 저장값이 없으면(처음 설치) 점을 표시하지 않고 현재 최신값으로 초기화한다.
- 갱신: MB-03 화면이 데이터를 처음 렌더한 뒤 `lastSeen = max(sharedAt)`.
- 이 값은 기기 로컬 편의 기능이며 M-06 열람 기록이 아니다.

**상태.** 빈 상태 `mb03.empty`, 오프라인 배너, 불러오기 실패(§3.7). revoked 요약은 목록에 없다(AC-SOAP-05.7).

**수용 기준 대응.** AC-SOAP-05.6(회원 앱의 쿼리는 `memberSummaries where memberUid == uid`만, `soap_notes` 참조 0건 — static guard와 저장소 단위 테스트), AC-SOAP-05.7(묘비 문서 → 목록에서 사라짐), AC-IA-04('SOAP 노트' 문구 0건, `Key('mb03.row')` 존재), AC-LINK-05.5(담당 해제 뒤에도 목록 유지 — 쿼리가 `trainerId`를 쓰지 않음).

### 4.4 MB-04 공유 요약 상세

| 항목 | 내용 |
|---|---|
| 목적 | 세션 기록 요약(`sourceType=soapNote`) 읽기 |
| PRD | §8.2 MB-04, F-SOAP-05.3~05.5, F-VIZ-06.3, 부록 B.8 |
| 스토리 | DF-315 |
| 파일 | `lib/screens/trainer_records/trainer_record_detail_screen.dart` |
| 경로·플래그 | `/home/myPage/trainer-records/:summaryId`, `memberShare` |

**레이아웃**

```
┌ 제목(summary.title, Gowun Batang: DfetTypography.displayStyle)
├ mb04.sharedAt · mb03.item.meta의 트레이너 표시명
├ 본문(summary.body, 선택 가능한 텍스트)
├ mb04.section.metrics: HighlightRow × 0~3 (없으면 카드 생략)
├ mb04.section.nextPlan: summary.nextPlan
└ mb04.revokeNotice (작은 글씨)
```

- 사진 영역이 없다(F-SOAP-05.5, AS-24).
- 홈 운동은 별도 필드가 없다(PRD §9.2는 `body`, `nextPlan`만). 서버 템플릿이 `nextPlan` 또는 `body`에 넣은 문장을 그대로 보인다(ASM-08-22).
- 단건 상태는 MB-02와 같다(`mb.notFound`, `mb.revoked`). `sourceType == bodyReport`면 MB-02 경로로 `context.replace`한다.
- 06 `markSummaryViewed`가 승인되면(Q-DEV-04) MB-02·MB-04 첫 렌더 때 `markViewed(summaryId)`를 1회 호출한다. 실패는 무시한다.

**수용 기준 대응.** AC-SOAP-05.4(요약 문서에 제외 필드가 없음은 서버 테스트가 정본이고, 회원 앱은 `title`, `body`, `highlights`, `nextPlan`, `sharedAt` 외 필드를 렌더하지 않는다 — 모델이 다른 필드를 읽지 않음을 단위 테스트), AC-SOAP-05.9(policyVersion 없음 → 배지 없음).

### 4.5 MB-05 초대 코드 입력

| 항목 | 내용 |
|---|---|
| 목적 | 초대 코드로 트레이너와 연결(uid 승격) |
| PRD | §8.2 MB-05, F-LINK-02.4~02.8, F-LINK-01.8, AS-22 |
| 스토리 | DF-306(P2, S19-S20). 서버는 DF-305 |
| 파일 | `lib/screens/invite_code_screen.dart`(화면 + `InviteGuideCard`), `lib/state/consent_state.dart`(`InviteRedeemController`), `lib/services/invite_repository.dart`, `lib/models/user_profile.dart`[수정] |
| 경로·플래그 | `/home/myPage/invite`, `memberShare` |

**진입점**

1. 내 정보 행 `Key('mb05.row')`: 제목 `mb05.row.title`, 부제 `mb05.row.subtitle`. `profile.trainerId != null`이면 부제를 `mb05.row.connected`로 바꾼다.
2. 대시보드 안내 카드 `InviteGuideCard`(`Key('mb05.card')`): `memberShare && profile.trainerId == null`이고 닫지 않았을 때 대시보드 맨 위. 닫기 상태는 SharedPreferences `dfet.member.inviteCard.dismissed.<uid>`. 삽입 위치는 `lib/screens/dashboard.dart`의 두 표시 모드(Today Signal, 기존 대시보드) 공통 상단이다(ASM-08-15).

`UserProfile` 변경: `final String? trainerId;`를 추가하고 `fromMap`에서 `map['trainerId'] as String?`로 읽는다. `toMap()`·`copyWith`의 쓰기 경로에는 넣지 않는다(규칙 dfet:firestore.rules:84-91이 거부).

**레이아웃**

```
┌ 안내 문장 mb05.card.body
├ [체크] mb05.age.label          Key('mb05.age')
│   보조 문장 mb05.age.under14
├ 입력 mb05.code.label           Key('mb05.code')   placeholder mb05.code.hint
├ 오류 문장(있을 때)             Key('mb05.error')
└ 버튼 mb05.submit               Key('mb05.submit')
```

**입력 규칙**

- 표시: 영문 대문자로 바꿔 보이고 공백을 지운다. 하이픈은 허용한다(표시 형식 `XXXX-XXXX`, 06 ASM-06-21).
- 버튼 활성 조건: 나이 확인 체크 && 영숫자 8자(하이픈 제외) && 요청 진행 중 아님.
- 전송 값: 사용자가 입력한 문자열에서 앞뒤 공백만 뺀 값. 문자 집합 검증과 정규화는 서버가 한다(06 §9.3).
- 만 14세 확인을 체크하지 않으면 코드 칸은 입력할 수 있지만 버튼이 비활성이다. 앱은 생년을 따로 받지 않는다(PRD MB-05는 확인만 요구).

**호출과 결과**

| 결과 | 처리 | 분석 |
|---|---|---|
| `{ok, status: promoted \| resumed}` | `ref.invalidate(userProfileProvider)`, 동의 provider들 invalidate → `context.go('/home/myPage/consent')` + 스낵바 `mb05.success` | `invite_code_redeemed{result: success}` |
| `invite.invalidOrExpired` | 오류 문장, 입력 유지 | `invite_code_redeemed{result: invalid}` |
| `invite.tooManyAttempts` | 오류 문장, 버튼 60초 비활성 | 보내지 않음 |
| `invite.conflict` | 오류 문장(센터 문의) | 보내지 않음 |
| `invite.profileMissing` | 오류 문장 + `/profile-setup`으로 가는 링크 | 보내지 않음 |
| `auth.staffAccountNotAllowed` | 오류 문장 | 보내지 않음 |
| `flag.disabled` | `mb.common.unavailable` | 보내지 않음 |
| `unavailable`·`deadline-exceeded` | `mb.common.offlineAction` + 다시 시도 | 보내지 않음 |

- 서버가 `aborted`(T2 잔여, 06 §6.12.1)를 돌려주면 같은 코드로 자동 1회 재호출하고, 그래도 실패하면 `mb.common.actionFailed`와 다시 시도를 보인다. 재호출은 서버에서 `resumed`로 이어진다(F-LINK-02.5).

**상태**(§8.4: 오프라인·동기화, 동기화 실패). 진행 중에는 버튼 안 `CupertinoActivityIndicator`, 입력 비활성.

**수용 기준 대응.** 서버 AC-LINK-02.1~02.5는 06 TC-06-RED-*. 회원 앱 테스트: 사유별 오류 문장이 `invite.invalidOrExpired` 하나로 합쳐짐(F-LINK-02.7), 나이 미확인 시 버튼 비활성(F-LINK-01.8), 성공 시 MB-06 이동.

### 4.6 MB-06 동의·내 정보 요청

| 항목 | 내용 |
|---|---|
| 목적 | 동의 5종 상태·철회·재동의, 현장 동의 재확인, 동의 이력, 정보주체 권리 요청 |
| PRD | §8.2 MB-06, F-PRIV-01.1~01.5, F-PRIV-02.1~02.3(철회 처리표), F-PRIV-03.8, F-PRIV-07.1~07.4, §9.2 consent*·rightsRequests |
| 스토리 | DF-307(동의·이력·권리 요청), DF-308(재확인) |
| 파일 | `lib/screens/consent/{consent_center_screen,consent_document_sheet,consent_history_screen,in_person_reconfirm_section,rights_request_screen}.dart`, `lib/state/consent_state.dart`, `lib/services/{consent_repository,rights_request_repository}.dart` |
| 경로·플래그 | `/home/myPage/consent`, `/history`, `/requests`. 플래그 없음 |

**내 정보 행.** `Key('mb06.row')`, 제목 `mb06.row.title`, 부제 `mb06.row.subtitle`. 재확인 대상이 있으면 부제를 `mb06.row.reconfirmBadge`로 바꾼다. 색은 중립.

**본 화면 레이아웃**

```
┌ [현장 동의 확인 섹션] 재확인 대상이 있을 때만(DF-308)
├ [개정 배너] 동의한 유형 중 새 published 버전이 있으면 유형마다 1개
├ 동의 카드 × 5 (① ② ③ ④ ⑤ 순서, 묶음 없음, 기본 체크 없음)
│   유형명 · 상태(동의함/동의하지 않음) · 문서 버전 · [자세히] · [동의하기 | 철회하기]
├ 행: mb06.history.title → /home/myPage/consent/history
└ 행: mb06.rights.title  → /home/myPage/consent/requests
```

**동의 카드 동작**

| 유형 | 동의하지 않음일 때 | 동의함일 때 |
|---|---|---|
| ① required | '동의하기' → 문서 시트 → `recordConsent([{required, grant, 최신 published ID}])` | '철회하기' → `mb06.withdraw.required` 대화상자 + '탈퇴 안내 보기'(기존 설정 화면 push, dfet:lib/screens/ios_profile_screen.dart:143-147 패턴). callable은 호출하지 않는다(06 V7) |
| ② healthData, ③ bodyImaging, ④ sharing | '동의하기' → 문서 시트 → grant | '철회하기' → 유형별 사전 안내(`mb06.withdraw.<type>`) 확인 → `recordConsent([{type, withdraw, 현재 state의 documentVersion}])` |
| ⑤ research | 버튼 없이 `mb06.research.inPersonOnly` 안내(ASM-08-16) | '철회하기'(위와 같음) |

- ①이 없으면 ②~⑤의 '동의하기'를 비활성하고 `consent.requiredFirst` 문장을 카드에 보인다(06 V8).
- 문서 시트(`ConsentDocumentSheet`)는 `purpose`, `items`(목록), `retention`, `recipient`(④만), `refusalNotice`, 문서 버전, `privacyPolicyVersion`을 모두 보인다(F-PRIV-01.2 다섯 고지 항목). 시트 하단 버튼 하나(`동의하기`)만 있다.
- 한 번에 한 유형만 바꾼다(묶음 동의 금지, F-PRIV-01.1).
- 성공하면 응답의 `state`로 화면을 즉시 갱신하고, 스트림이 뒤따라 같은 값을 준다.
- `consent.documentNotPublished` 오류: 문서 provider를 invalidate하고 시트를 새 문서로 다시 연다.
- 진행 중에는 카드 버튼을 모두 비활성한다. 오프라인이면 `mb.common.offlineAction`(동의 변경은 온라인에서만).

**개정 재동의**(F-PRIV-01.3). `state[type].granted == true`이고 `publishedDocs[type].id != state[type].documentVersion`이면 개정 배너 `mb06.revision.banner` + '새 버전 확인하기' → 문서 시트 → grant(새 버전). 재동의 전에는 이전 동의가 유효하다는 문장을 배너에 포함한다.

**현장 동의 재확인**(F-PRIV-03.8, DF-308)

- 대상: `consentRecords` 중 `channel == trainerDeviceInPerson && action == grant`이고, 그 유형의 현재 상태 `state[type].recordId == record.id`인 레코드. 재확인하면 상태의 `recordId`가 재확인 레코드로 바뀌므로 대상에서 빠진다(06 §6.2.4 5단계).
- 표시: `mb06.reconfirm.item`, 기한 `mb06.reconfirm.due`. 기한 = 이 기기에서 해당 레코드를 처음 본 날 + 30일(제안값, ASM-08-17). 처음 본 날은 SharedPreferences `dfet.member.reconfirm.firstSeen.<recordId>`.
- '맞아요' → 06 `reconfirm(record, clientCaptureId)`(`reconfirmOf = record.id`, 같은 유형·행위·문서 버전 1건).
- '다르면 철회하기' → 해당 유형의 철회 흐름.
- 기한이 지나도 자동 조치는 없다. 목록에 계속 남는다(ASM-08-17, Q-DEV-08-02).

**이력 화면.** `consentRecordsProvider`(최근 50건). 행 `mb06.history.row`: 시각, 채널(`mb06.history.channel.*`), 행위(`reconfirmedAt != null`이면 `reconfirm`), 문서 버전, 기록자(`recordedBy == uid`면 `mb06.history.by.self`, 아니면 `mb06.history.by.trainer`). 트레이너 uid·이름은 보이지 않는다.

**권리 요청 화면**(F-PRIV-07.1)

```
┌ 유형 카드 × 4: 제목 · 설명(mb06.rights.desc.*) · [요청하기]
└ 내 요청 목록: 유형 · 상태(mb06.rights.status.*) · 접수일 · 처리 기한(dueAt)
```

- '요청하기' → 확인 대화상자 → `submit(type, requestId)` → `mb06.rights.submitted`(dueAt 표시).
- 같은 유형의 `received` 또는 `inProgress` 요청이 있으면 그 유형 버튼을 비활성하고 `mb06.rights.pending`을 보인다(ASM-08-23).
- 삭제 요청 카드에는 회원 탈퇴 안내 링크를 함께 둔다(`mb06.rights.desc.erasure`).
- 사유 입력란은 없다(PRD §9.2 '자유 텍스트 사유 없음').
- 열람 요청의 결과 파일은 관리자가 만든 만료 링크로 전달한다. 회원 앱은 상태만 보인다(전달 수단은 Q-DEV-08-03).

**추가 문구 키**

| 키 | 문구 |
|---|---|
| `mb06.research.inPersonOnly` | 연구 참여 동의는 센터에서 연구 안내를 받은 뒤 할 수 있어요. |
| `mb06.rights.pending` | 처리 중인 같은 요청이 있어요. |
| `mb06.rights.confirm` | {요청 유형}을 보낼까요? 접수 후 10일 안에 처리해 드려요. |

**식별자.** `Key('mb06.card.<consentType>')`, `Key('mb06.card.<consentType>.action')`, `Key('mb06.revision.<consentType>')`, `Key('mb06.reconfirm.<recordId>')`, `Key('mb06.rights.<type>.submit')`.

**수용 기준 대응**

| 기준 | 확인 |
|---|---|
| F-PRIV-01.1 묶음·기본 체크 없음 | 위젯 테스트: 한 번의 탭으로 바뀌는 유형이 1개, 초기 체크 상태 없음 |
| F-PRIV-01.2 / AC-PRIV-01.3 다섯 고지 항목 표시 | 문서 시트 골든(항목 5 + ④ 받는 사람) |
| F-PRIV-02 철회 전 결과 안내 | 유형별 대화상자 문구 키 테스트 |
| AC-PRIV-02.2 ② 철회 1분 안 요약 사라짐 | 에뮬레이터 통합 테스트: 철회 callable 뒤 `memberSummaryFeedProvider` 0건(서버 해제 + 클라이언트 `status` 필터) |
| F-PRIV-03.8 재확인 | 합성 레코드 3종(현장·앱·이미 재확인)으로 대상 계산 단위 테스트 |
| F-PRIV-07.1 권리 요청 | 제출 → 목록에 `received`, 같은 유형 중복 버튼 비활성 |

---

## 5 회원 앱 공통 위젯

### 5.1 `DfetReportHeader` 개조

현행은 `axis == null`이면 4축 아이콘 묶음을 그린다(dfet:lib/design_system/d_fet_evidence.dart:224-227). 체형·신체조성 리포트에 4축 표식이 나오면 F-VIZ-06.7·AC-VIZ-07.3 위반이다.

```dart
enum DfetReportMark { auto, none }   // auto = 현행 동작(axis 아이콘 또는 4축 통합 표식)

class DfetReportHeader extends StatelessWidget {
  const DfetReportHeader({
    super.key, required this.axis, required this.eyebrow, required this.title, required this.subtitle,
    this.mark = DfetReportMark.auto,                 // [추가] 기존 호출부는 바뀌지 않음
  });
  final DfetReportMark mark;
  // build: mark == none이면 오른쪽 아이콘 칸(:223-227)을 그리지 않는다. eyebrow 색은 axis == null이면 primary(:192-194) 그대로
}
```

- MB-01·MB-02는 `axis: null, mark: DfetReportMark.none`.
- 테스트: `d_fet_evidence_test.dart`에 'mark none이면 `DfetAxisAssetIcon`이 0개' 추가. 기존 골든은 바뀌지 않아야 한다.

### 5.2 `DfetEvidenceRibbon` 개조

```dart
const DfetEvidenceRibbon({
  super.key, required this.source, required this.coverage, required this.policyVersion, required this.detail,
  this.tone = DfetEvidenceTone.neutral,
  this.title = '판정 근거와 데이터 상태',            // [추가] 기존 문구(:337) 기본값 유지 — 기존 4축 화면 불변
  this.pendingPolicyLabel = '정책 미승인',           // [추가] 기존 문구(:290) 기본값 유지
});
```

- 회원 체형 화면은 `title: MemberCopy.mb01RibbonTitle`, `pendingPolicyLabel: MemberCopy.mb01RibbonPendingPolicy`를 넘긴다.
- 기존 기본값 '판정 근거와 데이터 상태'는 회원 노출 금지어('판정')를 포함한다. 기존 4축 화면 문구 정리는 이 문서 범위 밖이며 [§12.2](#122-충돌) C-08-01에 적었다.

### 5.3 `SourceGradeChip` (DF-131)

| 항목 | 내용 |
|---|---|
| 파일 | `lib/widgets/clinical/source_grade_chip.dart` |
| API | `const SourceGradeChip({super.key, required String sourceGrade, String? reliabilityTier})` |
| 동작 | 회원 라벨이 있는 등급(§3.9)이면 `DfetEvidenceLabel(label, tone: neutral)`. 라벨이 없는 등급이나 빈 문자열이면 `SizedBox.shrink()`를 돌려주고, 호출자는 그 행을 그리지 않아야 한다(`SourceGradeChip.isRenderable(grade)` 정적 함수 제공) |
| 참고 칩 | `reliabilityTier == 'reference'`면 '참고용' 칩을 하나 더 붙인다 |
| 색 | 4축 팔레트(`DfetAxisPalette`)를 참조하지 않는다(AC-VIZ-07.3). 초록 금지(F-VIZ-07.7) |
| 테스트 | 등급 10종 × 라벨 표, `photoAuto`·`observedSection`·`modelEstimate`·`aiAppearance` → shrink |

### 5.4 `SeriesTrendChart` (DF-131)

P1a에 먼저 만들고(DF-131, 회원 화면은 P2부터 사용) P3에 밴드를 켠다(DF-383). `BloodTrendChart`는 고치지 않는다(혈액 화면 D4 불변).

```dart
// lib/widgets/clinical/series_trend_chart.dart
class TrendPoint {
  const TrendPoint({required this.at, required this.value, required this.sourceGrade, required this.seriesKey, this.side = 'none'});
  final DateTime at; final double value; final String sourceGrade; final String seriesKey; final String side;
}
class TrendBand {             // P3: inHouse MDC 밴드. 기준 세그먼트 구간에만 그린다
  const TrendBand({required this.center, required this.halfWidth, required this.from, required this.to, required this.label});
  final double center, halfWidth; final DateTime from, to; final String label;   // label = '측정 오차 범위'
}
class SeriesTrendChart extends StatelessWidget {
  const SeriesTrendChart({
    super.key, required this.points, required this.unit, required this.semanticsTitle,
    required this.singlePointLabel, required this.breakLabel, required this.mixedSourceLabel,
    this.band,
  });
  final List<TrendPoint> points; final String unit; final String semanticsTitle;
  final String singlePointLabel;   // 점 < 2
  final String breakLabel;         // seriesBreak 표식 문구
  final String mixedSourceLabel;   // 출처 등급 혼합 시 렌더 거부 문구
  final TrendBand? band;
}
```

| 규칙 | 구현 | 근거 |
|---|---|---|
| 출처 없는 점 미렌더 | `sourceGrade.isEmpty` 점을 버린다 | F-VIZ-07.1, AC-VIZ-07.1 |
| 출처 혼합 거부 | 남은 점의 `sourceGrade`가 2종 이상이면 차트 대신 `mixedSourceLabel` 텍스트. debug에서는 `assert`로도 알린다 | F-VIZ-07.2 |
| x축 = 날짜 비례 | `x = (at - 첫 점 at).inHours / 24`(일 단위 실수). 아래 축 라벨은 첫·끝 날짜 `M/d`만 | F-VIZ-03(날짜 척도), 반례 dfet:lib/screens/blood/components/blood_trend_chart.dart:97-99 |
| 곡선 금지 | `isCurved: false` | 반례 :101 |
| 보간·0 채움 금지 | 점이 있는 날짜에만 `FlSpot`. 빈 날짜를 만들지 않는다 | F-VIZ-07.6, §7.7 |
| seriesBreak | `seriesKey`마다 `LineChartBarData` 하나. 세그먼트 사이는 잇지 않는다. 새 세그먼트 첫 점에 `VerticalLine(dashArray: [4, 4])`와 라벨 `breakLabel` | F-VIZ-03.3, A-02 |
| 좌우 | `side == 'right'`면 `dashArray: [6, 4]`, 끝 점 옆 'R', `left`는 실선 'L' | A-02, AC-A11Y-03 |
| 밴드(P3) | `band != null`일 때만. 투명 선 2개(`center ± halfWidth`, x 범위 `from~to`)와 `BetweenBarsData`로 채움, 범례 '측정 오차 범위'. `HorizontalRangeAnnotation`은 전체 폭이라 쓰지 않는다 | §6.5.8 개조 조건, F-VIZ-06.6 |
| 색 | 선 `context.wellness.primary`, 끊김 표식 `textTertiary`. 4축 팔레트·초록·빨강 미사용 | F-VIZ-07.7, AC-VIZ-07.3 |
| 접근성 | `Semantics(label: A-03 차트 요약, excludeSemantics: true)` | A-03 |

테스트: `test/widgets/series_trend_chart_test.dart` — 출처 혼합 → 거부 문구, `sourceGrade` 빈 점 제외, 불규칙 간격 3점의 x값 비례(0, 3, 10일), seriesKey 2개 → `lineBarsData.length == 2`와 수직선 1개, 1점 → `singlePointLabel`, 골든 라이트·다크·회색조.

### 5.5 변화 문장 판단(`change_statement.dart`)

회원 화면이 highlight에 무엇을 적을지 정하는 **순수 함수**다. P2에는 서버가 모든 highlight의 `changeStatus`를 null로 보내므로(06 §6.13.4) 결과는 항상 `none`이지만, DF-316에서 함수와 테스트를 먼저 만든다. 배지 모양(글리프)과 밴드 연결은 DF-383(P3)이다.

```dart
enum MemberChangeKind { none, towardGoal, withinError, awayFromGoal, notComparable }

class MemberChangeStatement {
  const MemberChangeStatement(this.kind, [this.text]);
  final MemberChangeKind kind; final String? text;
}

MemberChangeStatement resolveMemberChangeStatement(SummaryHighlight h, {required String? policyVersion, required String family});

/// 리포트 하단 한 줄('변화 비교 기준을 준비하고 있어요')이 필요한가
bool needsPendingFootnote(MemberSummary s) =>
    s.policyVersion == null ||
    s.visibleHighlights.any((h) => resolveMemberChangeStatement(h, policyVersion: s.policyVersion, family: familyOf(h.metricCode)).kind == MemberChangeKind.none);
```

| 입력 | 결과 | 문장(부록 B.8) |
|---|---|---|
| `changeStatus == null` | none | (문장 없음) |
| `policyVersion == null` | none | (문장 없음) |
| `mdcSource != 'inHouse'` | none | (문장 없음) — 문헌 MDC 지표는 회원에게 배지 없음(§7.6) |
| `meaningfulImprovement` + inHouse + policyVersion | towardGoal | 측정 오차보다 큰 변화가 정한 목표 방향으로 나타났어요 |
| `withinError` + inHouse + policyVersion | withinError | 측정 오차 범위 안이에요 |
| `meaningfulDecline` + inHouse + policyVersion | awayFromGoal | 측정 오차보다 큰 변화가 목표와 반대 방향으로 나타났어요 |
| `indeterminate` + `deviceChanged` | notComparable | 이번에는 비교할 수 없어요(측정 기기가 바뀌었어요) |
| `indeterminate` + `protocolChanged` 또는 `conditionMismatch`, 자세 지표 | notComparable | 이번에는 비교할 수 없어요(촬영 조건이 달라요) |
| `indeterminate` + `protocolChanged` 또는 `conditionMismatch`, 그 밖의 지표 | notComparable | 이번에는 비교할 수 없어요(측정 조건이 달라요) — B.8에 없는 문장(ASM-08-19) |
| `indeterminate` + `noComparison` | notComparable | 이번에는 비교할 수 없어요(비교할 이전 기록이 없어요) |
| `indeterminate` + `noMdc`·`referenceMetric`·`betaMetric`·기타 | none | (문장 없음) |
| `pendingPolicy` | none | (문장 없음) |

- 조건 사유 판정 불가는 inHouse 여부와 관계없이 문장을 보인다(F-VIZ-06.3 '조건 사유의 indeterminate는 …'). 단 서버가 비대상 highlight의 `changeStatus`를 null로 저장하므로 실제로는 inHouse 지표에서만 도달한다.
- `family`는 카탈로그 생성 상수의 `family`(`posture`, `bodyComposition`, `circumference` …).
- P3 표시(DF-383): towardGoal·awayFromGoal은 방향 화살표 글리프(`CupertinoIcons.arrow_up_right`·`arrow_down_right`를 `improvementDirection`에 맞춰 선택), withinError는 '=' 글리프, notComparable은 점선 원. 색은 중립 톤(`textSecondary`)이다(§6.5.0).
- 테스트: `test/widgets/change_statement_test.dart` — 위 표 13행 전부, `needsPendingFootnote` 3케이스(정책 null, 전부 문장 있음, 일부 none).

### 5.6 `HighlightRow`

`lib/screens/body_report/widgets/highlight_row.dart`. MB-01·MB-02·MB-04 공용.

```
[회원 지표명] [참고용 칩?]                         [값 단위]  (DfetMetricValue(compact: true, axis: null))
[측면]  [출처 칩]  mb01.highlight.measuredAt
mb01.highlight.comparedTo (comparedTo가 있을 때)
[변화 문장] (MemberChangeKind != none일 때)
```

- `SourceGradeChip.isRenderable(h.sourceGrade) && h.isMemberRenderable`가 아니면 위젯을 만들지 않는다.
- 값 형식은 §3.9. 글자 크기가 커지면 첫 줄의 값이 다음 줄로 내려간다(`Wrap`, 말줄임 없음).
- `Semantics` 라벨은 §3.11 A-03 템플릿.

### 5.7 사용하지 않는 컴포넌트

`AxisRadarChart`, `DfetSignalRail`, `HealthTimeline`, `ProgressEfficacyCard`, `ScoreGauge`, `PoseOverlayPainter`는 MB 화면에서 import하지 않는다. static guard가 `lib/screens/{body_report,trainer_records,consent}/`와 `invite_code_screen.dart`에서 이 이름들과 `DfetAxisPalette`를 grep해 0건을 확인한다(AC-VIZ-07.2, AC-VIZ-07.3).

---

## 6 회원 SOAP 조회 결함 처리

### 6.1 선택지 비교

| 선택지 | 내용 | 판단 |
|---|---|---|
| A. 쿼리 고치기 | `where isSharedWithMember == true`를 더해 규칙을 증명시키고 이메일 쿼리 제거 | **기각.** 공유 시 `diagnosis`·트레이너 메모가 든 원문 전체를 회원이 읽는 구조가 남는다(D9, F-LINK-05.1). 네이티브 기록의 `memberId`는 로컬 UUID라 여전히 0건이다(§2.3 #4). DF-020이 회원 읽기 조항 자체를 없앤다 |
| B. 그대로 두기 | P2까지 방치 | **기각.** 오류를 빈 목록으로 보이는 '알리지 않은 실패'가 계속된다(§9.6, M-G3 취지). 행 이름 'SOAP 노트'가 회원 문구 규칙(B.8)에 맞지 않는다 |
| C. P0에 진입점을 숨기고 P2에 교체 | 아래 단계표 | **채택** |

### 6.2 단계별 작업

| 단계 | 스토리 | 작업 | 파일 |
|---|---|---|---|
| P0(S04) | DF-029(ASM-08-01) | 내 정보 'SOAP 노트' 행과 `member_soap_notes_screen.dart` import를 지운다. 화면 파일은 P2까지 남는다(참조 없음) | dfet:lib/screens/ios_profile_screen.dart:11, :117-129 |
| P0~P1a | DF-020, DF-931 | 규칙에서 회원의 `soap_notes` 읽기 조항(dfet:firestore.rules:142-143)을 없앤다. 앱 변경 없음 | `firestore.rules` |
| P2(S21-S22) | DF-315 | ① `loadMemberSoapNotes` 삭제 ② `soapNotesProvider`의 회원 분기 삭제 ③ `member_soap_notes_screen.dart` 삭제 ④ MB-03 행 추가 ⑤ static guard 범위 적용 | 아래 |
| P3 | DF-387(MIG-09) | 트레이너 폴백 제거 뒤 static guard 예외 경로를 지운다 | `tool/lint/static-guards.sh` |

P2 코드 변경(DF-315)

```dart
// lib/state/soap_note_state.dart — :26-39 교체
final soapNotesProvider = FutureProvider.autoDispose<List<SoapNote>>((ref) async {
  final isTrainerGuest = ref.watch(isTrainerGuestModeProvider);
  if (isTrainerGuest) { … 기존 :21-24 그대로 … }
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final profile = await ref.watch(userProfileProvider.future);
  // 트레이너 폴백(동결, MIG-09) 전용. 회원은 memberSummaries만 쓴다(ADR-006, AC-SOAP-05.6)
  if (profile?.isTrainer == true || profile?.isAdmin == true) {
    return ref.watch(firestoreServiceProvider).loadTrainerSoapNotes(user.uid);
  }
  return const <SoapNote>[];
});
```

- `FirestoreService.loadMemberSoapNotes`(dfet:lib/services/firestore_service.dart:594-654)를 통째로 지운다.
- `loadTrainerSoapNotes`의 오류 삼킴(:588-591)은 동결된 트레이너 폴백 코드라 고치지 않는다(MIG-09 제거 대상).

### 6.3 회귀 방지

- 새 저장소는 `catch → []` 패턴을 쓰지 않는다([§3.3](#33-저장소와-오류)). 리뷰 체크리스트 항목이다.
- 위젯 테스트: `memberSummaryFeedProvider`를 `Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'))`로 덮으면 MB-03이 `mb.common.loadFailed`를 보이고 `mb03.empty`는 보이지 않는다.

### 6.4 정적 가드 범위

AC-VIZ-06.1은 '회원 앱 코드에서 원 기록 컬렉션 경로 문자열 0건'이다. 그러나 `lib/`에는 MIG-09(P3)까지 동결된 트레이너 폴백과 네이티브 콜백이 남아 `soap_notes`를 쓴다(dfet:lib/widgets/shells/trainer_shell.dart:452-590, dfet:lib/services/firestore_service.dart:562-673). 그래서 P2의 grep 범위를 **회원 경로**로 정한다(ASM-08-20, C-08-02).

```bash
# tool/lint/static-guards.sh 일부 (DF-011이 만들고 DF-315가 이 블록을 추가)
MEMBER_PATHS=(
  lib/screens/body_report lib/screens/trainer_records lib/screens/consent lib/screens/invite_code_screen.dart
  lib/screens/ios_profile_screen.dart lib/screens/report_hub_screen.dart
  lib/services/member_summary_repository.dart lib/services/consent_repository.dart
  lib/services/invite_repository.dart lib/services/rights_request_repository.dart
  lib/state/member_summary_state.dart lib/state/consent_state.dart
  lib/models/member_summary.dart lib/models/consent.dart lib/models/rights_request.dart
  lib/widgets/clinical/source_grade_chip.dart lib/widgets/clinical/series_trend_chart.dart lib/widgets/clinical/change_statement.dart
)
RAW_COLLECTIONS="'(soap_notes|postureAssessments|bodyCompositionRecords|circumferenceMeasurements|bodyScans)'"
grep -RnE "$RAW_COLLECTIONS" "${MEMBER_PATHS[@]}" && fail "AC-VIZ-06.1 raw record path in member code"
grep -RnE "loadMemberSoapNotes|MemberSoapNotesScreen" lib && fail "legacy member SOAP path"
grep -RnE "AxisRadarChart|DfetSignalRail|DfetAxisPalette|ProgressEfficacyCard" \
  lib/screens/body_report lib/screens/trainer_records lib/widgets/clinical/series_trend_chart.dart \
  && fail "AC-VIZ-07.2/07.3 4-axis component in body report"
```

- DF-387(MIG-09) 뒤에는 `MEMBER_PATHS` 대신 `lib/` 전체에서 `lib/models/soap_note*.dart`(교차 픽스처 코덱)와 `lib/admin/`(레거시, 별도 정리)만 제외한다.

---

## 7 P0 규제 문구 수정과 Runner 동결

### 7.1 회원 앱 문구 교체(DF-029, MIG-04, S04)

| 위치(확인한 현행) | 현행 문구 | 교체 | 비고 |
|---|---|---|---|
| dfet:lib/screens/guide_screen.dart:36 | 체형 분석 (Posture) | 운동 자세 촬영 (Posture) | 정적 체형평가는 회원 앱에 없다. 실제 기능(기록 탭 '자세 평가', dfet:lib/screens/record_hub_screen.dart:423-466)을 설명한다 |
| dfet:lib/screens/guide_screen.dart:38-41 | AI를 이용해 체형 불균형을 분석합니다. … AI가 거북목, 골반 불균형 등을 분석해줍니다. | 스쿼트·푸시업·플랭크 동작을 촬영하면 관절 각도를 참고용으로 보여 드려요.\n\n1. 기록 탭 '자세 평가'에서 동작을 고르고 '평가 시작'을 누르세요.\n2. 전신이 나오도록 카메라 앞에 서 주세요.\n3. 동작을 마치면 각도 기록과 운동 팁을 확인할 수 있어요. | 질환명·진단성 라벨 제거(부록 C.1, §3.4-8) |
| dfet:lib/screens/guide_screen.dart:48-50 | 체중 변화: 체중과 골격근량의 변화 추이를 보여줍니다. | • 운동 기록: 주간·월간 운동 시간과 칼로리 기록을 그래프로 보여 드려요. | 금지어는 아니지만 없는 기능을 안내한다(ASM-08-21, should) |
| dfet:lib/screens/onboarding_screen.dart:40 | 체형 교정 | 자세 균형 운동 | 목표 선택지. 이미지 경로 switch(:544)의 case도 함께 바꾼다 |
| dfet:lib/screens/profile_setup_screen.dart:38 | 체형 교정 | 자세 균형 운동 | switch(:358) case 함께 |
| dfet:lib/screens/create_request_screen.dart:150 | 새로운 자세 교정 요청 | 새로운 자세 확인 요청 | 저장 값 `type: 'postureCheck'`(:107)는 식별자라 그대로 |
| dfet:lib/screens/ios_profile_screen.dart:117-129 | 'SOAP 노트' 행 | 삭제 | §6.2(ASM-08-01) |

- **저장된 목표 값 호환.** `users.goal`에 '체형 교정'이 이미 저장된 회원이 있을 수 있다(dfet:lib/models/user_profile.dart:115, :148). 값을 이관하지 않고 표시에서만 바꾼다: `lib/models/user_profile.dart`에 `String? get displayGoal => goal == '체형 교정' ? '자세 균형 운동' : goal;`를 두고 `dfet:lib/screens/my_info_screen.dart:76`이 `profile.displayGoal`을 쓴다. 온보딩·프로필 화면의 선택 상태 비교도 `displayGoal` 기준이다.
- 이미지 자산 파일 이름은 바꾸지 않는다(식별자).
- 수용 기준: 네 파일과 `my_info_screen.dart`에서 회원 세트 금지어 0건(copy-lint 보고 모드 결과), 기존 골든 `onboarding_caretype*.png`는 목표 화면이 아니라 영향 없음, `onboarding_flow_test.dart` 통과.
- 이 릴리스는 소유자가 DF-911로 제출하며, G-05a 제출(DF-910) 전에 배포돼야 한다.

### 7.2 Runner 내장 트레이너 규제 수정(DF-028, 동결 예외)

작업 상세는 [07_TRAINER_APP_SPEC.md](07_TRAINER_APP_SPEC.md)와 DF-028 스토리에 있다. 여기서는 확인한 위치와 대체어만 적는다.

- DF-028은 G-01(DF-901) 뒤 `main`에서 분기해 작업한다. `main`에는 트레이너 UI 미커밋 변경(B분류)이 없으므로 **첫 열(`main` 줄 번호)이 수정 위치**다. 둘째 열은 현재 작업 트리(`feature/integrated-care-2026`, 미커밋 포함) 줄 번호이며 참고용이다. 전체 대응표는 [11_MIGRATION_RUNBOOK.md §6.2](11_MIGRATION_RUNBOOK.md#62-출시-앱-문구--main-줄-번호-대응표)를 따른다.
- 줄 번호가 어긋나면 표의 '현행' 문자열로 검색해 위치를 찾는다.

| 위치 `main`(HEAD d841412, 수정 기준) | 작업 트리(참고) | 현행(확인) | 조치 |
|---|---|---|---|
| dfet:ios/Runner/AppDelegate.swift:2062 | :2857 | 프로그램명 목록 `["통증 관리", "자세 교정", "재활 트레이닝", "근력 강화", "체형 교정", "컨디셔닝", "퍼포먼스", "홈운동 관리"]` | '자세 교정' → '자세 균형 운동', '재활 트레이닝' → '컨디션 관리 운동', '체형 교정' → '가동성 운동'. '통증 관리'는 금지어 표에 없으나 소유자 검토 대상(ASM-08-24) |
| :3049 | :3844 | `"diagnosis": selectedMember.subtitle,` | 키 삭제(자동 채움 제거, §3.4-3) |
| :3524, :3533 | :4319, :4328 | 치료계획, 홈운동, 다음 세션… | '운동 계획, 홈운동, 다음 세션…' |
| :3930-3931 | :4725-4726 | 부제·placeholder '치료계획, …' | '운동 계획, …' |
| :7860 | :8717 | placeholder '세션 중 치료/운동 계획' | '세션 중 운동 계획' |
| :8101 | :8958 | `inspectorField("진단/이슈", text: $diagnosis)` | 입력 필드 삭제 |
| :613 | 없음(B분류 program 상세 화면으로 교체됨) | program 자리 표시 subtitle '운동 처방, 세트, 반복, 강도, 진행도를 관리합니다.' | '운동 계획, 세트, 반복, 강도, 진행도를 관리합니다.' PRD MIG-04 목록에 없는 `main` 줄(V1-12 X-06) |

### 7.3 Runner 동결 정책(MIG-09)

| 항목 | 규칙 |
|---|---|
| 대상 | `ios/Runner/AppDelegate.swift`의 트레이너 화면·채널, `lib/widgets/shells/trainer_shell.dart`, `lib/screens/trainer/**`, 트레이너용 `FirestoreService` 메서드 |
| 허용 변경 | 크래시, 데이터 유실, 보안·규제 수정(MIG-04 포함)만. PR에 `freeze-exception` 라벨과 사유(PRD §11.10, ADR-014) |
| 금지 | 새 기능, UI 개선, 새 컬렉션 쓰기 경로 |
| CODEOWNERS | `ios/Runner/AppDelegate.swift`는 소유자 검토 필수(GH-09) |
| SOAP 쓰기 | MIG-03 적용(DF-924, S09) 뒤 v1 쓰기가 규칙에서 막히므로 Runner 트레이너의 SOAP 저장은 실패한다. 적용 전에 Runner 트레이너 사용자에게 종료를 공지한다(§11.4) |
| 제거 | P3 DF-387. 제거 릴리스에서 트레이너 계정이 로그인하면 새 앱 안내를 보인다. 안내 문구 키 `trainer.movedToNewApp`: '트레이너 기능은 D-FET Trainer iPad 앱으로 옮겨졌어요. 새 앱에서 로그인해 주세요.' |
| 회원 앱 영향 | 회원 화면(MB-*)은 동결 대상이 아니다. 회원 앱 릴리스 태그 `member-vX.Y.Z` |


---

## 8 admin_web 공통 설계

### 8.1 파일 배치

| 경로 | 종류 | 내용 | 단계·스토리 |
|---|---|---|---|
| `admin_web/lib/generated/contracts.ts` | [신규·생성물] | 플래그 키, 지표 카탈로그, 어휘, audit action 목록(ASM-08-26) | P0, DF-004·DF-027·DF-033 |
| `admin_web/lib/domain/feature-flags.ts` | [신규] | 8키 스키마 생성·읽기(순수) | P0, DF-027 |
| `admin_web/lib/domain/assignment.ts` | [신규] | 배정 모드·인계 판정(순수) | P0, DF-025 |
| `admin_web/lib/domain/consent-document.ts` | [신규] | 동의 문서 zod·게시 검증(순수) | P1a 진입 전, DF-032 |
| `admin_web/lib/domain/audit-normalize.ts` | [신규] | `at ?? createdAt`, `targetId ?? target.*` 정규화와 병합 정렬(순수) | P1a, DF-136 |
| `admin_web/lib/domain/body-change-policy.ts` | [신규] | bodyChange 정책 zod·승인 검증(순수) | P1b, DF-221 |
| `admin_web/lib/audit.ts` | [수정] | `writeAuditEvent`, `recordHealthRead` 추가. 기존 `writeAudit` 유지 | P1a, DF-136 |
| `admin_web/lib/auth.ts` | [수정] | `readRole` claim 통일(P1a), 역할 분리(P3) | DF-101, DF-385 |
| `admin_web/lib/firebase-client.ts` | [수정] | `callAdminFunction(name, data)` 브라우저 callable 도우미 | P2, DF-317 |
| `admin_web/components/console-shell.tsx` | [수정] | 메뉴 추가 | 각 화면 스토리 |
| `admin_web/app/(console)/settings/feature-flags/page.tsx`, `components/feature-flag-editor.tsx`, `app/api/admin/feature-flags/route.ts` | [수정] | AD-07 | P0, DF-027 |
| `admin_web/app/(console)/assignments/page.tsx`, `components/assignment-editor.tsx`, `app/api/admin/assignments/route.ts` | [수정] | AD-01 인계 안내·감사 | P0, DF-025 |
| `admin_web/app/api/admin/roles/route.ts`, `components/role-editor.tsx` | [수정] | 트레이너 해제 경고 | P0, DF-025(ASM-08-27) |
| `admin_web/app/(console)/consent-documents/page.tsx`, `components/consent-document-editor.tsx`, `app/api/admin/consent-documents/route.ts` | [신규] | AD-03 | DF-032 |
| `admin_web/app/(console)/users/[uid]/page.tsx` | [수정] | 열람 감사, v2 집계 | P1a, DF-136 |
| `admin_web/app/(console)/audit/page.tsx` | [수정] | P1a 병합 조회, P2 필터·월간 검토 | DF-136, DF-317 |
| `admin_web/app/(console)/metric-catalog/page.tsx` | [신규] | AD-05 | P1b, DF-220 |
| `admin_web/app/api/clinical/config/route.ts`, `components/config-editor.tsx` | [수정] | bodyChange kind | P1b DF-221, P3 DF-384 |
| `admin_web/app/api/clinical/config/activate/route.ts` | [신규] | 승인본 활성화·롤백 | P3, DF-384(ASM-08-32) |
| `admin_web/app/(console)/rights-requests/page.tsx`, `components/rights-request-actions.tsx`, `app/api/admin/rights-requests/route.ts` | [신규] | AD-06 권리 요청 | P2, DF-317 |
| `admin_web/app/api/admin/audit-reviews/route.ts` | [신규] | 월간 검토 기록 | P2, DF-317(ASM-08-35) |
| `admin_web/app/(console)/pending-members/page.tsx`, `app/api/admin/pending-members/route.ts` | [신규] | AD-02 | P2, DF-318 |
| `admin_web/test/*.test.mjs` | [신규] | 순수 모듈 테스트 | 각 스토리 |

### 8.2 역할과 권한

| 시점 | 판정 | 근거 |
|---|---|---|
| 현재~DF-101 전 | `readRole`: `admin === true` 또는 `role === 'admin'`(dfet:admin_web/lib/auth.ts:18-23) | 현행 |
| DF-101(P1a, S09) 뒤 | `claims.admin === true` → admin, `claims.trainer === true` → trainer, `claims.role === 'lab_operator'` → lab_operator. `role === 'admin'` 문자열만으로는 admin이 아니다 | ADR-018, PRD §10.7, R-23 |
| DF-385(P3) 뒤 | admin을 `operator`(D-FET 운영)와 `center`(센터 관리자)로 나눈다(ASM-08-25) | PRD §6.7.0, §8.3 |

```ts
// admin_web/lib/auth.ts (DF-101)
function readRole(claims: Record<string, unknown>): ConsoleRole | null {
  if (claims.admin === true) return 'admin';
  if (claims.trainer === true) return 'trainer';
  if (claims.role === 'lab_operator') return 'lab_operator';
  return null;
}
```

- 제거 순서: MIG-02 실사(DF-907)에서 운영 관리자 전원이 `admin` claim을 가진 것을 확인한 뒤 DF-101을 병합한다(PRD §10.7, 05 §7.10).
- 모든 새 페이지는 `await requireConsoleUser(['admin'])`, 모든 새 라우트는 `if (!actor || actor.role !== 'admin') return 403`. `roleCanAccess`는 admin에게 전부 열려 있어(dfet:admin_web/lib/auth.ts:54) 새 메뉴를 추가해도 목록 변경이 필요 없다. trainer·lab_operator는 새 메뉴를 보지 못한다.
- P3 역할 분리 화면 배정(PRD §8.3): `operator` → AD-05, AD-07, 수집·작업·콘텐츠. `center` → AD-01~AD-04, AD-06, 회원·요청. 원 기록 열람(회원 상세)은 `center`만, `operator`의 열람은 위탁계약 범위 안에서만 허용하고 감사한다(§6.7.0).

### 8.3 라우트 공통 틀

기존 패턴(dfet:admin_web/app/api/admin/feature-flags/route.ts:12-29)을 따르고, 검증은 `lib/domain/*.ts` 순수 함수에 둔다.

```ts
export async function POST(request: NextRequest) {
  try {
    assertSameOrigin(request);
    const actor = await getConsoleUser();
    if (!actor || actor.role !== 'admin') return NextResponse.json({ error: '관리자 권한이 필요합니다.' }, { status: 403 });
    const input = schema.parse(await request.json());          // zod 오류 → 400
    const result = await adminDb.runTransaction(async (tx) => { /* 읽기 전부 → 검증(domain) → 쓰기 */ });
    await writeAuditEvent(actor, { … });                        // 또는 기존 writeAudit(레거시 action)
    return NextResponse.json({ ok: true, ...result });
  } catch (cause) {
    const status = cause instanceof ConflictError ? 409 : 400;
    return NextResponse.json({ error: cause instanceof Error ? cause.message : '처리 실패' }, { status });
  }
}
```

- 상태 전환 위반(published 수정, 승인본 수정)은 409, 형식 위반은 400, 권한은 403이다.
- 트랜잭션은 모든 읽기를 쓰기보다 먼저 한다(06 §3.8).
- 오류 문구는 운영자용 한국어다. 관리자 화면 문구도 공통 금지어 린트 대상이다(부록 C.3 공통 세트).

### 8.4 내비게이션

`admin_web/components/console-shell.tsx`의 `nav` 배열(:9-24)에 추가한다.

| section | label | href | 단계 |
|---|---|---|---|
| 개인정보 | 동의 문서 | `/consent-documents` | DF-032 |
| 개인정보 | 권리 요청 | `/rights-requests` | DF-317 |
| 개인정보 | 대기 회원·초대 | `/pending-members` | DF-318 |
| 설정 | 지표 카탈로그 | `/metric-catalog` | DF-220 |
| 설정 | '통합 정책' → '정책 버전'으로 이름 변경(bodyChange 포함) | `/settings/insight-policies` | DF-221 |

- 메뉴는 해당 스토리의 PR에서 함께 추가한다. 미완성 화면의 메뉴를 먼저 넣지 않는다(AC-IA-02 취지).

### 8.5 감사 기록

06 §3.9 형식을 admin_web에서도 쓴다(06 ASM-06-30).

```ts
// admin_web/lib/audit.ts (DF-136)
import { AUDIT_ACTIONS } from './generated/contracts';

export async function writeAuditEvent(actor: ConsoleUser, e: {
  action: string; targetCollection: string; targetId: string; memberUid: string | null;
  metadata?: Record<string, string | number | boolean | Record<string, number>>;
}): Promise<void>;
// 1) AUDIT_ACTIONS에서 e.action을 찾지 못하면 throw(테스트에서 실패)
// 2) metadata는 해당 action의 metadataKeys만 남긴다
// 3) auditLogs.add({action, actorUid, actorRole, targetCollection, targetId, memberUid, at: serverTimestamp(), metadata, schemaVersion: 1})
//    actorEmail은 쓰지 않는다(PRD §9.7)

export async function recordHealthRead(
  actor: ConsoleUser, memberUid: string,
  targetCollection: 'users' | 'soap_notes' | 'postureAssessments' | 'bodyCompositionRecords'
    | 'circumferenceMeasurements' | 'bodyScans' | 'memberSummaries' | 'pendingMembers',
  targetId: string,
): Promise<void>;   // = writeAuditEvent(actor, {action: 'healthRecordRead', …, metadata: {surface: 'adminMemberDetail'}})  (06 §7.6)
```

- 기존 `writeAudit`(dfet:admin_web/lib/audit.ts:6-21)과 그 action 문자열(`member.assignment.update`, `app.feature_flags.update`, `auth.role.update`, `admin.application.*`, `clinical.config.publish`)은 유지하되 DF-136에서 `actorEmail`을 빼고 `at`도 함께 쓰도록 바꾼다. 이 문자열들은 `contracts/audit-actions.v1.json`에 등록한다(06 ASM-06-03).
- **읽기 정규화.** 레거시 문서는 `createdAt`·`target` 맵, 새 문서는 `at`·`targetId`다. Firestore `orderBy`는 필드가 없는 문서를 빼므로, 목록은 `orderBy('at', 'desc').limit(n)`과 `orderBy('createdAt', 'desc').limit(n)` 두 쿼리를 합쳐 `at ?? createdAt`으로 정렬한다(`lib/domain/audit-normalize.ts`, ASM-08-36). DF-136이 기존 감사 화면(dfet:admin_web/app/(console)/audit/page.tsx:10)에 먼저 적용한다. 두 필드를 모두 가진 문서는 ID로 중복을 없앤다.

### 8.6 생성된 contracts 사용

`admin_web/lib/generated/contracts.ts`(DF-004 emitter `adminWeb.mjs`)가 아래 이름을 내보낸다고 가정한다(ASM-08-26). 이름을 바꾸면 이 문서와 코드를 같은 PR에서 고친다.

```ts
export const FEATURE_FLAGS: readonly { key: string; default: false; phase: string; ruleGatedCollections: readonly string[] }[];
export const FEATURE_FLAG_KEYS: readonly ['gut','blood','insights','soapV2','bodyComposition','bodyAssessment','memberShare','lidarBeta'];
export const METRIC_CATALOG: readonly { metricCode: string; nameKo: string; family: string; unit: string; sideRule: string;
  allowedSourceGrades: readonly string[]; reliabilityTier: string | null; improvementDirection: string;
  conditionKeys: readonly string[]; availability: string }[];
export const METRIC_CODES: readonly string[];
export const CONSENT_TYPES: readonly ['required','healthData','bodyImaging','sharing','research'];
export const MDC_SOURCES: readonly ['literature','inHouse'];
export const IMPROVEMENT_DIRECTIONS: readonly ['higherIsBetter','lowerIsBetter','towardZero','none'];
export const VOCAB_DRAFT_ENUMS: readonly string[];   // 부록 A.5~A.7 확정 전 목록 이름
export const AUDIT_ACTIONS: readonly { action: string; phase: string; metadataKeys: readonly string[] }[];
```

- `lib/domain/*.ts`는 생성물을 직접 import하지 않고 인자로 받는다. Node 테스트에서 `@/` 경로 별칭을 풀 수 없기 때문이다(ASM-08-18).

### 8.7 브라우저에서 부르는 관리자 callable

관리자 전용 callable(`exportMemberData`, `submitRightsRequest` 관리자 대리 접수, `deleteUserData`)은 admin_web 서버가 대신 부르지 않는다. 서버는 세션 쿠키만 가지고 관리자 ID 토큰이 없다(06 §7.3).

```ts
// admin_web/lib/firebase-client.ts (DF-317)
import { getFunctions, httpsCallable } from 'firebase/functions';
export async function callAdminFunction<Req, Res>(name: 'exportMemberData' | 'submitRightsRequest' | 'deleteUserData', data: Req): Promise<Res> {
  if (!clientAuth.currentUser) throw new Error('다시 로그인해 주세요.');           // ASM-08-38
  const fn = httpsCallable<Req, Res>(getFunctions(app, ADMIN_CALLABLE_REGION[name]), name);
  return (await fn(data)).data;
}
```

- 리전은 함수별로 둔다. `exportMemberData`·`submitRightsRequest`는 asia-northeast3(06), `deleteUserData`는 현재 기본 리전이다(dfet:functions/index.js:330, `deleteOwnAccount`만 asia-northeast3 :378-379). 기존 callable 리전은 바꾸지 않으므로(NFR-16) 도우미는 `{exportMemberData: 'asia-northeast3', submitRightsRequest: 'asia-northeast3', deleteUserData: undefined}` 표로 `getFunctions(app, region)`을 고른다.

---

## 9 관리자 화면 명세(AD-01~AD-07)

### 9.1 AD-01 트레이너·배정

| 항목 | 내용 |
|---|---|
| PRD | §8.3 AD-01, F-LINK-03, F-LINK-05.4, §9.7 auditLogs(배정 변경 감사 `metadata.handover`) |
| 스토리 | DF-025(P0, S05)의 admin_web 부분(ASM-08-27 포함), DF-101(P1a, claim 통일) |
| 경로 | `/assignments`(배정), `/users`(역할·트레이너 승인), `/admins`(관리자 승인) — 기존 |

**배정 화면 변경**

1. 표에 '동의 ④' 열을 추가한다. 서버 컴포넌트가 목록 회원의 `memberConsentStates/{uid}`를 `adminDb.getAll(...refs)`로 한 번에 읽어 `있음`/`없음`/`기록 없음`(상태 문서 없음)을 보인다. 동의 유형 외 내용은 보이지 않는다.
2. `AssignmentEditor`는 저장 전에 모드별 확인창을 띄운다(`lib/domain/assignment.ts`의 `assignmentNotice(mode, sharingGranted)`).

| 모드 | 조건 | 확인 문구 |
|---|---|---|
| `assign` | 현재 담당 없음 → 새 담당 | 담당 트레이너를 배정합니다. |
| `reassign` + ④ 있음 | 담당 A → B | 동의 ④가 있어 확정된 기록을 새 담당 트레이너에게 넘깁니다. 작성 중인 기록은 넘기지 않습니다. 이전 트레이너의 접근은 바로 끊깁니다. |
| `reassign` + ④ 없음 | 담당 A → B | 동의 ④가 없어 새 담당 트레이너는 이전 기록을 볼 수 없습니다. 이전 트레이너의 접근도 바로 끊깁니다. |
| `remove` | 담당 A → 없음 | 담당을 해제하면 어떤 트레이너도 이 회원의 기록에 접근할 수 없습니다. 기록은 보유기간 규칙에 따라 관리됩니다. |

3. 저장 뒤 결과 문구: '저장했습니다. 기록 접근 권한 정리는 잠시 뒤 반영됩니다.'(재정렬은 비동기, RISK-10).

**배정 라우트 변경**(dfet:admin_web/app/api/admin/assignments/route.ts)

```ts
// lib/domain/assignment.ts
export type AssignmentMode = 'assign' | 'reassign' | 'remove' | 'noop';
export function assignmentMode(previous: string | null, next: string | null): AssignmentMode;
export function handoverFor(mode: AssignmentMode, sharingGranted: boolean): boolean {   // F-LINK-05.4
  return mode === 'reassign' && sharingGranted;
}
```

- 트랜잭션의 읽기 단계(:20-31)에 `memberConsentStates/{memberUid}` 읽기를 더한다(쓰기보다 먼저).
- `noop`(같은 트레이너)이면 400 '변경 사항이 없습니다.'
- 감사: 기존 action `member.assignment.update`, `metadata: {trainerUid, mode, handover}`(06 §3.9 표). `target`은 기존 `{uid}` 유지.
- 응답 `{ok: true, mode, handover}`.
- 기록 `trainerId` 재정렬은 라우트가 호출하지 않는다. `users/{uid}.trainerId` 변경을 `syncRecordAccessKeys` 트리거가 처리한다(06 §6.1, C-04).

**트레이너 승인·해제**(`/users`의 역할 편집, `/api/admin/roles`)

- 승인: 역할을 `trainer`로 바꾸면 claim `trainer: true`와 `trainers/{uid}`(`approvalStatus: 'approved'`, `memberIds` 초기화)가 생긴다(dfet:admin_web/app/api/admin/roles/route.ts:29-52). 변경 없음.
- 해제 경고(ASM-08-27): trainer에서 다른 역할로 바꿀 때 `trainers/{uid}.memberIds`가 비어 있지 않으면 라우트가 409 `{error: '담당 회원 n명을 먼저 다른 트레이너에게 배정하세요.', assignedCount: n}`를 돌려준다. 편집기는 확인창을 띄우고 동의하면 `confirmUnassigned: true`를 붙여 다시 보낸다. 담당 회원이 남은 채 해제되면 그 회원들은 claim 없는 담당자를 가리키게 되어 트레이너 접근이 사실상 끊긴다(규칙 `isTrainer()`).
- 관리자 승인 화면(`/admins`)은 변경 없음. DF-101 뒤에도 승인 라우트가 `admin: true` claim을 쓰므로(dfet:admin_web/app/api/admin/approvals/route.ts:34-38) 판정 통일과 맞는다.

**상태.** 빈 상태(회원 없음), 동기화 실패(저장 오류 문장). §8.4 매트릭스 AD 행.

**테스트.** `admin_web/test/assignment.test.mjs`: `assignmentMode` 4경우, `handoverFor` 표. 수동(에뮬레이터): ④ 있음/없음 재배정 뒤 감사 문서 `metadata.handover` 확인, 06 TC의 재정렬 결과와 대조.

### 9.2 AD-02 대기 회원·초대 현황

| 항목 | 내용 |
|---|---|
| PRD | §8.3 AD-02, F-LINK-01.2, F-LINK-02.3·02.6, §4.5 |
| 스토리 | DF-318(P2, S25-S26, should) |
| 경로 | `/pending-members`, `GET /api/admin/pending-members`(06 §7.4), `POST /api/admin/pending-members`(ASM-08-28) |

**목록**(서버 컴포넌트, `?status=pending|promoted|cancelled|expired`, 기본 pending)

| 열 | 값 |
|---|---|
| 대기 회원 | `displayName`, 문서 ID(mono) |
| 생성 트레이너 | `trainerId`(mono) |
| 상태 | `StatusPill`(pending, promoted, cancelled, expired) |
| 초대 코드 | 최신 코드의 `status`와 `expiresAt`(`inviteCodes where pendingMemberId == p`). **코드 원문·해시는 보이지 않는다**(AC-LINK-02.2) |
| 최근 실패 | `lastRedeemFailure.reason`(`conflict` 등)과 시각(ASM-08-29) |
| 승격 | `promotedUid`(있으면 `/users/{uid}` 링크), `promotedAt` |
| 생성·만료 | `createdAt`, `cancelledAt`·`expiredAt` |

- 페이지를 렌더할 때마다 `recordHealthRead`를 목록 단위로 1건 남긴다(`targetCollection: 'pendingMembers'`, `targetId: '(list)'`, `memberUid: null`, `metadata: {surface: 'adminMemberDetail', pendingMember: true}`). 06 §7.4의 '조회마다 기록'을 목록 단위로 해석했다(ASM-08-28).

**조치**(`POST /api/admin/pending-members`, ASM-08-28)

| op | 조건 | 처리 | 감사 |
|---|---|---|---|
| `cancel` | `status == 'pending'` | `status: 'cancelled'`, `cancelledAt`(서버 시각). 파기는 `purgeExpiredRecords`가 5영업일 안에 한다(F-LINK-01.5) | `pendingMember.cancel`(audit-actions 등록) |
| `revokeInvite` | 최신 코드 `status == 'active'` | 코드 `status: 'revoked'` | `inviteCode.revoke`(등록) |

- conflict(다른 담당이 있는 회원이 코드를 입력) 처리는 이 화면에서 하지 않는다. `lastRedeemFailure.uid`의 회원 상세로 이동해 AD-01에서 배정을 정리한다(F-LINK-02.6).

### 9.3 AD-03 동의 문서 버전

| 항목 | 내용 |
|---|---|
| PRD | §8.3 AD-03, F-PRIV-01.2·01.3·01.5, AC-PRIV-01.3·01.4, §9.2 `consentDocumentVersions`, G-04, G-09, Q-24 |
| 스토리 | DF-032(P0 키, S06, P1a 진입 전제) |
| 경로 | `/consent-documents`, `GET·POST /api/admin/consent-documents`(06 §7.2) |

**화면**

```
┌ 유형 탭 5개(required, healthData, bodyImaging, sharing, research)
├ 버전 표: version · status · publishedAt · privacyPolicyVersion · [보기] [비교] [초안 편집](draft만)
├ 편집기(ConsentDocumentEditor): title, purpose, items(한 줄에 하나), retention, recipient(sharing만 표시·필수), refusalNotice, privacyPolicyVersion
│   [초안 저장] [게시] — 게시 전 검증 결과 목록을 먼저 보인다
└ 비교: 직전 published와 필드별 나란히(바뀐 필드 강조)
```

**zod와 게시 검증**

```ts
// admin_web/lib/domain/consent-document.ts
import { z } from 'zod';
export function buildConsentDocumentSchema(consentTypes: readonly string[]) {
  return z.object({
    consentType: z.enum(consentTypes as [string, ...string[]]),
    version: z.string().regex(/^\d+\.\d+$/),                    // 예 "1.0"
    title: z.string().min(1).max(100),
    purpose: z.string().max(2000),
    items: z.array(z.string().min(1).max(200)).max(50),
    retention: z.string().max(500),
    recipient: z.string().max(500).nullable(),
    refusalNotice: z.string().max(2000),
    privacyPolicyVersion: z.string().max(40),
  }).strict();
}
export type PublishIssue =
  | 'purposeEmpty' | 'itemsEmpty' | 'retentionNotSpecific' | 'refusalNoticeEmpty'
  | 'recipientRequired' | 'privacyPolicyVersionEmpty';
export function validateForPublish(doc: ConsentDocumentInput): PublishIssue[] {
  const issues: PublishIssue[] = [];
  if (!doc.purpose.trim()) issues.push('purposeEmpty');
  if (doc.items.length === 0) issues.push('itemsEmpty');
  if (!/\d+\s*(일|개월|년)/.test(doc.retention)) issues.push('retentionNotSpecific');   // ASM-08-31, Q-24
  if (!doc.refusalNotice.trim()) issues.push('refusalNoticeEmpty');                     // 거부권 + 불이익
  if (doc.consentType === 'sharing' && !doc.recipient?.trim()) issues.push('recipientRequired');   // F-PRIV-01.5
  if (!doc.privacyPolicyVersion.trim()) issues.push('privacyPolicyVersionEmpty');       // G-09
  return issues;
}
```

| op(06 §7.2) | 처리 | 실패 |
|---|---|---|
| `createDraft` | 문서 ID `{consentType}--{version}`(05 §4.13, C-08-06)로 create, `status: 'draft'` | 이미 있으면 409 |
| `updateDraft` | `status == 'draft'`만 수정 | published·retired면 409 |
| `publish` | 트랜잭션: 대상 읽기, 같은 유형의 published 읽기 → `validateForPublish` → 대상 `published`, `publishedAt` / 이전 published `retired`, `retiredAt` | 검증 실패 400(이슈 목록 반환), draft 아님 409 |
| `retire` | published → retired | 그 밖 409 |
| `GET ?consentType=` | 목록(관리자) | — |

- published 문서는 수정·삭제하지 않는다(PRD §9.2). 회원·트레이너는 published만 읽는다(규칙, 05 §7.9).
- 문서 본문은 회원 노출 문장이다. 게시 전 금지어 회원 세트를 검사해 **경고로만** 보인다. 법률 고지 문장('의료 진단 목적이 아니에요' 같은 부정 문장)이 정상적으로 걸릴 수 있어서다(ASM-08-30). 최종 문구 책임은 법률 자문(G-04)이다.
- 감사: `consentDocument.publish`, `consentDocument.retire`(06 §7.2). `metadata: {consentType}`.
- 게이트: 다섯 유형 모두 published(보유기간 N 확정 포함)가 G-04 증빙이다. Q-24가 정해지지 않으면 `healthData`의 `retention`이 `retentionNotSpecific`로 막힌다. 의도된 동작이다.

**테스트.** `admin_web/test/consent-document.test.mjs`: 이슈 6종 각각, `sharing` 수령자 없음 → `recipientRequired`(AC-PRIV-01.4), 보유기간 '미정' → `retentionNotSpecific`(AC-PRIV-01.3), 정상 문서 → 이슈 0. 에뮬레이터 수동: 게시 뒤 이전 버전 retired, published 수정 409.

### 9.4 AD-04 변화 판정 정책(bodyChange)

| 항목 | 내용 |
|---|---|
| PRD | §8.3 AD-04, §7.3·§7.6, §10.7 정책 kind, §12.4 롤백, G-08, Q-13 |
| 스토리 | DF-221(P1b, S16: kind 검증), DF-384(P3, S27-S29: 운영 화면) |
| 경로 | `/settings/insight-policies`, `POST /api/clinical/config`, `POST /api/clinical/config/activate`(P3, ASM-08-32) |

**P1b(DF-221) 라우트 변경**(dfet:admin_web/app/api/clinical/config/route.ts)

1. `policyKind` enum(:12)에 `'bodyChange'`를 더하고, `superRefine`(:17-21)의 짝 규칙을 `insightPolicyVersions ↔ integrated | bodyChange`로 바꾼다.
2. `validateApprovedConfig`(:27-87)에 bodyChange 분기를 더한다. zod는 06 §7.5 그대로(`bodyChangeMetric`, `bodyChangePolicy`)이며 `lib/domain/body-change-policy.ts`에 둔다.

```ts
// admin_web/lib/domain/body-change-policy.ts
export function validateBodyChange(config: unknown, opts: {
  status: 'draft' | 'approved'; metricCodes: readonly string[];
  mdcSources: readonly string[]; directions: readonly string[];
}): string[] /* 오류 문장 목록, 비면 통과 */;
// draft: metrics 키가 모두 metricCodes 안에 있는지(형식)만
// approved: 06 §7.5 zod 전부 + metrics 1개 이상
//   + mdcSource === 'inHouse'면 mdcReference가 /^(g06:|https:\/\/)/ (ASM-08-33)
```

3. 문서 ID는 기존 규칙 `bodyChange--{version}`(:96), 승인본 수정 거부(:110-112)와 kind별 단일 활성(:113-121)은 그대로 쓴다.
4. `ConfigEditor`(dfet:admin_web/components/config-editor.tsx:10, :33)는 `insightPolicyVersions`일 때도 `policyKind` 선택(`integrated`, `bodyChange`)을 보인다. P1b에는 JSON 입력 그대로다.
5. 트레이너 규칙은 `kind == 'bodyChange' && status == 'approved' && active == true`만 읽는다(R-25). P1b에는 승인본을 만들지 않는다(G-08 전).

**P3(DF-384) 운영 화면**

```
┌ 정책 버전 표(kind 필터): version · status · active · approvedBy · publishedAt · [보기] [활성화](approved만) 
├ 초안 편집기(draft만): 지표별 행
│   metricCode(카탈로그 선택) · mdcValue · mdcSource(literature|inHouse) · mdcReference · protocolVersion
│   · improvementDirection(카탈로그 기본값) · conditionKeys(카탈로그 기본값, 편집 가능)
│   표시: literature면 '문헌값, 자체 재검사 전', inHouse면 '자체 재검사'와 연구 보고서 링크
├ [승인] → status approved(잠금). 승인 주체는 admin(P3부터 center, Q-13)
└ [활성화]/[이 버전으로 롤백] → POST /api/clinical/config/activate
```

- `POST /api/clinical/config/activate {collection: 'insightPolicyVersions', versionId}`: 대상이 approved인지 확인하고, 같은 kind의 다른 활성 문서를 비활성하며 대상 `active: true`. 기존 라우트는 승인본 재저장을 거부하므로(:110-112) 롤백(이전 버전 재활성화, §7.6·§12.4)에 이 경로가 필요하다(C-08-09). 감사 `clinical.config.activate`(`metadata: {policyKind, rollback: bool}`).
- 버전이 바뀌어도 저장된 스냅샷·요약은 다시 계산하지 않는다(§7.6). 화면에 이 사실을 안내한다.
- 상태: '산정 준비 중'(§8.4 AD-04) — 활성 bodyChange 정책이 없으면 표 위에 '활성 정책 없음: 앱은 산정 준비 중으로 표시합니다.'

**테스트.** `admin_web/test/body-change-policy.test.mjs`: 카탈로그 밖 metricCode, `mdcValue <= 0`, 잘못된 mdcSource·direction, 빈 conditionKeys, inHouse 참조 형식, draft는 형식만 검사.

### 9.5 AD-05 지표 카탈로그 조회

| 항목 | 내용 |
|---|---|
| PRD | §8.3 AD-05, 부록 A |
| 스토리 | DF-220(P1b, S15, should) |
| 경로 | `/metric-catalog`(읽기 전용, 라우트 없음) |

| 열 | 출처 |
|---|---|
| metricCode, 한글명, 지표군, 단위, side 규칙 | `METRIC_CATALOG` |
| 허용 sourceGrade | `allowedSourceGrades` |
| 신뢰 등급 | `reliabilityTier`(없으면 '미지정') |
| 가용성 | `availability`(v1, V2) |
| 조건 키 | `conditionKeys` |
| 활성 MDC | 서버에서 `insightPolicyVersions where kind == 'bodyChange' && active == true` 1건을 읽어 `metrics[metricCode]`가 있으면 '±{mdcValue}{unit} · {문헌값, 자체 재검사 전 \| 자체 재검사} · 정책 {version}', 없으면 'MDC 미확보' |

- 상단에 카탈로그 버전(`contracts_version`)과 초안 어휘 목록(`VOCAB_DRAFT_ENUMS`, 부록 A.5~A.7 확정 전이면 '초안')을 보인다.
- 원 기록을 읽지 않으므로 열람 감사는 없다. admin 전용.

### 9.6 AD-06 감사 로그·권리 요청

| 항목 | 내용 |
|---|---|
| PRD | §8.3 AD-06, F-PRIV-05.1·05.2·05.4, F-PRIV-07.1~07.4, AC-PRIV-05.1, AC-PRIV-07.1 |
| 스토리 | DF-136(P1a, S13: 열람 감사, 병합 조회, 내보내기 스크립트), DF-317(P2, S21-S22: 필터·월간 검토·권리 요청 화면) |
| 경로 | `/audit`, `/rights-requests`, `GET·POST /api/admin/rights-requests`(06 §7.3), `POST /api/admin/audit-reviews`(ASM-08-35) |

**P1a(DF-136)**

1. 회원 상세(dfet:admin_web/app/(console)/users/[uid]/page.tsx)
   - 렌더마다 `recordHealthRead(actor, uid, 'users', uid)` 1건(admin·trainer 모두). 실패하면 페이지를 렌더하지 않는다(감사 없는 열람 금지, F-PRIV-05.2).
   - SOAP 건수(:30, :71)를 `soap_notes where memberUid == uid`와 레거시 `where memberId == uid`의 `count()` 합으로 바꾼다(ID 중복 가능성이 있으면 두 쿼리의 문서 ID 합집합 크기). 원문 필드는 계속 보이지 않는다.
   - v1 새 원 기록(체형·신체조성·둘레)의 건수를 추가할 때도 건수만 보인다. 원 기록 내용을 보여 주는 관리자 화면은 v1 범위에 없다. 열람은 권리 요청 내보내기로만 한다(ASM-08-39).
2. 감사 화면(dfet:admin_web/app/(console)/audit/page.tsx:10): §8.5 병합 조회로 바꾼다. 열: 시각(`at ?? createdAt`), 행위자 역할, action, 대상(`targetCollection/targetId` 또는 레거시 `target`), `memberUid`, metadata. 이메일 열은 레거시 문서에만 있고 새 문서에는 없다.
3. 감사 로그 내보내기 스크립트(월간 검토용, F-PRIV-05.4): `functions/scripts/ops/export-audit-logs.js --from 2026-12-01 --to 2026-12-31 --out <로컬 경로>`(소유자 실행, 읽기 전용). CSV 열: `at, action, actorRole, targetCollection, targetId, memberUid, metadata(JSON)`. 행위자 이메일과 건강 수치는 쓰지 않는다(ASM-08-34).
4. 권리 요청 P1a 처리: 트레이너 앱 대리 접수와 관리자 접수는 callable `submitRightsRequest`, 상태 갱신은 소유자 스크립트 `functions/scripts/ops/rights-request.js`(06 ASM-06-29). admin_web 화면은 P2다.

**P2(DF-317) 감사 화면 확장**

- 필터: action(선택 목록 = `AUDIT_ACTIONS`의 action), `memberUid`, 기간(from, to). `memberUid`가 있으면 `where memberUid == m orderBy at desc`(인덱스 05 §10.2), 없으면 §8.5 병합 조회에 기간 조건.
- P2 이벤트(`summaryShared`, `summaryRevoked`, `memberPromoted`, `postureReverted`)를 action 필터에 포함한다.
- 월간 검토 기록: 버튼 '이번 달 검토 완료 기록' → `POST /api/admin/audit-reviews {period: 'YYYY-MM', reviewedCount: int}` → `writeAuditEvent(action: 'auditLogReviewed', targetCollection: 'auditLogs', targetId: period, memberUid: null, metadata: {period, reviewedCount})`. action 이름과 metadata 키는 DF-317 수용 기준 3과 같다([backlog/P2_P3.md](backlog/P2_P3.md) DF-317, ASM-P2P3-22). DF-317 PR에서 `contracts/audit-actions.v1.json`에 `{action: 'auditLogReviewed', phase: 'P2', metadataKeys: ['period', 'reviewedCount']}`를 추가하고 생성물을 갱신한다. 새 컬렉션을 만들지 않는다(ASM-08-35). 자유 메모는 받지 않는다. 화면 상단에 마지막 검토 월(`auditLogs where action == 'auditLogReviewed' orderBy at desc limit 1`)을 보인다.
- `POST /api/admin/audit-reviews`는 06 §7 목록에 아직 없다. 06 §7에 AD-06·DF-317 라우트로 추가하는 것을 06 담당 변경으로 요청한다(ASM-08-35). 요청: admin claim 필수, `period`는 `^\d{4}-(0[1-9]|1[0-2])$`이고 현재 월 이하, `reviewedCount`는 0 이상의 정수. 응답 `{ok: true}`, 오류 `invalid-argument`·`permission-denied`(06 §3 오류 규약).

**P2(DF-317) 권리 요청 화면**(`/rights-requests`)

```
┌ 상태 탭(received · inProgress · completed · rejected), dueAt 오름차순(인덱스 status, dueAt)
├ 행: requestId(mono) · memberUid(mono, /users 링크) · type · channel · receivedAt · dueAt · [기한 초과] 표시
│   조치 버튼(유형·상태별, 아래 표)
└ [대리 접수] memberUid · type 입력 → callAdminFunction('submitRightsRequest', {requestId: uuid, memberUid, type, channel: 'admin'})
```

| 유형 | 조치 | 호출 |
|---|---|---|
| 공통 | 처리 시작 | `POST /api/admin/rights-requests {op: 'setStatus', requestId, status: 'inProgress'}` |
| `access` | 열람 파일 만들기 | 브라우저 `callAdminFunction('exportMemberData', {requestId})` → 응답 `downloadUrl`(24시간 만료)을 화면에 한 번 보인다. 함수가 `completed`로 바꾼다(06 §6.6) |
| `erasure` | 회원 삭제 실행 | 확인창에 memberUid를 다시 입력해야 버튼이 켜진다 → `callAdminFunction('deleteUserData', {uid, rightsRequestId})`(06 §6.5, §6.7) |
| `rectification` | 완료 처리 | 트레이너 addendum(사유 '정보주체 정정 요구', F-PRIV-07.3) 확인 뒤 `setStatus completed` |
| `suspension` | 완료 처리 | ②③ 철회(회원 MB-06 또는 트레이너 TR-14 현장 철회) 확인 뒤 `setStatus completed` |
| 공통 | 처리하지 않음 | `setStatus rejected`(사유 필드 없음, PRD §9.2) |

- 기한 초과: `dueAt < now && status in (received, inProgress)`면 행에 '기한 초과'(빨강 대신 경고 톤 + 글자). 알림은 `alertOverdueObligations`가 따로 보낸다(06 §6.9).
- `setStatus` 라우트는 `status` 전이(`received→inProgress→completed|rejected`, `received→rejected`)만 허용하고, `handledBy`, `completedAt`을 쓰며 감사 `rightsRequestHandled`(`metadata: {type, stage, channel}`)를 남긴다. 스파인 컬렉션 표는 `rightsRequests` 작성자를 Functions만으로 적었으나 06 §7.3을 따른다(C-08-11).
- 권리 요청 화면은 원 기록을 보이지 않으므로 열람 감사 대상이 아니다. 내보내기 함수가 `healthRecordRead(surface: 'adminExport')`를 남긴다(06 §6.6).

### 9.7 AD-07 기능 플래그

| 항목 | 내용 |
|---|---|
| PRD | §8.3 AD-07, §6.0.2, §10.7, §12.3, AC-IA-02 |
| 스토리 | DF-027(P0, S05) |
| 경로 | `/settings/feature-flags`, `POST /api/admin/feature-flags`(06 §7.1) |

**라우트**(dfet:admin_web/app/api/admin/feature-flags/route.ts)

```ts
// admin_web/lib/domain/feature-flags.ts
import { z } from 'zod';
export function buildFeatureFlagsSchema(keys: readonly string[]) {
  return z.object(Object.fromEntries(keys.map((k) => [k, z.boolean()]))).strict();   // 8키 모두 필수, 여분 키 거부
}
export function readFlags(keys: readonly string[], data: Record<string, unknown> | undefined): Record<string, boolean> {
  return Object.fromEntries(keys.map((k) => [k, data?.[k] === true]));               // 없으면 false(ADR-010)
}

// route.ts (:10 교체)
const schema = buildFeatureFlagsSchema(FEATURE_FLAG_KEYS);
// :20-24 그대로 set()(8키 필수이므로 다른 키가 지워지지 않는다) + updatedAt, updatedBy
// :25 감사: 'app.feature_flags.update', metadata = 8키 불리언(06 §7.1)
```

**배포 순서**(05 §4.17): ① 운영 `appConfig/features`에 8키를 `false`로 시드(소유자, 기존 3키 값 유지) → ② 라우트·화면 배포 → ③ 회원 앱·트레이너 앱 파서 배포. ①을 건너뛰면 ②까지는 안전하지만(8키 필수) 저장 전 화면 초기값이 문서와 다를 수 있다.

**화면**(dfet:admin_web/app/(console)/settings/feature-flags/page.tsx:9-18, dfet:admin_web/components/feature-flag-editor.tsx)

```
┌ 기존 임상: gut · blood · insights   (설명 문구 기존 유지)
├ v1 신규(기본 false):
│   soapV2           P1a 진입 · 전제 G-04, G-09, G-05a 제출, MIG-03 적용, G-03
│   bodyComposition  P1a 진입 · 전제 같음
│   bodyAssessment   P1b 진입 · P1a 종료 뒤
│   memberShare      P2 진입 · 전제 G-05b, MB-05·MB-06 배포
│   lidarBeta        P2 내부 트레이너 · 전제 G-07a. P3 진입 시 false로 되돌림
├ 경고: 끄면 새 기록 생성만 막히고 기존 기록 열람은 유지돼요. v1 SOAP 쓰기 차단은 플래그와 무관해요.
├ [저장] — 새 5키 중 false→true로 바뀌는 키가 있으면 확인창에 그 키의 전제 게이트를 나열
└ 변경 이력: auditLogs where action == 'app.feature_flags.update' limit 20(메모리 정렬, 복합 인덱스 불필요)
```

- 전제 게이트 문구는 `admin_web/lib/domain/feature-flags.ts`의 `FLAG_GATE_HINTS`(PRD §12.3 순서)에 둔다. 서버는 게이트 충족을 검사하지 않는다(게이트 증빙은 소유자 책임, EP-00).
- `lidarBeta`를 P3 진입 때 false로 되돌리는 것은 DF-389 소유자 행동이다.

**테스트.** `admin_web/test/feature-flags.test.mjs`: 7키 → 오류, 9키(여분) → 오류, 8키 → 통과, `readFlags(undefined)` 모두 false. 연계: 같은 8키 문서를 Dart `AppFeatureFlags.fromMap`과 Swift 파서가 같은 값으로 읽는다(DF-027 AC, `contracts/fixtures`의 플래그 픽스처 공유).

---

## 10 테스트 계획

전체 전략은 [10_TEST_PLAN.md](10_TEST_PLAN.md)와 ADR-013을 따른다. 모든 데이터는 합성이다.

### 10.1 회원 앱(Flutter, CI job `flutter`)

| 파일 | 대상 | 확인 | 스토리 |
|---|---|---|---|
| `test/clinical_reports_test.dart`[수정] | `AppFeatureFlags` | 8키 `fromMap`, null·키 누락 false, `showsBodyReport` 진리표 | DF-027 |
| `test/soap_note_v2_codec_test.dart` | `SoapNoteV2Codec` | `contracts/fixtures/soap_v2`·`soap_legacy` 왕복(06 §9.3) | DF-007 |
| `test/widgets/source_grade_chip_test.dart` | 출처 칩 | 10등급 라벨·shrink | DF-131 |
| `test/widgets/series_trend_chart_test.dart` | 추이 차트 | §5.4 규칙 전부 + 골든(라이트·다크·회색조) | DF-131 |
| `test/d_fet_evidence_test.dart`[수정] | 헤더·리본 | `mark: none` 4축 아이콘 0개, 리본 `title` 매개변수, 기존 기본값 불변 | DF-316 |
| `test/member/member_summary_model_test.dart` | 모델 | `contracts/fixtures/summaries/{shared_body_report,soap_note_summary,revoked,body_report_with_hidden,malformed_highlight}.json` 파싱, 잘못된 highlight 건너뜀, 로그에 수치 없음 | DF-315·DF-316 |
| `test/widgets/change_statement_test.dart` | 변화 문장 | §5.5 표 13행, `needsPendingFootnote` 3경우 | DF-316 |
| `test/member/report_hub_body_segment_test.dart` | MB-01 진입 | 플래그 조합 4가지 × 세그먼트 유무, `insights` 세그먼트·레이더 축 4개 불변 | DF-316, DF-331 |
| `test/member/body_report_screen_test.dart` | MB-01 | §4.1 상태 6종, 숨김 highlight 미표시(AC-VIZ-06.6), 오류가 빈 상태로 보이지 않음 | DF-316 |
| `test/member/body_report_detail_screen_test.dart` | MB-02 | 해제·없음·잘못된 sourceType, 사진 경로 0 → 영역 없음(AC-VIZ-06.4), ③ 없음 문구, 추이 점 구성(refId 중복 제거, seriesKey 분리) | DF-316 |
| `test/member/trainer_records_screen_test.dart` | MB-03 | 필터, revoked 미표시, '새 기록' 규칙, permission-denied → 불러오기 실패 | DF-315 |
| `test/member/profile_rows_test.dart` | 내 정보 | 'SOAP 노트' 문구 0건(AC-IA-04), 플래그별 행 유무(AC-IA-02), 행 색이 `AppColors.success`가 아님 | DF-029, DF-315 |
| `test/member/app_router_member_routes_test.dart` | 라우트 | 플래그 off redirect, 해제 요약 경로 열기(AC-VIZ-06.2) | DF-331 |
| `test/member/invite_code_screen_test.dart` | MB-05 | 버튼 활성 조건, messageKey별 문구, 성공 이동, `aborted` 자동 1회 재시도, 분석 이벤트 속성 | DF-306 |
| `test/member/consent_center_screen_test.dart` | MB-06 | 한 번에 한 유형, ① 철회 → 탈퇴 안내(callable 미호출), ⑤ 동의 버튼 없음, 개정 배너, clientCaptureId 재시도 재사용 | DF-307 |
| `test/member/in_person_reconfirm_test.dart` | 재확인 | 대상 계산 3경우, 기한 계산 | DF-308 |
| `test/member/rights_request_screen_test.dart` | 권리 요청 | 제출·중복 비활성·상태 문구 | DF-307 |
| `test/member/member_goldens_test.dart` → `test/goldens/member/*.png` | MB-01~06 | §8.4 매트릭스 O칸(AC-IA-01), 라이트·다크, textScale 1.0·2.0(AC-A11Y-02), 회색조(AC-A11Y-03, AC-VIZ-07.5) | 각 화면 스토리 |
| 같은 파일 | 접근성 | `meetsGuideline(textContrastGuideline)`, `iOSTapTargetGuideline`, 수치 `Semantics` 라벨에 출처·변화 문장 또는 기준 준비 문장 포함(AC-A11Y-01) | 각 화면 스토리 |

- 저장소는 테스트에서 provider override로 가짜 구현(`implements MemberSummaryRepository`)을 넣는다. 새 dev 의존성(가짜 Firestore 패키지)을 추가하지 않는다.
- 규칙 증명(회원 쿼리 R-11·R-12, 원 기록 거부 R-10)은 에뮬레이터 규칙 테스트(DF-022)가 정본이다. 회원 앱 쪽에서는 쿼리 모양(필드·연산자·정렬)이 06 §10 표와 같은지 저장소 단위 테스트로 고정한다.
- 골든 회색조: `ColorFiltered(colorFilter: ColorFilter.matrix(<luminance 행렬>))`로 감싸 렌더한다.

### 10.2 관리자 웹(CI job `admin-web`: lint, typecheck, test, build)

| 파일 | 대상 | 스토리 |
|---|---|---|
| `admin_web/test/feature-flags.test.mjs` | §9.7 | DF-027 |
| `admin_web/test/assignment.test.mjs` | §9.1 | DF-025 |
| `admin_web/test/consent-document.test.mjs` | §9.3 | DF-032 |
| `admin_web/test/audit-normalize.test.mjs` | 병합·정규화: 레거시만, 새 문서만, 두 필드 모두 가진 문서 중복 제거, 정렬 | DF-136 |
| `admin_web/test/body-change-policy.test.mjs` | §9.4 | DF-221 |
| `admin_web/test/audit-actions.test.mjs` | `writeAuditEvent`의 action 검사·metadata 화이트리스트(순수 부분을 `lib/domain/audit-normalize.ts`로 분리) | DF-136 |

- 실행: `npm test --prefix admin_web`(dfet:admin_web/package.json:14). `.ts` 모듈을 `.test.mjs`에서 직접 import하므로 Node 22.18 이상(형 제거 기본 활성)이 필요하다(ASM-08-18). CI의 `setup-node`는 `22.x` 최신을 쓴다.
- 라우트·페이지 통합은 에뮬레이터 수동 체크리스트(각 스토리 PR 증빙)로 확인한다: 403(비관리자), 400(검증), 409(상태 전이), 감사 문서 1건.

### 10.3 단계 게이트와의 연결

| 게이트·단계 종료 | 이 문서 산출물 증빙 |
|---|---|
| P0 종료(DF-926) | AD-07 8키 저장·Dart 파서 일치, 회원 앱 문구 4개 파일 린트 통과, 'SOAP 노트' 행 제거 |
| G-04 증빙(DF-908) | AD-03에서 5종 published(보유기간·④ 수령자 포함) |
| P1a 종료(DF-927) | `healthRecordRead` 기록(AC-PRIV-05.1), 병합 감사 화면 |
| P2 진입·종료(DF-934, DF-936) | MB-05·MB-06 배포, MB-01~04 골든·상태 매트릭스, AC-VIZ-06.1~06.6, AC-SOAP-05.6·05.7 |
| G-08(DF-920) | AD-04 승인본·활성화 기록 |

---

## 11 스토리·파일 대응표

| 스토리 | 이 문서 절 | 주요 파일 | 단계·스프린트 |
|---|---|---|---|
| DF-007 | §3.1 | `lib/models/soap_note_v2.dart`, `test/soap_note_v2_codec_test.dart` | P0 S02 |
| DF-025(AD-01) | §9.1 | `admin_web/app/api/admin/{assignments,roles}/route.ts`, `components/{assignment-editor,role-editor}.tsx`, `lib/domain/assignment.ts` | P0 S05 |
| DF-027 | §3.5, §9.7 | `lib/services/clinical_repository.dart`, `lib/contracts/generated/feature_flag_keys.dart`, `admin_web/app/api/admin/feature-flags/route.ts`, `components/feature-flag-editor.tsx`, `lib/domain/feature-flags.ts` | P0 S05 |
| DF-028 | §7.2(목록) | `ios/Runner/AppDelegate.swift`(동결 예외) | P0 S04 |
| DF-029 | §6.2, §7.1 | `lib/screens/{guide_screen,onboarding_screen,profile_setup_screen,create_request_screen,ios_profile_screen,my_info_screen}.dart`, `lib/models/user_profile.dart`(`displayGoal`), `lib/copy/member_copy.dart`(골격) | P0 S04 |
| DF-032 | §9.3 | `admin_web/app/(console)/consent-documents/page.tsx`, `components/consent-document-editor.tsx`, `app/api/admin/consent-documents/route.ts`, `lib/domain/consent-document.ts` | P0 키, S06 |
| DF-101 | §8.2 | `admin_web/lib/auth.ts` | P1a S09 |
| DF-131 | §5.3, §5.4 | `lib/widgets/clinical/{source_grade_chip,series_trend_chart}.dart` | P1a S12 |
| DF-135 | §9.6(P1a 연계) | (Functions 쪽. admin_web 변경 없음) | P1a S13 |
| DF-136 | §8.5, §9.6 | `admin_web/lib/audit.ts`, `lib/domain/audit-normalize.ts`, `app/(console)/users/[uid]/page.tsx`, `app/(console)/audit/page.tsx`, `functions/scripts/ops/export-audit-logs.js` | P1a S13 |
| DF-220 | §9.5 | `admin_web/app/(console)/metric-catalog/page.tsx` | P1b S15 |
| DF-221 | §9.4 | `admin_web/app/api/clinical/config/route.ts`, `components/config-editor.tsx`, `lib/domain/body-change-policy.ts` | P1b S16 |
| DF-306 | §4.5, §3.10 | `lib/screens/invite_code_screen.dart`, `lib/services/{invite_repository,dfet_functions_exception,member_analytics}.dart`, `lib/state/consent_state.dart`, `lib/models/user_profile.dart`, `lib/screens/dashboard.dart`(안내 카드) | P2 S19-S20 |
| DF-307 | §4.6 | `lib/screens/consent/*`, `lib/services/{consent_repository,rights_request_repository}.dart`, `lib/models/{consent,rights_request}.dart` | P2 S21-S22 |
| DF-308 | §4.6(재확인) | `lib/screens/consent/in_person_reconfirm_section.dart` | P2 S21-S22 |
| DF-315 | §4.3, §4.4, §6 | `lib/screens/trainer_records/*`, `lib/services/member_summary_repository.dart`, `lib/state/member_summary_state.dart`, `lib/models/member_summary.dart`, `lib/state/soap_note_state.dart`, `lib/services/firestore_service.dart`, `lib/screens/member_soap_notes_screen.dart`[삭제], `tool/lint/static-guards.sh` | P2 S21-S22 |
| DF-316 | §4.1, §4.2, §5.1, §5.2, §5.5, §5.6 | `lib/screens/body_report/*`, `lib/widgets/clinical/change_statement.dart`, `lib/design_system/d_fet_evidence.dart`, `lib/screens/report_hub_screen.dart` | P2 S21-S22 |
| DF-317 | §9.6(P2) | `admin_web/app/(console)/{audit,rights-requests}/page.tsx`, `components/rights-request-actions.tsx`, `app/api/admin/{rights-requests,audit-reviews}/route.ts`, `lib/firebase-client.ts` | P2 S21-S22 |
| DF-318 | §9.2 | `admin_web/app/(console)/pending-members/page.tsx`, `app/api/admin/pending-members/route.ts` | P2 S25-S26 |
| DF-331 | §3.5, §3.6, §3.7 | `lib/router/app_router.dart`, 회원 화면 오류 표시 | P2 S21-S22 |
| DF-383 | §5.4(밴드), §5.5(글리프) | `lib/widgets/clinical/{series_trend_chart,change_statement}.dart`, `lib/widgets/clinical/{range_bar,comparison_card}.dart`(개조) | P3 S27-S29 |
| DF-384 | §9.4(P3) | `admin_web/app/(console)/settings/insight-policies/page.tsx`, `app/api/clinical/config/activate/route.ts` | P3 S27-S29 |
| DF-385 | §8.2 | `admin_web/lib/auth.ts`, `components/console-shell.tsx` | P3 S30-S32 |
| DF-387 | §7.3, §6.4 | 회원 앱 트레이너 셸 제거, `trainer.movedToNewApp` 안내, static guard 범위 확대 | P3 S30-S32 |
| DF-389 | §9.7 | (소유자 행동, AD-07 사용) | P3 S30-S32 |

---

## 12 가정(ASM-08-NN)·충돌·열린 질문

ID는 이 문서 한정이다. PRD로 올릴 때는 PRD §13.4에 따라 AS-34, Q-25 이후 번호를 새로 받는다.

### 12.1 가정

| ID | 가정 | PRD·근거 | 확인 시점 |
|---|---|---|---|
| ASM-08-01 | P0 문구 릴리스(DF-029)에서 내 정보 'SOAP 노트' 행을 지운다. DF-029 범위를 약간 넓힌다(0점 추가) | AC-IA-04, §10.5, §2.3 결함 | S04 계획(소유자 수락) |
| ASM-08-02 | `dfet:` 줄 번호는 2026-09-24 작업 트리 기준이다. MIG-01 뒤 달라질 수 있다 | PRD §0.2, §11.2 | 각 스토리 착수 시 재확인 |
| ASM-08-03 | 06의 `watchSummaries`를 두고 `watchSummaryFeed`·`watchStateFeed`(isFromCache 포함)를 더한다 | §8.4 오프라인 표시 | DF-315 착수 전 06 반영 |
| ASM-08-04 | 06 `getSummary`(Future)에 더해 `watchSummary(id)`(Stream)를 둔다. 해제가 열린 화면에 즉시 반영되게 하기 위해서다 | AC-SOAP-05.7, AC-PRIV-02.2 | 06 반영 |
| ASM-08-05 | 회원 문구는 ARB가 아니라 `lib/copy/member_copy.dart` 상수로 모은다(ARB 기반이 없음) | ADR-016, 부록 C.3 | DF-029 |
| ASM-08-06 | 회원 앱 분석은 인터페이스와 디버그 싱크만 둔다. 전송 SDK는 G-09 뒤 결정 | ADR-015, AS-DEV-07, G-09 | Q-DEV-08-01 |
| ASM-08-07 | `memberSummaries.sharedByDisplayName`(공유 시점 트레이너 표시명 스냅샷, 서버 작성)을 둔다. 회원은 트레이너 문서를 읽을 수 없다 | §8.2 MB-03 '트레이너 표시명', §9.2 | DF-309 전에 05·06 반영 |
| ASM-08-08 | 회원 요약 피드 100건, 동의 이력 50건 상한(페이지네이션 없음) | §9.6 페이지네이션 원칙 | P2 종료 검토에서 건수 확인 |
| ASM-08-09 | `rightsRequests` 회원 쿼리는 `orderBy` 없이 받아 클라이언트에서 정렬한다(인덱스 추가 회피) | 05 §10.2 | DF-307 |
| ASM-08-10 | `AppFeatureFlags.enabled()`는 기존 3키만 true, 새 5키 false | D4, 데모 데이터 없음 | DF-027 |
| ASM-08-11 | 딥링크 패키지가 없으므로 해제 요약 열기는 go_router 경로로 확인한다 | AC-VIZ-06.2 | DF-315 |
| ASM-08-12 | 카탈로그에 회원용 이름 `memberLabelKo`를 더한다. 결정 전 §3.9 표를 쓴다 | 부록 B.8(CVA → 머리·목 정렬 각도) | DF-003 개정 또는 DF-316 |
| ASM-08-13 | 체형·신체조성 세그먼트는 careType과 무관하게 보인다 | F-VIZ-06.8(조건에 careType 없음) | DF-316 |
| ASM-08-14 | `comparedTo`는 차트 점으로 쓰지 않고 행 문구로만 보인다. 사진이 2장이면 [이전, 이번] 순서로 본다 | F-VIZ-06.5·06.6, Q-19 | DF-313과 순서 합의 |
| ASM-08-15 | 초대 안내 카드는 대시보드 두 모드 공통 상단에 둔다 | §8.2 '가입 직후 안내 카드' | DF-306(dashboard.dart는 MIG-01 분류 뒤) |
| ASM-08-16 | ⑤ 연구 동의는 회원 앱에서 '동의하기'를 제공하지 않고 철회만 제공한다(IRB 연구참여 동의서 절차 필요) | F-PRIV-01 ⑤, G-06 | G-04·IRB 협의 |
| ASM-08-17 | 현장 동의 재확인 기한 = 이 기기에서 처음 본 날 + 30일(로컬 기록). 기한이 지나도 자동 조치 없음 | F-PRIV-03.8 '30일(제안값)' | Q-DEV-08-02 |
| ASM-08-18 | admin_web 순수 검증 모듈은 `.ts`로 두고 Node 22.18+ 형 제거로 `.test.mjs`에서 직접 import한다. 경로 별칭·생성물 import 없이 인자로 받는다 | dfet:admin_web/package.json:14, ADR-017(새 의존성 금지) | DF-027 첫 적용 |
| ASM-08-19 | 신체조성·둘레의 `conditionMismatch`·`protocolChanged` 회원 문장은 '측정 조건이 달라요'로 쓴다(B.8은 '촬영 조건이 달라요'만 있음) | 부록 B.8, F-VIZ-06.3 | PRD B.8 보완(P3 전) |
| ASM-08-20 | AC-VIZ-06.1 grep 범위는 MIG-09 전까지 회원 경로 목록(§6.4)이다 | AC-VIZ-06.1, MIG-09 | DF-315, DF-387 |
| ASM-08-21 | guide_screen.dart:48-50(없는 기능 안내)도 DF-029에서 고친다(should) | §2.4, 금지어는 아님 | S04 |
| ASM-08-22 | 홈 운동은 별도 필드가 없으므로 서버 템플릿이 `nextPlan`·`body`에 넣은 문장을 그대로 보인다 | F-SOAP-05.3, §9.2 | DF-309 템플릿 |
| ASM-08-23 | 같은 유형의 열린 권리 요청이 있으면 새 요청 버튼을 비활성한다 | F-PRIV-07.1 | DF-307 |
| ASM-08-24 | Runner 프로그램명 '통증 관리'는 금지어 표에 없어 그대로 두되 소유자가 검토한다 | 부록 C.1('통증 완화' 등) | DF-028 PR |
| ASM-08-25 | P3 관리자 역할 분리는 claim `adminScope: 'operator' \| 'center'`(admin: true 유지)로 한다 | §6.7.0, §8.3, ADR-018 | DF-385 착수 전 ADR-018 개정 |
| ASM-08-26 | `admin_web/lib/generated/contracts.ts`의 export 이름은 §8.6과 같다 | ADR-005 | DF-004 emitter |
| ASM-08-27 | 트레이너 역할 해제 시 담당 회원이 남아 있으면 확인을 한 번 더 받는다(`confirmUnassigned`) | F-LINK-03, AD-01 | DF-025 |
| ASM-08-28 | AD-02에 `POST /api/admin/pending-members`(`cancel`, `revokeInvite`)를 더하고, 목록 열람 감사는 렌더당 1건으로 한다 | §8.3 AD-02 '만료·취소', 06 §7.4 | DF-318 전 06 반영 |
| ASM-08-29 | `pendingMembers.lastRedeemFailure {reason, uid, at}`(서버 전용)를 redeem 실패(conflict 등) 때 쓴다 | §8.3 AD-02 '실패 사유' | DF-305 전 05·06 반영 |
| ASM-08-30 | 동의 문서 금지어 검사는 게시를 막지 않고 경고만 한다 | 부록 C.3, G-04 | DF-032 |
| ASM-08-31 | '구체적 보유기간' 검사 = 숫자 + 일·개월·년 포함 | F-PRIV-01.2, Q-24 | DF-032, G-04 |
| ASM-08-32 | 승인본 재활성화(롤백)용 `POST /api/clinical/config/activate`를 둔다 | §7.6, §12.4 | DF-384 |
| ASM-08-33 | inHouse `mdcReference`는 `g06:` 식별자 또는 `https://` 링크 | §10.7 'inHouse면 연구 보고서 참조' | DF-221·DF-384 |
| ASM-08-34 | 감사 로그 내보내기는 `functions/scripts/ops/export-audit-logs.js`(읽기 전용, 소유자 실행) | F-PRIV-05.4 | DF-136 |
| ASM-08-35 | 월간 검토 기록은 새 컬렉션 없이 auditLogs action `auditLogReviewed`(metadata `{period, reviewedCount}`)로 남긴다. P2_P3 ASM-P2P3-22와 같은 이름이며 라우트 `POST /api/admin/audit-reviews`는 06 §7에 추가 요청 | F-PRIV-05.4 '검토 기록' | DF-317, DF-033 등록 |
| ASM-08-36 | 감사 목록은 `at`·`createdAt` 두 쿼리를 병합한다 | §9.2 auditLogs(`createdAt`을 `at`으로 간주) | DF-136 |
| ASM-08-37 | 동의 문서 게시 시 같은 유형의 이전 published를 retired로 바꾼다. retired 문서에 대한 기존 동의는 유효하다 | F-PRIV-01.3, 06 §7.2 | DF-032 |
| ASM-08-38 | 관리자 callable은 브라우저 세션(`clientAuth.currentUser`)이 있을 때만 부른다. 없으면 재로그인 안내 | 06 §7.3 | DF-317 |
| ASM-08-39 | v1 admin_web은 원 기록 내용을 화면에 보이지 않는다(건수만). 원문 확인은 권리 요청 내보내기로 한다 | F-PRIV-05.2, §6.7.0 | DF-136 |
| ASM-08-40 | `recordConsent`(재확인 포함) 멱등 키는 `clientCaptureId`, 동의 문서 ID는 `{consentType}--{version}`(R5). 회원 앱은 문서 ID를 불투명 문자열로 다룬다 | V1-05 §4.13·ASM-05-15, V1-06 §3.7 | DF-307, DF-032 |

### 12.2 충돌

| ID | 내용 | 처리 |
|---|---|---|
| C-08-01 | 회원 세트 금지어가 MIG-04 목록 밖의 기존 회원 문자열에 있다: dfet:lib/design_system/d_fet_evidence.dart:337('판정'), dfet:lib/screens/microbiome/microbiome_screen.dart:114('판정'), :115·:209('진단' 부정 문장), dfet:lib/screens/blood/blood_screen.dart:65·dfet:lib/screens/blood/blood_report_screen.dart:139-144('정상범위', '판정', '진단'), dfet:lib/screens/insights/insights_screen.dart:81('진단'), dfet:lib/screens/posture_result_screen.dart:331('개선 팁 보기'), dfet:lib/screens/dashboard.dart:639('개선'), dfet:lib/services/video_pose_analyzer.dart:438-441('개선', '교정'). copy-lint 차단 모드(DF-040, P0 종료)가 이 파일들에서 실패한다 | 이 문서는 새 회원 화면과 MIG-04 4개 파일만 다룬다. DF-040 착수 전에 ① DF-029에 포함 ② `allowPaths`에 넣고 정리 티켓 ③ 부정 고지 문장 예외 규칙 중 하나를 정해야 한다(Q-DEV-08-04, 12_COPY_ANALYTICS_AND_LINT 담당) |
| C-08-02 | AC-VIZ-06.1 '회원 앱 코드 원 기록 경로 0건'과, MIG-09(P3)까지 `lib/`에 남는 동결 트레이너 코드 | ASM-08-20 |
| C-08-03 | 카탈로그 `nameKo`에 약어(CVA 등)가 있어 회원 문장 규칙(B.8)과 맞지 않는다 | ASM-08-12 |
| C-08-04 | MB-03 '트레이너 표시명'을 위한 필드가 `memberSummaries`에 없다 | ASM-08-07 |
| C-08-05 | PRD는 `DfetReportHeader(axis 없음)`로 체형 리포트를 그리라고 하나, 현행 코드는 axis null이면 4축 표식을 그린다(F-VIZ-06.7 위반) | §5.1 `mark` 매개변수 |
| C-08-06 | `consentDocumentVersions` 문서 ID 형식: 05 §4.13 `{consentType}--{version}` 대 06 §7.2 `{consentType}_{version}` | admin_web은 05(데이터 모델 정본)를 따른다. 회원 앱은 불투명 문자열로 다뤄 영향 없음. 05·06 담당이 하나로 맞춘다 → 해소(정합 패스 2): 06 §7.2·P0 DF-032가 `{consentType}--{version}`으로 통일 |
| C-08-07 | `healthRecordRead.metadata.surface` 값: 05 §11.5(`adminWeb`\|`TR-03`) 대 06 §3.9(`TR-03`\|`adminMemberDetail`\|`adminExport`) | 06을 따른다. 05 표 수정 필요 |
| C-08-08 | 기존 감사 화면은 `createdAt`만 정렬해 `at`만 가진 새 이벤트가 보이지 않는다 | ASM-08-36 |
| C-08-09 | 정책 롤백(이전 승인본 재활성화, §7.6·§12.4)을 기존 설정 라우트로 할 수 없다(dfet:admin_web/app/api/clinical/config/route.ts:110-112) | ASM-08-32 |
| C-08-10 | 부록 B.8에 신체조성 조건 불일치 회원 문장이 없다 | ASM-08-19 |
| C-08-11 | 스파인 컬렉션 표는 `rightsRequests` 작성자를 Functions만으로 적었으나 06 §7.3은 admin_web 라우트가 상태를 바꾼다 | 06을 따른다. 스파인·05 작성자 칸에 'admin_web 서버(상태 갱신)' 추가 |
| C-08-12 | AD-02 '실패 사유'를 담을 필드가 PRD §9.2에 없다 | ASM-08-29 |
| C-08-13 | M-06 열람 서버 기록 수단이 PRD·스파인에 없다(06 CF-06-08과 같은 문제) | 06 ASM-06-04·Q-DEV-04를 따른다. 승인되면 MB-02·MB-04가 `markViewed` 호출 |
| C-08-14 | 월간 감사 검토 action 이름이 문서마다 달랐다(이전 08은 `auditReview.monthly`, P2_P3 DF-317·DF-388은 `auditLogReviewed`). 라우트 `POST /api/admin/audit-reviews`는 06 §7 목록에 없다 | `auditLogReviewed`(metadata `{period, reviewedCount}`)로 통일(§9.6, ASM-08-35). 06 §7에 AD-06·DF-317 라우트 추가를 06 담당에 요청한다 → 06 §7.8에 라우트 추가(정합 패스 2) |

### 12.3 개발 열린 질문

| ID | 질문 | 결정 전 기본값 | 기한 |
|---|---|---|---|
| Q-DEV-08-01 | 회원 앱 분석 전송 SDK(`firebase_analytics`, 새 의존성)를 G-09 뒤 도입하는가 | 도입하지 않음, 디버그 싱크만 | P2 진입 |
| Q-DEV-08-02 | 현장 동의 재확인 기한(30일)이 지나면 무엇을 하는가(트레이너 알림, 해당 유형 일시 중지 등) | 아무것도 하지 않고 목록 유지 | G-04 |
| Q-DEV-08-03 | 열람 요청 결과 파일을 회원에게 어떻게 전달하는가(이메일, 앱 내 링크, 센터 방문) | 관리자가 만료 링크를 별도 경로로 전달 | G-04 |
| Q-DEV-08-04 | 기존 회원 화면의 금지어(C-08-01)를 언제·어느 스토리에서 정리하는가 | DF-040 착수 전 소유자 결정 | S04 |
| Q-DEV-08-05 | P3 관리자 역할 분리 claim 모양(ASM-08-25)과 운영자의 원 기록 접근 범위 | `adminScope` 제안 | P3 진입(Q-21 결과 반영) |

관련 PRD 열린 질문: Q-04(④ 범위), Q-05(대기 회원 민감정보), Q-07(동의 증빙 보존), Q-13(정책 승인 주체), Q-19(시계열 필드), Q-20(플래그 대상 지정), Q-21(처리 주체), Q-24(보유기간).

---

## 13 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | - | 없음 |
| v1.0(검토 반영) | 2026-09-24 | 월간 감사 검토 action `auditLogReviewed` 통일(C-08-14), §7.2 DF-028 `main` 줄 번호 열 | - | 없음 |
| v1.0(정합 패스 2) | 2026-09-24 | recordConsent clientCaptureId, 동의 문서 ID, main :613 행, 06·P2_P3 가정·충돌 ID 참조 갱신(R5, R10) | - | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: R5(`clientCaptureId`, `{consentType}--{version}`, ASM-08-40), R10(06·P2_P3 가정·충돌 ID 네임스페이스), C-08-06·C-08-14 해소 표시, DF-028 `main` :613 행 | - | 없음 |

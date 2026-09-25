# 개발 환경·AI 에이전트 플레이북

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-13 |
| 버전 | v1.1.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | [PRD_V1](../PRD_V1.md) §10.2(트레이너 앱 구조), §10.2.4(G-02 구성), §12.5(테스트 전략), §13.4(가정·질문 번호), NFR-02, NFR-03, NFR-11 |
| 관련 에픽·스토리 | EP-01 / DF-001(에이전트 진입 문서), DF-002(백로그 도구), DF-008(trainer_app 골격), DF-034(plist 주입), DF-107(에뮬레이터 통합), DF-903·DF-905(소유자 준비) |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [1. 이 문서의 역할](#1-이-문서의-역할)
- [2. 도구와 버전](#2-도구와-버전)
- [3. 로컬 준비](#3-로컬-준비)
- [4. 명령 모음](#4-명령-모음)
- [5. AI 에이전트 진입 문서](#5-ai-에이전트-진입-문서)
- [6. 컨텍스트 팩(영역별 필독)](#6-컨텍스트-팩영역별-필독)
- [7. 금지 행동과 비밀·실데이터 규칙](#7-금지-행동과-비밀실데이터-규칙)
- [8. 병렬 배정과 PR 증빙](#8-병렬-배정과-pr-증빙)
- [9. 흔한 실패와 대응](#9-흔한-실패와-대응)
- [10. 가정(ASM-13-NN)](#10-가정asm-13-nn)
- [11. 변경 이력](#11-변경-이력)

## 1. 이 문서의 역할

- 개발자(소유자)와 AI 코딩 에이전트(Claude, Codex)가 **같은 명령으로** 빌드·테스트하도록 환경과 명령을 모은다.
- 에이전트 작업 흐름, 권한 경계, 작업 지시서 규칙의 정본은 [01 AI 에이전트 작업 흐름](01_AGILE_WORKING_AGREEMENT.md#ai-에이전트-작업-흐름)과 [01 에이전트 권한 경계](01_AGILE_WORKING_AGREEMENT.md#에이전트-권한-경계)다. 이 문서는 그 규칙을 실행하는 데 필요한 **환경·명령·필독 목록**만 더한다.
- 테스트 층과 케이스의 정본은 [V1-10](10_TEST_PLAN.md), CI job 정의는 [V1-10 §19](10_TEST_PLAN.md#19-ci-워크플로)다. 여기의 명령은 그 요약이다.
- 아직 없는 파일(생성기, 시드 스크립트, 린트 도구)은 담당 스토리 키를 함께 적었다. 해당 스토리가 병합되기 전에는 명령이 동작하지 않는다.

## 2. 도구와 버전

| 도구 | 버전 | 쓰는 곳 | 근거 |
|---|---|---|---|
| Xcode | 16.x | trainer_app, BodyPath(P2) | AS-DEV-06 |
| GitHub 러너(트레이너 앱) | macos-15 | trainer-app, trainer-app-emulator-it | AS-DEV-06, [V1-10 §19.4](10_TEST_PLAN.md#194-trainer-appyml-초안df-008-df-107) |
| Swift | 5 언어 모드. 순수 타깃은 `SWIFT_STRICT_CONCURRENCY=complete` | `trainer_app/Packages/TrainerCore`(순수, iOS 17 + macOS 14), `TrainerKit`(iOS 전용) | [V1-04 §6.2](04_ARCHITECTURE.md#62-패키지-두-개로-나누는-이유), ADR-001 |
| XcodeGen | 2.44.1로 고정(CI는 릴리스 zip을 SHA-256으로 확인해 설치) | `trainer_app/project.yml` | [SPRINT_01 ASM-S01-09](sprints/SPRINT_01.md#13-가정asm), 기존 사용 근거 dfet:trainer_ios/project.yml:1-3, dfet:trainer_ios/README.md:18 |
| iOS 배포 대상 | trainer_app 17.0(ADR-001), 회원 앱 Runner 15.5 | — | ADR-001, NFR-01 |
| Node | 22 | functions, admin_web, contracts·lint·backlog 도구 | dfet:.github/workflows/ci.yml:39-41, dfet:functions/package.json `engines.node`, dfet:admin_web/package.json `engines.node` |
| Java | 21(Firestore·Storage 에뮬레이터 job), 17(flutter job) | 에뮬레이터 | dfet:.github/workflows/ci.yml:44-47, :17-20 |
| firebase-tools | 최신 전역 설치(CI가 버전 고정 없이 설치). **15.x 이상 필수**: 14.x 에뮬레이터는 firebase-functions v7에서 제거된 `functions.config()`를 호출해 functions 로드가 실패한다(2026-09-25 MIG-01 검증에서 14.17.0 실패, 15.31.0 통과) | 에뮬레이터 | dfet:.github/workflows/ci.yml:52, [ASM-13-01](#10-가정asm-13-nn) |
| Flutter | **3.38.2 고정**(CI `flutter-version: 3.38.2`). 로컬도 같은 버전을 쓴다(`flutter downgrade`/`flutter upgrade`로 맞춤). 3.47 stable에서는 위젯 테스트 실패·deprecation·FlutterFire SPM 충돌이 있어 전환은 별도 작업([V1-00 K-16](00_README.md#알려진-차이와-남은-일)). iOS는 CocoaPods 빌드(`pubspec.yaml`의 `enable-swift-package-manager: false`) | 회원 앱 | dfet:.github/workflows/ci.yml(flutter·ios-no-codesign job) |
| jq | 1.6 이상 | `schemas/*.json` 검사, 백로그 스크립트 | dfet:.github/workflows/ci.yml:51 |
| gh | 최신. 소유자만 `--apply`에 사용 | 백로그 생성 | [TL-01](../../tool/backlog/README.md) |
| shellcheck | 있으면 사용 | `tool/**/*.sh` | P0 DF-002 카드 |

에뮬레이터 포트와 프로젝트 ID는 [V1-10 §4.2](10_TEST_PLAN.md#42-firebase-에뮬레이터)가 정본이다: Firestore 18080, Storage 19199(dfet:firebase.json:37-50), Auth 19099·Functions 5001은 P0 시드 스토리(DF-042 채택 시 DF-042, 아니면 DF-012)가 추가한다. 로컬 개발·트레이너 통합 테스트의 프로젝트 ID는 `demo-dfet`다(`demo-` 접두는 실제 리소스에 닿지 않는다).

## 3. 로컬 준비

### 3.1 처음 한 번(소유자 Mac)

1. 저장소를 받고 `main`을 기준으로 둔다. v1 작업은 모두 `main`에서 분기한다(AS-DEV-11). `feature/integrated-care-2026`은 DF-901 뒤 삭제된다.
2. 도구 설치: Xcode 16.x, XcodeGen 2.44.1(GitHub 릴리스 `xcodegen.zip`을 SHA-256 `a2e905fb…1b73`으로 확인해 설치. brew로 설치하지 않는다, [SPRINT_01 ASM-S01-09](sprints/SPRINT_01.md#13-가정asm), [ASM-13-04](#10-가정asm-13-nn)), `brew install jq gh`, Node 22, Java 21, Flutter 3.38.2, `npm install --global firebase-tools`(15.x 이상).
3. 의존성: `npm ci --prefix functions`, `npm ci --prefix admin_web`, `flutter pub get`.
4. **plist 배치(소유자만, ADR-019).** DF-903에서 받은 `GoogleService-Info.plist`를 저장소 밖(예: `~/secure/dfet/trainer/`)에 보관하고, 실기기·운영 연결 빌드가 필요할 때만 `trainer_app/Config/GoogleService-Info.plist`로 복사한다. 이 경로는 `.gitignore` 대상이다(DF-034). 내용은 어디에도 붙여 넣지 않는다. 에이전트 환경에는 plist를 두지 않는다. plist가 없으면 preview 구성으로 빌드된다.
5. 트레이너 앱 프로젝트 생성: `xcodegen generate --spec trainer_app/project.yml`(DF-008 이후). 생성된 `DFETTrainer.xcodeproj`는 커밋 대상이며 CI가 재생성 diff로 검증한다.
6. **Storage 규칙 배포 대상 = 서울 버킷(DEC-19, DF-043).** `firebase.json`의 `storage`는 `[{"bucket", "target": "seoul", "rules": "storage.rules"}]` 형식이다. firebase-tools 15.x 에뮬레이터는 `bucket`만 있는 배열을 거부하고(`Must supply 'target' in Storage configuration`) `target`을 쓰므로, 배포와 에뮬레이터 모두 `.firebaserc`의 `targets.<프로젝트>.storage.seoul` 매핑으로 버킷을 찾는다. 운영 매핑(서울 버킷 1개)과 에뮬레이터 프로젝트(`dfet-rules-test`·`dfet-e2e`·`dfet-migrations`·`demo-dfet`) 매핑은 저장소 `.firebaserc`에 커밋돼 있다(버킷 이름은 비밀이 아니다). DF-942에서 만든 서울 버킷 이름이 저장소 값과 다르면 소유자가 `firebase target:clear storage seoul --project dfetmanage` 뒤 `firebase target:apply storage seoul <서울 버킷> --project dfetmanage`로 다시 연결하고, 같은 PR에서 `functions/src/shared/storage.js`·`lib/config/storage_bucket.dart`·`admin_web/.env.example`·`admin_web/apphosting.yaml`·`admin_web/lib/firebase-admin.ts` 대체값·`firebase.json` `bucket`을 같은 값으로 바꾼다(`npm --prefix functions test`의 `storage-bucket.test.js`가 여섯 곳이 같은지 확인한다). 새 에뮬레이터 프로젝트 ID를 CI에 추가하면 `.firebaserc`에 같은 `seoul` 매핑(`<id>`, `<id>.appspot.com`, `<id>.firebasestorage.app`)을 더한다. 매핑이 없으면 Storage 에뮬레이터가 시작하지 않는다. 회원 앱은 `FirebaseStorage.instance` 대신 `lib/config/storage_bucket.dart`의 `appStorage()`(서울 버킷 `instanceFor`)를 쓴다. `lib/firebase_options.dart`의 `storageBucket`은 바꾸지 않는다. Android·iOS는 네이티브 설정 파일(`google-services.json`·`GoogleService-Info.plist`, 기본 버킷)로 기본 앱을 먼저 만들고, Dart 값이 다르면 `Firebase.initializeApp`이 `[core/duplicate-app]`으로 실패해 App Check까지 꺼진다. `test/firebase_options_storage_bucket_test.dart`가 두 값이 같은지, `lib/`에 `FirebaseStorage.instance`가 없는지 확인한다. 계정 삭제(`deleteOwnAccount`)는 DF-043 전 업로드가 남은 기존 기본 버킷도 함께 지운다(`deleteAccountMedia()`). 기존 기본 버킷은 `firebase.json` 배포 대상이 아니므로 그 버킷의 Storage 규칙은 콘솔에서 소유자가 관리한다.

### 3.2 에뮬레이터와 합성 시드

```bash
# 에뮬레이터 실행(프로젝트 ID는 demo-dfet)
firebase emulators:start --only auth,firestore,storage,functions --project demo-dfet

# 다른 터미널에서 합성 시드(스크립트·기본 파일은 P0 시드 스토리, P1a 추가분·변형은 DF-107. V1-10 §5.4)
export FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:19199
node functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json
```

- 시드는 가상 트레이너 2명(trainer claim), 가상 회원 3명, 대기 회원 1명, 플래그 8키(`soapV2`·`bodyComposition` true), published 동의 문서 5종을 넣는다([V1-10 §5.4](10_TEST_PLAN.md#54-에뮬레이터-시드)). 식별자·표시명 규약은 [V1-10 §5.2](10_TEST_PLAN.md#52-합성-식별자표시명-규약)를 따른다.
- 시드 스크립트는 에뮬레이터 환경 변수가 없으면 아무것도 쓰지 않고 종료 코드 2로 끝난다. 운영 프로젝트 ID 문자열은 스크립트와 테스트에 넣지 않는다(정적 가드).
- 오류 주입 변형: `functions/test/fixtures/emulator-seed.no-consent.v1.json`, `emulator-seed.consent-fail.v1.json`. ID는 `synthTrainerA`·`synthMember0001`·`SYNTHpending00000001`([ASM-13-02](#10-가정asm-13-nn)).

### 3.3 트레이너 앱을 plist 없이 보기

- `--preview-*` 실행 인자로 인메모리 합성 저장소를 쓰는 DEBUG 전용 구성이다(ADR-001, [V1-04](04_ARCHITECTURE.md)). 인자 목록과 시나리오는 [V1-07](07_TRAINER_APP_SPEC.md)과 [V1-10 §10.4](10_TEST_PLAN.md#104-ui-테스트와-상태-매트릭스-스냅샷)를 따른다.
- 릴리스 빌드의 기본 저장소는 Preview가 아니다(DF-017 수용 기준).

## 4. 명령 모음

아래 명령은 해당 스토리가 병합된 뒤부터 동작한다. 에이전트는 작업 지시서 8절(검증 명령)에 적힌 명령을 그대로 실행하고 결과를 PR과 완료 보고에 붙인다.

| 영역 | 명령 | 도입 스토리 |
|---|---|---|
| 문서 | `node tool/lint/doc-headers.mjs --links docs/v1` | DF-001 |
| 백로그 | `node tool/backlog/build_issues.mjs --check`, `node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md`, `bash tool/backlog/test/run.sh`, `bash tool/backlog/create_github_issues.sh`(dry-run) | 스테이징에 있음, DF-002가 CI 연결 |
| contracts | `node tool/contracts/generate.mjs --check` | DF-004 |
| 금지어 | `node tool/lint/prohibited-terms.mjs` | DF-010(보고 모드), DF-040(차단 모드) |
| 정적 가드 | `bash tool/lint/static-guards.sh` | DF-011 |
| TrainerCore 순수 타깃 | `swift test --package-path trainer_app/Packages/TrainerCore`(TrainerContracts, TrainerDomain, PostureMath, SyncEngine, TrainerAnalytics) | DF-008 |
| 트레이너 앱 생성물 | `xcodegen generate --spec trainer_app/project.yml && git diff --exit-code` | DF-008 |
| 트레이너 앱 시뮬레이터 | `xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'` | DF-008 |
| 트레이너 통합 | `firebase emulators:exec --only auth,firestore,storage,functions --project demo-dfet "xcodebuild test ... -only-testing:IntegrationTests"` | DF-107 |
| Functions | `npm --prefix functions run lint`, `npm --prefix functions test` | 기존(dfet:functions/package.json `scripts`) |
| 규칙 | `firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"` | 기존(dfet:.github/workflows/ci.yml:53), DF-022·DF-035·DF-023 확장 |
| Functions e2e | `firebase emulators:exec --only functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"` | 기존(dfet:.github/workflows/ci.yml:55). 가짜 비밀은 CI처럼 `functions/.secret.local`에 테스트 값만 둔다 |
| 이관 | migrations job(에뮬레이터에서 레거시 픽스처 → 기대 v2) | DF-031 |
| 회원 앱 | `flutter analyze`, `flutter test` | 기존(dfet:.github/workflows/ci.yml:25-27) |
| admin_web | `npm --prefix admin_web run lint`, `run typecheck`, `test`, `run build` | 기존(dfet:.github/workflows/ci.yml:66-70) |
| BodyPathCore(P2) | BodyPath 저장소에서 `swift test` | DF-300·DF-302 |

## 5. AI 에이전트 진입 문서

DF-001이 저장소의 `AGENTS.md`와 `CLAUDE.md` 끝에 아래 절을 붙인다(두 파일 동일, 기존 내용은 바꾸지 않는다). 정본 문구는 [P0 DF-001 카드](backlog/P0.md#df-001)다.

```markdown
## D-FET Coach v1 개발
- 정본: docs/PRD_V1.md. 개발 문서: docs/v1/00_README.md(지도), docs/v1/13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md(에이전트 규약).
- 작업은 이슈의 에이전트 작업 지시서(V1-T08)에 적힌 수정 허용 경로 안에서만 한다.
- 금지: main 직접 푸시·병합·배포, 운영 데이터 접근·이관 실행, 비밀 파일(.env*, .secret.local, GoogleService-Info.plist 값, 키)과 output/·tmp/ 열람.
- 금지: GitHub 이슈 생성, PRD 직접 수정(수정 제안만).
- 모든 검증은 합성 데이터와 에뮬레이터로 하고 증빙을 PR에 첨부한다.
```

에이전트가 스토리를 시작하는 순서:
1. 이슈에 붙은 작업 지시서([V1-T08](templates/AGENT_BRIEF.md))를 읽는다. 지시서가 없으면 시작하지 않고 이슈에 '지시서 없음'을 코멘트한다.
2. [02 §8 색인](02_PRODUCT_BACKLOG.md#8-전체-스토리-색인)에서 의존 스토리가 병합됐는지 확인한다.
3. 지시서의 컨텍스트 팩(§6)만 읽는다. PRD는 절 번호로 좁혀 읽는다.
4. `main`에서 `claude/DF-NNN-<slug>` 또는 `codex/DF-NNN-<slug>` 브랜치를 만든다.
5. 테스트부터 쓰고 구현한 뒤 지시서의 검증 명령을 실행한다.
6. draft PR(템플릿 전부 작성)과 이슈 완료 보고([01 형식](01_AGILE_WORKING_AGREEMENT.md#완료-보고-형식에이전트--이슈-코멘트))를 남긴다.

## 6. 컨텍스트 팩(영역별 필독)

작업 지시서 3절은 아래에서 고른다. 항상 읽는 것: 해당 스토리 카드 전문, [01 에이전트 권한 경계](01_AGILE_WORKING_AGREEMENT.md#에이전트-권한-경계), 이 문서 §7.

| 영역(area/) | 필독 | 필요할 때만 |
|---|---|---|
| trainer-app(골격·모듈) | [V1-04](04_ARCHITECTURE.md)의 저장소 배치·TrainerKit 모듈·의존 그래프, [ADR-001](adr/ADR-001-independent-trainer-app.md), [ADR-002](adr/ADR-002-local-first-swiftdata-outbox.md) | [ADR-019](adr/ADR-019-config-and-secrets.md), [V1-10 §10](10_TEST_PLAN.md#10-트레이너-앱-테스트) |
| trainer-app(화면) | [V1-07](07_TRAINER_APP_SPEC.md)의 해당 TR 절, [V1-12](12_COPY_ANALYTICS_AND_LINT.md) 문구 키, `docs/v1/data/copy_ko.json` | PRD §6의 해당 F-ID, §8.4 상태 매트릭스 |
| trainer-app(이식) | DF-039 이식표, 카드의 원본 줄 범위와 반례 | 보관 브랜치 `archive/trainer-ui-2026-09` tip([00_README 이식 기준선](00_README.md#이식-기준선)) |
| contracts | [ADR-005](adr/ADR-005-soap-schema-v2-contracts.md), [V1-05](05_DATA_MODEL_AND_RULES.md) contracts JSON 스키마 절, [V1-10 §6](10_TEST_PLAN.md#6-계약교차-클라이언트-테스트) | PRD 부록 A·B |
| rules·storage | [V1-05](05_DATA_MODEL_AND_RULES.md) 규칙 설계·R/S 테스트 설계, [V1-10 §7](10_TEST_PLAN.md#7-보안-규칙storage-테스트), [ADR-003](adr/ADR-003-uid-identity-pending-members.md), [ADR-007](adr/ADR-007-storage-binaries-lidar-local.md) | PRD §9.4·§9.5 |
| functions | [V1-06](06_API_SPEC.md) 해당 함수 계약, [ADR-017](adr/ADR-017-functions-structure.md), [V1-10 §8](10_TEST_PLAN.md#8-functions-단위e2e-테스트) | [ADR-011](adr/ADR-011-consent-model.md)(동의), PRD §9.7(삭제 범위) |
| privacy·analytics | [ADR-011](adr/ADR-011-consent-model.md), [ADR-015](adr/ADR-015-analytics-privacy.md), [V1-12](12_COPY_ANALYTICS_AND_LINT.md) 이벤트 레지스트리 | `docs/v1/data/analytics_events.json` |
| 금지어·문구 | [ADR-016](adr/ADR-016-regulatory-copy-lint.md), [V1-12](12_COPY_ANALYTICS_AND_LINT.md), `docs/v1/data/forbidden_terms.json` | PRD 부록 C |
| member-app·admin-web | [V1-08](08_MEMBER_APP_AND_ADMIN_SPEC.md) 해당 MB·AD 절, [ADR-006](adr/ADR-006-member-summaries.md) | [ADR-010](adr/ADR-010-feature-flags.md), [ADR-018](adr/ADR-018-admin-claim-unification.md) |
| 알고리즘 | [V1-09](09_ALGORITHMS_SPEC.md) 해당 절, [V1-10 §9](10_TEST_PLAN.md#9-알고리즘-벡터) | [ADR-008](adr/ADR-008-apple-vision-landmarks.md), [ADR-009](adr/ADR-009-server-only-change-evaluation.md) |
| 이관 | [V1-11](11_MIGRATION_RUNBOOK.md) 해당 MIG 절, [V1-10 §12](10_TEST_PLAN.md#12-이관-테스트) | PRD §11 |
| ci·backlog 도구 | [V1-10 §19](10_TEST_PLAN.md#19-ci-워크플로), [TL-01](../../tool/backlog/README.md), [ADR-014](adr/ADR-014-branching-release.md) | — |
| bodypath(P2) | [ADR-012](adr/ADR-012-bodypath-result-package.md), [V1-10 §3.7](10_TEST_PLAN.md#37-bodypathcorebodypath-저장소-p2-준비) | PRD §10.4 |

## 7. 금지 행동과 비밀·실데이터 규칙

정본은 [01 에이전트 권한 경계](01_AGILE_WORKING_AGREEMENT.md#에이전트-권한-경계)다. 요지:

- **Git·GitHub:** `main` 직접 푸시, 자기 PR 병합, 자동 병합, 태그 생성, 이슈 생성, 라벨·마일스톤·Projects·저장소 설정 변경을 하지 않는다. `tool/backlog/create_github_issues.sh --apply`를 실행하지 않는다(dry-run만). 스프린트 PR의 병합은 DEC-20 조건(CI 초록 + 적대적 리뷰 승인)을 확인한 병합 담당 AI만 rebase로 한다. 권한 경계를 바꾸는 PR(01 권한 경계, 00 DEC 행, `.github/CODEOWNERS`, PR 템플릿, `AGENTS.md`, `CLAUDE.md`)은 소유자만 병합한다([01 에이전트 권한 경계](01_AGILE_WORKING_AGREEMENT.md#에이전트-권한-경계) '병합' 행).
- **파일:** 지시서의 수정 허용 경로 밖, `docs/PRD_V1.md`(수정 제안만), 동결 경로(`trainer_ios/`, `ios/Runner/AppDelegate.swift`, `lib/widgets/shells/trainer_shell.dart`, `lib/screens/trainer/**`, `lib/router/app_router.dart`의 `/trainer` 라우트·트레이너 리다이렉트 줄, `lib/services/firestore_service.dart`의 SOAP 함수. 정본 목록은 [G-01 동결 선언](evidence/G-01.md#동결-선언). freeze-exception 지시서가 있을 때만 예외)를 고치지 않는다.
- **비밀:** `.env*`, `functions/.secret.local`, `GoogleService-Info.plist` 값, 서명 인증서, API 키, 서비스 계정 키를 열거나 출력하거나 커밋하지 않는다. CI 시크릿 이름(값 아님): `TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64`([ADR-019](adr/ADR-019-config-and-secrets.md)), 서명 인증서·App Store Connect API 키(DF-922·DF-139), BodyPath 읽기 자격(DF-923). 초대 코드 HMAC 키는 Secret Manager에 둔다.
- **데이터:** 운영 Firestore·Storage, `output/`, `tmp/`, 내보내기 파일, 회원 데이터를 열지 않는다. 테스트·픽스처·스크린숏은 합성 가상 회원만 쓴다([V1-10 §5.1](10_TEST_PLAN.md#51-금지-데이터와-허용-데이터)).
- **실행:** `firebase deploy`, 이관 스크립트 `--apply`, TestFlight 업로드, 운영 프로젝트 ID를 가리키는 모든 명령을 실행하지 않는다.
- **의존성:** 지시서가 허용하지 않은 npm·SPM·pub 의존성을 추가하지 않는다(ADR-013, ADR-017).
- PRD가 모호하면 추측하지 말고 PR '가정' 절에 `AS-DEV-후보`로 적은 뒤 가장 보수적인 해석(기능 숨김, 저장 안 함, 판정 안 함)을 택한다.

## 8. 병렬 배정과 PR 증빙

- 동시에 여는 에이전트 브랜치는 3개 이하다. 수정 경로 교집합이 없어야 한다: TrainerCore·TrainerKit은 타깃 단위, functions는 `src/<domain>` 단위, 규칙은 파일 단위(`firestore.rules`는 한 번에 한 스토리)([01 에이전트 배정 규칙](01_AGILE_WORKING_AGREEMENT.md#에이전트-배정-규칙)).
- xcodebuild·시뮬레이터가 필요한 트레이너 앱 UI 작업은 소유자 Mac의 Claude Code에 우선 배정한다. Codex 클라우드에서 macOS 검증이 불가하면 CI 결과를 증빙으로 쓴다.
- 생성물(`*/generated/**`, `DFETTrainer.xcodeproj`, `tool/backlog/issues.json`)을 건드리는 스토리가 동시에 둘이면 뒤에 병합되는 쪽이 재생성 후 다시 푸시한다.
- PR에 붙일 증빙: 수용 기준별 테스트 이름과 결과, 실행한 명령과 출력 요약, 스냅샷(합성 데이터), 수정 경로 목록, 가정, '비밀·실데이터 접근 없음' 확인([PR 템플릿](../../.github/pull_request_template.md)).

## 9. 흔한 실패와 대응

| 증상 | 원인 | 대응 |
|---|---|---|
| 목록 쿼리 전체가 `permission-denied` | 쿼리에 `trainerId == uid` 조건이 없어 규칙이 목록을 증명하지 못한다 | 모든 원 기록 목록 쿼리에 `trainerId == uid`를 넣는다(ADR-003, V1-05 쿼리·규칙 정합 목록) |
| 쿼리 오류가 빈 화면으로 보임 | 오류를 빈 목록으로 삼켰다 | '불러오기 실패'와 재시도를 보인다(F-VIZ-05.6). 리뷰에서 반려한다(FirebaseData의 `print(`는 static-guards가 잡는다) |
| 에뮬레이터에서만 '동기화 실패' | 시드의 `appConfig/features`가 false라 규칙 `featureOn`이 create를 거부 | 시드 플래그 값을 먼저 확인([V1-10 §5.4](10_TEST_PLAN.md#54-에뮬레이터-시드)) |
| 인덱스 누락 오류 | §9.6 복합 인덱스 미정의 | `firestore.indexes.json`에 추가(DF-024), 에뮬레이터 쿼리 테스트로 확인 |
| CI `generate.mjs --check` 실패 | contracts를 바꾸고 생성물을 다시 만들지 않았다 | `node tool/contracts/generate.mjs` 후 생성물 커밋 |
| CI `build_issues.mjs --check` 실패 | 색인·카드를 바꾸고 `issues.json`을 다시 만들지 않았다 | `node tool/backlog/build_issues.mjs` 후 커밋 |
| `git diff --exit-code` 실패(trainer_app) | `project.yml`을 바꾸고 xcodeproj를 재생성하지 않았다 | `xcodegen generate --spec trainer_app/project.yml` 후 커밋 |
| 시뮬레이터 카메라·Pencil·센서 기능 불가 | 시뮬레이터 한계 | 프로토콜 뒤 가짜 구현으로 단위 테스트, 실기기 확인은 `needs-device-test` 라벨과 V1-T09 |
| 시뮬레이터 권한 팝업으로 UI 테스트 정지 | 사진·카메라 권한 | `--preview-*` 구성에서 권한 경로를 가짜로 대체하거나 `addUIInterruptionMonitor`로 처리 |
| Storage 규칙이 에뮬레이터에서는 통과, 운영에서 실패 | 교차 서비스 `firestore.get` 권한 미부여 | 소유자 DF-906, 실환경 확인 DF-038(S-09) |
| copy-lint가 부정문 고지를 위반으로 잡음 | 예외 문구는 정확 일치로만 허용 | [V1-12](12_COPY_ANALYTICS_AND_LINT.md) 예외(AE-*) 문구를 한 글자도 바꾸지 않는다 |
| 백로그 dry-run이 '생성 N건'이라고만 함 | dry-run은 네트워크를 쓰지 않아 기존 이슈를 모른다 | 정상. 실제 중복 판단은 소유자의 `--apply`에서만 한다 |

## 10. 가정(ASM-13-NN)

| ID | 가정 | 근거 | 틀리면 |
|---|---|---|---|
| ASM-13-01 | firebase-tools 버전은 고정하지 않고 CI와 같은 최신을 쓴다 | dfet:.github/workflows/ci.yml:52 | 에뮬레이터 동작 차이가 생기면 CI와 로컬에 같은 버전을 고정한다 |
| ASM-13-02 | 에뮬레이터 시드 정본은 `functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json`(변형 2개: `emulator-seed.no-consent.v1.json`, `emulator-seed.consent-fail.v1.json`), 프로젝트 `demo-dfet`, synth ID(`synthTrainerA`·`synthMember0001`·`SYNTHpending00000001`)다(R2, 결정 2026-09-24). 다른 이름은 쓰지 않는다 | V1-10 §5.2·§5.4, R2 결정 2026-09-24 | 다른 경로·ID를 쓰는 문서를 이 정본으로 고친다 |
| ASM-13-03 | 에이전트 환경(Codex 클라우드 등)에는 xcodegen·Xcode가 없을 수 있어, 커밋된 xcodeproj와 CI 결과를 증빙으로 쓴다 | ADR-001, 01 에이전트 배정 규칙 | 소유자 Mac에서만 배정 |
| ASM-13-04 | XcodeGen은 2.44.1 릴리스 zip으로 고정 설치한다(R8, 결정 2026-09-24). Homebrew 안정판은 2.46.0이라 brew로는 고정되지 않는다 | [SPRINT_01 ASM-S01-09](sprints/SPRINT_01.md#13-가정asm) | 로컬 `xcodegen version`이 2.44.1이 아니면 재생성 diff가 난다. zip으로 다시 설치한다 |

## 11. 변경 이력

| 버전 | 날짜 | 작성 | 내용 |
|---|---|---|---|
| v1.0 | 2026-09-24 | CJH(AI 에이전트 초안) | 최초 작성. 도구 버전은 dfet CI·package.json에서 확인, 명령·필독 목록은 01·10·ADR과 대조 |
| v1.0(정합 패스 2) | 2026-09-24 | CJH(AI 에이전트) | 시드 정본 확정(R2), XcodeGen zip 설치(R8), 포트 추가 담당 |
| v1.0.1 | 2026-09-24 | CJH(AI 에이전트) | 교차 정합성 조정: 시드 경로·ID 정본화(R2), XcodeGen zip 고정(R8, ASM-13-04), Auth·Functions 포트 추가를 P0 시드 스토리로 이관 |
| v1.0.2 | 2026-09-25 | CJH(AI 에이전트) | firebase-tools 15.x 이상 필수 명시(14.x는 functions v7 에뮬레이터 로드 실패). Flutter 3.38.2 고정과 iOS CocoaPods 빌드 명시(PR #1 CI 결과) |
| v1.1 | 2026-09-25 | CJH(AI 에이전트) | §7 Git 금지 행동을 DEC-20(병합 담당 AI의 rebase 병합, 구현 에이전트의 자기 PR 병합 금지)에 맞춤. §7 동결 경로를 DF-930 선언(G-01 동결 선언)과 같게 넓힘 |
| v1.1.1 | 2026-09-25 | CJH(AI 에이전트) | §3.1 6번: Storage 규칙 배포 대상 서울 버킷(`target` 형식과 `.firebaserc` 매핑, DF-043, DEC-19), 회원 앱 `appStorage()`, 계정 삭제의 기존 기본 버킷 정리 |

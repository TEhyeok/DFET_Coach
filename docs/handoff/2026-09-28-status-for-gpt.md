# D-FET Coach v1 진행 현황 (GPT 교차 검토용)

2026-09-28 기준. 작성: Claude Code. 이 문서는 다른 모델(GPT/Codex)이 지금까지 한 일, 진행 중인 일, 다음 계획을 한 번에 파악하고 검토하도록 만든 인수인계 문서다. 정본은 `docs/v1/`(V1-01~V1-12)과 `docs/v1/backlog/`이며, 충돌하면 그쪽이 우선한다.

## 1. 무엇을 만드는가

D-FET Coach는 트레이너용 iPad 앱(`trainer_app/`, Swift)과 회원 앱(Flutter, 루트 `lib/`), Firebase(Firestore·Storage·Functions, 서울 리전)로 이루어진다. 소유자가 원하는 핵심 기능은 세 가지다.

1. 체형평가(정면·측면 사진, 랜드마크, 자세 지표) + 신체조성(수기 입력, 결과지 사진, 줄자 둘레)
2. SOAP 노트 작성(세션 중 Live 필기, Review, 확정, addendum)
3. 위 기록의 시각화(회원 상세 타임라인, 추이 차트, 결과 화면)

범위는 DEC-22 '1인 알파 MVP' 67개 카드다(`tool/backlog/issues.json`의 `scope/mvp`, 각 카드의 `### MVP 범위(DEC-22)` 절이 범위를 정한다).

## 2. 지금까지 된 것 (main)

코드·병합 PR 기준으로 MVP 67개 중 31개 완료. 백로그의 `상태:` 줄은 갱신이 늦으니 믿지 말 것.

| 영역 | 카드 | PR |
|---|---|---|
| 문서·백로그·계약 | DF-001, 002, 003, 004, 005, 006, 027, 901 | #1, #2, #104, #105, #108, #109, #112, #117, #161 |
| 서버 규칙·인덱스·Functions 공통 | DF-020, 021, 022, 024, 035, 037, 042, 043 | #114, #154, #155, #156, #159, #160, #164, #167 |
| 트레이너 앱 기반 | DF-008, 009, 012, 013, 014, 015, 016, 017, 018, 034, 039, 104, 108 | #107, #118, #157, #158, #162, #163, #166, #168, #169, #173, #175, #176, #177 |
| 체형 계산·촬영 준비 | DF-201, DF-203(MVP 조각) | #170, #172 |
| 문구 카탈로그·아이폰 화면 수정 | — | #174, #178 |

화면으로 보이는 것은 로그인, 회원 목록(TR-02), 대기 회원 등록(TR-14, 만 14세 확인), 설정(TR-15: 로그아웃, 미동기 경고, 업로드 대기열)뿐이다. 세 핵심 기능의 화면은 아직 없다(회원 상세 TR-03은 플래그로 가려진 '추후 추가 예정' 버튼뿐).

이번 세션의 주요 설계 결정(검토 대상):

- 로컬 우선: LocalStore(SwiftData, 스키마 V1_1) + Outbox + SyncEngine. 초안과 Outbox 항목은 한 번의 저장으로 쓴다. acked 항목은 페이로드를 남기지 않는다.
- 세션 결속 전송(`SessionBoundRemote`): 매 전송 전·실패 후 로그인 uid를 확인하고, 다르면 `RemoteError.signedOut`으로 멈춘다(실패로 두지 않음).
- 로그아웃(ASM-P0-17): 미동기 기록은 지우지 않고 trainerUid 파티션에 남긴다. 서버에 있다는 증거가 있는 것만 purge한다.
- 모든 사용자 문구는 문구 덱 `docs/v1/data/copy_ko.json`이 정본이다. 카탈로그는 `tool/lint/catalog-deck.mjs`로만 바꾼다.

## 3. 진행 중 (GitHub 브랜치, 아직 PR 아님)

| 작업 | 브랜치 | 범위 |
|---|---|---|
| 신체조성 입력 + 추이 차트 | `claude/DF-127-body-composition`(통합), `claude/DF-127-domain`, `claude/DF-130-chart` | DF-127 TR-11 입력(값·기기·측정 시각·공복, 범위·교차 검증, BMI), DF-130 SeriesTrendChart(날짜 비례, 보간 없음, 기기 변경 끊김, '산정 준비 중'), TR-03 '측정 입력 > 신체조성' 메뉴와 미니 추이 |
| 동의 흐름 + 회원 목록 | `claude/consent-flow`(통합), `claude/DF-109-record-consent`, `claude/DF-110-consent`, `claude/DF-113-member-list` | DF-109 recordConsent(서버가 memberConsentStates 파생), DF-110 등록 뒤 동의 ①②③, DF-111 EffectiveConsent, DF-113 TR-02 대기 회원·동의 칩·검색 |

브랜치는 작업 중이라 계속 바뀐다. 끝나면 Claude 검토, GPT 검토를 거쳐 PR로 병합한다.

## 4. 다음 순서 (GPT 로드맵 검토 반영, 2026-09-28)

완료 기준은 iPad 시뮬레이터에서 도는 흐름 하나다: 대기 회원 등록 → 동의 ①②③ → 신체조성 저장 → 정정 → 추이 다시 열기. 좁은 폭(Slide Over 1/3, 320~375pt, V1-07 §3.3)에서도 확인한다. 1단계 UX 수정은 이 흐름만 다룬다. 앱 전체 다듬기는 병렬 후속이며 SOAP·체형을 막지 않는다. 소유자 아이폰 설치는 관문이 아니라 로컬 시연 빌드(project.yml 변경 없음, DF-904/Q-22 전)다.

1. 진행 중 두 작업(DF-127/130, DF-109/110/111/113) 병합. DF-128 중 '정정'(voidAndPrefill, 사유 1~200자, TC-128-05)은 DF-127 바로 뒤에 당겨 DF-925 플래그 전에 낸다. 결과지 사진 부분은 DF-118 뒤. DF-127에 들어간 SeriesSegmenter·기기 변경 표식(AC-DF-128.6·.7)은 DF-128·DF-216이 다시 만들지 않는다.
2. 공통 단계: DF-038(에뮬레이터 확인과 기록) → DF-023(storage.rules: soapInk, postureAssessments, bodyCompositionRecords/report, S-01~S-08) → DF-107(트레이너 앱 에뮬레이터 통합 CI: 순서·규칙 거부·오프라인).
3. 병렬 트랙(최대 3개, 01 WIP 규칙):
   - 트랙 A(SOAP): DF-116 → DF-118 → DF-114 → DF-120·121·122 → DF-123
   - 트랙 B(체형): DF-200을 `trainer_app/Spikes/VisionPoseSpike/`로 지금 시작(시뮬레이터 먼저, 안 되면 실기기로 관절 픽스처 기록) → DF-204 → DF-205·206 → DF-207·208 → DF-209 → DF-210. DF-209 구조 결정(K-10: MetricOptions·PostureMetricResult 위치, 수명 주기 구현 위치)은 트랙 B 시작 전에 먼저 한다.
   - 트랙 C(측정): DF-129 → DF-216(`TrainerDomain/Series` 위) → DF-128 결과지(DF-118 뒤)
   - 마지막: DF-215, DF-225(DF-209 뒤)
4. 공유 경로 순서: `TrainerDomain/Series`는 DF-127/130 → DF-216 → DF-215. `firestore.rules`·`storage.rules`는 한 번에 한 스토리만 고친다.

## 5. 알려진 편차·후속

- V1-04 §9.3 저장소 격리·복구 안내 미구현(잠금 중 열기 실패를 손상으로 오판할 위험 때문에 설계 필요). MVP 뒤.
- `SyncStateBadge` 실패 행 정렬(스냅샷 재기록 필요).
- 트레이너 앱 에뮬레이터 통합 테스트는 로컬 스크립트(`trainer_app/scripts/test_auth_emulator.sh`)로만 돌고 CI에서는 빠져 있다(DF-107이 CI 잡을 만든다).
- 아이폰 세로 폭·큰 글씨 배치를 재는 UI 테스트가 없다(GPT 첫 검토 지적).

## 6. 소유자(사람)만 할 수 있는 일

정본은 [00_README 소유자 대기 목록](../v1/00_README.md) 1~12단계다. 요약:
DF-942 서울 이전(사전 점검 942-1, 삭제 전 반드시 내보내기, 중단 조건) → DF-903 앱 등록(의존 없음, 병렬 가능) → DF-905 트레이너 테스트 계정(서울 DB 재생성 뒤) → DF-906 Storage 권한(첫 DF-931 배포와 함께) → DF-109 테스트 동의 문서 게시(dry-run 먼저, `--apply --project dfetmanage`는 소유자만) → DF-925·DF-929 플래그 → S12 끝 DF-931 MVP 재배포(DF-114 둘레 인덱스, 인덱스 빌드 완료 뒤 데모 체크리스트 B). 이 중 어느 것도 에뮬레이터 개발을 막지 않는다.

## 7. GPT에게 부탁하는 검토

1. 동기화 설계: `trainer_app/Packages/TrainerCore/Sources/SyncEngine/SyncEngine.swift`, `LocalStore/LocalOutboxStore.swift`, `App/Composition/SessionRuntime.swift`, `LiveSessionSignOut.swift`. 데이터가 사라지거나 순서가 뒤집히는 경로가 있는가?
2. 서버 규칙: `firestore.rules`의 soap_notes·bodyCompositionRecords·pendingMembers·memberConsentStates. 클라이언트가 우회할 수 있는 쓰기, 담당이 아닌 회원 읽기가 있는가?
3. 동의: recordConsent와 EffectiveConsent(진행 중 브랜치). 로컬 캡처가 서버 동의로 오인되는 경로가 있는가?
4. UI/UX: TR-02·TR-11·TR-14·TR-15 흐름이 트레이너에게 자연스러운가? 아이폰 폭에서 깨지는 곳은?
5. 우선순위: 세 핵심 기능을 가장 빨리 '실제로 쓸 수 있게' 하려면 위 4절 순서가 맞는가?

## 8. 코드 지도와 확인 방법

- `trainer_app/Packages/TrainerCore`(순수 Swift: TrainerDomain, SyncEngine): `swift test --package-path trainer_app/Packages/TrainerCore`
- `trainer_app/Packages/TrainerKit`(iOS 모듈: LocalStore, FirebaseData, DesignSystem, Feature*), `trainer_app/App`(조립): XcodeGen(`xcodegen generate --spec project.yml --project .`) 뒤 iPad 시뮬레이터 `xcodebuild test`
- 규칙·Functions 테스트: `functions/test/`(Firebase 에뮬레이터, 프로젝트 `demo-*`만)
- 미리보기(합성 데이터, Firebase 없음): `--preview-members --preview-flags=bodyComposition` 등(`trainer_app/README.md` Preview arguments)
- 금지: 비밀 파일(`.env*`, `GoogleService-Info.plist`), 실제 회원·건강 데이터(`output/`, `tmp/`), 운영 Firebase

## 9. GPT 교차 검토 결과 (2026-09-28, Codex CLI)

12개 영역(완료 9, 진행 중 1, 설계 1, 로드맵 1)을 GPT가 검토했고 Claude가 지적마다 코드와 대조했다. 45건 중 34건 확인, 11건 기각.
- 높음 1건(두 영역 중복): 로그아웃 3초 대기 제한이 작동하지 않음(`waitUntilIdle` 취소 불가).
- 중간: 인증 실패의 영구 실패 처리, 로그아웃 실패 뒤 목록 구독 미복구, 대기열 빈 상태 오표시, 규칙 2건(요청 문서 소유자 변경, 게시글 수정 검증), claim 회수 잠금의 로그아웃 의존, 금지어 검사 누락, 동의 설계 2건(멱등 재응답 순서, 새 대기 회원 동의 리스너 순서), 로드맵 2건(4절 반영).
- 병합된 코드의 수정: 브랜치 `claude/gpt-review-fixes`(진행 중). 진행 중 작업의 지적은 각 브랜치에 반영한다.


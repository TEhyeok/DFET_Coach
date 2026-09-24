# 릴리스 체크리스트 템플릿

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-T14 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §12.1 단계, §12.3 플래그 개방 순서, §12.4 롤백 기준, §10.8 NFR-09·NFR-16, §11.12 MIG-11 |
| 관련 에픽·스토리 | DF-139(TestFlight 워크플로), DF-922, DF-931(규칙·함수 배포), DF-924(MIG 적용), DF-925·929·934·935(플래그 개방), DF-911(회원 앱 문구 릴리스), DF-390(1.0) |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [사용법](#사용법)
- [릴리스 종류와 태그](#릴리스-종류와-태그)
- [공통 사전 점검](#공통-사전-점검)
- [A. 트레이너 앱 TestFlight](#a-트레이너-앱-testflight)
- [B. 회원 앱 스토어 릴리스](#b-회원-앱-스토어-릴리스)
- [C. 보안 규칙·인덱스·Storage 규칙 배포](#c-보안-규칙인덱스storage-규칙-배포)
- [D. Functions 배포](#d-functions-배포)
- [E. 기능 플래그 개방](#e-기능-플래그-개방)
- [F. 롤백](#f-롤백)
- [변경 이력](#변경-이력)

## 사용법

- 모든 배포는 **소유자만** 한다. CI는 배포하지 않는다(ADR-014). 에이전트는 이 체크리스트를 실행하지 않는다.
- 릴리스마다 운영 이슈 `[릴리스] <태그>`(type/chore)를 만들고 해당 절을 본문에 붙여 체크한다. 완료 후 이슈 링크를 스프린트 리뷰에 적는다.
- 이관 적용(MIG-03~08)은 이 문서가 아니라 [V1-11](../11_MIGRATION_RUNBOOK.md)과 [V1-T10](MIGRATION_RUN_RECORD.md)을 따른다. 이 체크리스트는 이관과 묶이는 배포 순서만 확인한다.
- 명령의 `--project dfetmanage`는 운영 프로젝트다. 저장소에 `.firebaserc`가 없으므로 항상 명시한다. 배포 명령은 항상 `firebase deploy --project dfetmanage --only …` 순서로 적는다([V1-00 DEC-15](../00_README.md), R7).

## 릴리스 종류와 태그

| 종류 | 태그 | 채널 | 단계 |
|---|---|---|---|
| 트레이너 앱 | `trainer-vX.Y.Z` (0.1 P0 → 0.2 P1a → 0.3 P1b → 0.4 P2 → 1.0 P3) | TestFlight 내부 그룹(P1a~P2), P3 채널은 Q-DEV-02 | P0~P3 |
| 회원 앱 | `member-vX.Y.Z` | App Store·Google Play | 문구 수정(DF-911), P2 MB 화면 |
| Firestore 규칙·인덱스, Storage 규칙 | `rules-YYYYMMDD-N` | Firebase 운영 | P0 이후 |
| Functions | `functions-YYYYMMDD-N` | Firebase 운영 | P0 이후 |
| 이관 적용 | `mig03-apply-YYYYMMDD` 등 | 운영 데이터 | P1a 진입 |

## 공통 사전 점검

```markdown
- [ ] 태그 대상 커밋이 main에 있고 필수 CI가 모두 초록이다(커밋 SHA: <sha>)
- [ ] 이번 릴리스에 포함된 DF 목록과 각 PR이 Done이다: <DF-..., #PR>
- [ ] 금지어 린트(copy-lint)가 차단 모드로 통과한다(P0 종료 이후)
- [ ] 규칙 테스트 R-01~R-31, S-01~S-08 100%(M-G4)
- [ ] 플래그 기본값 확인: 새 키는 false(개방은 E절에서 따로)
- [ ] 비밀이 커밋·아티팩트·로그에 없다(plist 값, 키, .secret.local)
- [ ] 롤백 방법을 F절에서 미리 골라 두었다
- [ ] 게이트 선행 조건 충족(해당 시): <G-NN 증빙 링크>
```

## A. 트레이너 앱 TestFlight

```markdown
### 준비
- [ ] trainer_app/project.yml의 MARKETING_VERSION = <X.Y.Z>, 빌드 번호는 워크플로가 github.run_number로 설정
- [ ] xcodegen 재생성 diff 0, trainer-app CI 초록, trainer-app-emulator-it 최근 야간 실행 초록
- [ ] 릴리스 구성에서 App Check가 App Attest를 쓴다(NFR-09)
- [ ] 릴리스 기본 저장소가 Preview가 아니다(NFR-03), DEBUG 플래그 오버라이드 메뉴가 릴리스에 없다
- [ ] 플래그 false인 기능의 진입점 0(AC-IA-02) — --preview-* UI 스모크 결과
- [ ] 분석 싱크: G-09 공개 전이면 DebugSink만(ADR-015)

### 실기기 확인(needs-device-test, V1-T09 기록)
- [ ] 비행기 모드 저장 → 강제 종료 → 재실행 유지, 복구 후 중복 0(NFR-04)
- [ ] 규칙 거부 상황에서 '동기화 실패'와 재시도 표시(C-05)
- [ ] 4방향·1/3 Split View 잘림 없음(NFR-12)
- [ ] 로그아웃 후 세션 종료·미동기 경고(NFR-08)

### 업로드
- [ ] 태그 `trainer-vX.Y.Z` 생성·푸시
- [ ] GitHub Actions `trainer-testflight` 워크플로를 workflow_dispatch로 실행(입력: 태그)
- [ ] App Store Connect에서 빌드 처리 완료, 내부 그룹에 배포
- [ ] 수출 규정·암호화 질문 응답 확인

### 배포 후
- [ ] 설치 후 claim 계정 로그인, 담당 회원 로드(가상 회원)
- [ ] 크래시·저장 실패 표시 이벤트 확인(24시간)
- [ ] 스프린트 리뷰에 릴리스 기록
```

## B. 회원 앱 스토어 릴리스

```markdown
- [ ] pubspec.yaml version 증가(<x.y.z+n>)
- [ ] flutter analyze·test·ios-no-codesign 초록(iOS 15.5 유지, NFR-01)
- [ ] 회원 노출 문자열 회원 규칙 세트 통과(부록 C.3), 새 문장은 부록 B.8만
- [ ] P0 문구 수정 릴리스(DF-911)면: guide_screen·onboarding_screen·profile_setup_screen·create_request_screen 금지어 0 확인(MIG-04)
- [ ] 새 화면(MB-01~06)은 플래그 조건 뒤에 있다(memberShare && (bodyAssessment || bodyComposition))
- [ ] 스토어 메타데이터·스크린샷 금지어 수동 검수(G-10 체크리스트 사용, P3 필수)
- [ ] 태그 `member-vX.Y.Z`, 스토어 제출, 심사 결과 기록
```

## C. 보안 규칙·인덱스·Storage 규칙 배포

```markdown
### 순서 원칙
- 인덱스 → 규칙 → 클라이언트. 새 쿼리를 쓰는 앱이 배포되기 전에 인덱스와 규칙이 먼저 있어야 한다.
- v1 SOAP 쓰기 영구 차단 스위치는 MIG-03 적용(DF-924)과 같은 창에서 켠다(V1-11 순서).
- Storage 규칙은 Storage 서비스 계정의 Firestore 교차 조회 권한(G-03, DF-906)이 부여된 뒤 배포한다.

### 실행
- [ ] 에뮬레이터 규칙 테스트 로컬 재실행 통과
- [ ] 배포 전 운영 규칙 백업(콘솔에서 현재 버전 기록)
- [ ] 태그 `rules-YYYYMMDD-N`
- [ ] `firebase deploy --project dfetmanage --only firestore:indexes` 후 인덱스 빌드 완료 확인
- [ ] `firebase deploy --project dfetmanage --only firestore:rules`
- [ ] `firebase deploy --project dfetmanage --only storage`
- [ ] 실환경 스모크(가상 계정): 담당 트레이너 목록 쿼리 성공, 비담당 거부, S-09 교차 조회 허용 케이스
- [ ] 배포 기록(태그, 시각, 결과)을 DF-931 이슈에 남김
```

## D. Functions 배포

```markdown
- [ ] functions-and-rules CI 초록(단위, 규칙, e2e)
- [ ] 신규 함수 region = asia-northeast3, 기존 callable 이름·리전 변경 없음(NFR-16)
- [ ] 필요한 비밀(HMAC 키 등)이 Secret Manager에 있다(값은 기록하지 않음)
- [ ] 태그 `functions-YYYYMMDD-N`
- [ ] 변경 함수만 배포: `firebase deploy --project dfetmanage --only functions:<name1>,functions:<name2>`
- [ ] 트리거·스케줄 함수는 첫 실행 로그를 확인(건수만)
- [ ] (P3) callable enforceAppCheck 켜기 전 회원 앱·admin_web 경로 확인(DF-386)
```

## E. 기능 플래그 개방

PRD §12.3 순서를 따른다. 개방은 admin_web AD-07에서 하고 감사 기록이 남는다.

```markdown
| 순서 | 플래그 | 소유자 행동 | 전제 확인 |
|---|---|---|---|
| 1 | soapV2, bodyComposition | DF-925 | [ ] G-04 [ ] G-09 [ ] G-05a 제출 [ ] MIG-03 적용 [ ] G-03 |
| 2 | bodyAssessment | DF-929 | [ ] P1a 종료 검토 통과 [ ] TR-07~09 동작 확인 |
| 3 | memberShare | DF-934 | [ ] G-05b [ ] MB-05·MB-06 배포 |
| 4 | lidarBeta | DF-935 | [ ] G-07a [ ] 기기 능력 확인(NFR-13) [ ] 내부 트레이너만 |

- [ ] 개방 전 규칙 featureOn 조건이 운영에 배포돼 있다
- [ ] 개방 후 24시간 저장 실패·규칙 거부 로그 확인
- [ ] 끌 때의 영향(PRD §12.3 '끄면' 열)을 확인했다
```

## F. 롤백

| 상황(PRD §12.4) | 즉시 조치 | 명령·위치 |
|---|---|---|
| 비인가 열람·공유 노출 | memberShare off, 요약 revoked, 세션 폐기 | AD-07, revokeMemberSummary, 콘솔 토큰 폐기 |
| 판정 오류 | 이전 bodyChange 정책 재활성화 또는 비활성 | AD-04 |
| 저장 실패·유실 신고 | 트레이너 앱 배포 중지 | App Store Connect 테스트 그룹에서 빌드 만료 |
| 금지어 노출 | 문자열 핫픽스, 노출 요약 revoked | 핫픽스 PR, revokeMemberSummary |
| LiDAR 오해·실패율 급증 | lidarBeta off | AD-07 |
| 이관 오류 | 해당 플래그 off, MIG-11 | V1-11 롤백 절차 |
| 크래시 급증 | 영향 플래그 off, 출시 중지 | AD-07, App Store Connect |
| 규칙 배포 오류 | 직전 태그 규칙 재배포 | `git checkout rules-<직전 태그> -- firestore.rules storage.rules` 후 C절 실행 |

- v1 SOAP 쓰기 차단 규칙은 롤백하지 않는다(ADR-014, R-21).
- 롤백 후에는 버그 보고([V1-T13](BUG_REPORT.md))의 S1 사후 검토 절을 작성한다.

## 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: 배포 명령을 `firebase deploy --project dfetmanage --only …` 순서로 통일(R7, DEC-15) | — | 없음 |

# AI 에이전트 작업 지시서 템플릿

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-T08 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §0.2 근거 표기 규칙, §0.5 ID 체계, §6.0.3, §10.8 NFR-03·NFR-10, §12.5 |
| 관련 에픽·스토리 | 모든 에이전트 배정 스토리(agent/claude, agent/codex). 예시 DF-011 |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

- [사용법](#사용법)
- [작성 규칙](#작성-규칙)
- [템플릿](#템플릿)
- [예시: DF-011 static-guards](#예시-df-011-static-guards)
- [재실행 시 덧붙이는 절](#재실행-시-덧붙이는-절)
- [변경 이력](#변경-이력)

## 사용법

- 소유자는 이 지시서를 처음부터 쓰지 않는다. 목요일 다듬기에서 백로그 카드의 '에이전트 브리프' 절(아래 1·3·4·5·7절 요지)을 채우고, `node tool/backlog/brief.mjs DF-NNN [--sprint SNN] > brief.md`로 전체 지시서를 생성해 스토리 이슈에 **코멘트로** 붙인다. 월요일 계획에서 `--sprint`를 주어 다시 생성·확정하고 `agent/claude` 또는 `agent/codex` 라벨을 단다([V1-01 작업 지시서 규칙](../01_AGILE_WORKING_AGREEMENT.md#ai-에이전트-작업-흐름), ASM-01-17).
- 생성기가 채우는 절과 소유자가 카드에 쓰는 절:

| 절 | 채우는 쪽 | 원천 |
|---|---|---|
| 0 절대 규칙, 10 막혔을 때, 11 완료 보고 | 생성기(고정문) | 이 템플릿 |
| 2 추적 | 생성기 | 이슈 JSON `key`, `epic`, `phase`, `labels`(flag/), `trace` |
| 6 수용 기준 | 생성기 | 카드의 '수용 기준' 표(PRD AC 원문, AC-DF-NNN.k) |
| 8 검증 명령 | 생성기 | area별 기본 명령([V1-01 영역별 DoD](../01_AGILE_WORKING_AGREEMENT.md#완료-정의dod)) + 카드의 테스트 명령 |
| 9 브랜치·커밋·PR | 생성기 | 이슈 JSON `key`, `type`, `area`, 배정 에이전트 |
| 4 '같은 스프린트의 다른 에이전트 작업' | 생성기(`--sprint`) | 같은 Sprint의 agent/* 이슈와 그 카드의 수정 허용 경로 |
| 1 목표, 3 컨텍스트 팩, 4 수정 허용·금지 경로, 5 인터페이스 계약, 7 구현 메모 | 소유자(카드 '에이전트 브리프' 절) | 카드. 5절은 카드의 설계 절 링크로 대신할 수 있다 |

- 생성기가 없는 S01에는 소유자가 같은 규칙으로 손으로 조립한다.
- 이 지시서 전체가 에이전트에게 주는 프롬프트다. 에이전트 세션은 `main` 최신 커밋에서 새로 시작한다.
- 작업 흐름과 권한 경계는 [V1-01 AI 에이전트 작업 흐름](../01_AGILE_WORKING_AGREEMENT.md#ai-에이전트-작업-흐름)이 정본이다. 영역별 필독 목록(컨텍스트 팩)은 [V1-13](../13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md)에 있다.

## 작성 규칙

1. **완결성**: 에이전트가 질문 없이 끝낼 수 있어야 한다. 경로, 타입·함수 시그니처, JSON 예시, 테스트 명령을 구체적으로 적는다. "적절히", "필요하면" 같은 표현을 쓰지 않는다.
2. **범위 고정**: '수정 허용 경로'는 파일 또는 디렉터리 단위로 적는다. 목록 밖 파일을 고쳐야 하면 에이전트는 멈추고 보고한다.
3. **PRD는 절 단위로**: PRD 전체(3,834줄)를 읽히지 않는다. 필요한 절·ID만 링크한다.
4. **수용 기준은 원문 인용**: PRD AC와 AC-DF를 바꿔 쓰지 않고 그대로 옮긴다.
5. **이식 스토리**: 원본 `dfet:경로:줄`(보관 브랜치 tip 기준, DF-039)과 가져오지 않을 반례를 적는다.
6. **동시 작업 표시**: 같은 스프린트에 도는 다른 에이전트 스토리와 그 경로를 적어 충돌을 피하게 한다.

## 템플릿

````markdown
# 작업 지시서: [DF-NNN] <동사형 제목>

너는 D-FET Coach v1 저장소(TEhyeok/DFET_Coach, 트렁크 main)에서 **이 스토리 하나만** 구현하는 코딩 에이전트다.
결과물은 draft PR 하나와 이슈 완료 보고 하나다.

## 0. 절대 규칙
- 브랜치: `<claude|codex>/DF-NNN-<slug>`만 쓴다. main 푸시·병합·태그·자동 병합 금지.
- GitHub 이슈를 만들지 않는다. 라벨·마일스톤·Projects를 바꾸지 않는다.
- 비밀 파일(.env*, functions/.secret.local, GoogleService-Info.plist 값, 인증서, 키)과 output/·tmp/·내보내기·회원 데이터를 열거나 출력하지 않는다.
- 운영 Firebase 프로젝트(dfetmanage)를 가리키는 명령(firebase deploy, 이관 --apply 등)을 실행하지 않는다. 에뮬레이터와 합성 데이터만 쓴다.
- docs/PRD_V1.md를 수정하지 않는다. 고칠 점은 PR 본문 'PRD 수정 제안'에 적는다.
- 아래 '수정 허용 경로' 밖을 고쳐야 하면 멈추고 완료 보고의 '막힘'에 적는다.
- 새 의존성(npm, SPM, pub)을 추가하지 않는다(지시서가 허용한 것 제외).
- PRD가 모호하면 추측하지 말고 가장 보수적인 해석(숨김, 저장 안 함, 판정 안 함)을 택하고 'AS-DEV-후보'로 보고한다.

## 1. 목표
<1~3줄. 무엇이 가능해지는가. 사용자 관점 또는 시스템 관점>

## 2. 추적
- 스토리: DF-NNN (에픽 EP-NN, 단계 <P0|P1a|...>, 플래그 <없음|soapV2|...>)
- PRD: <F-..., AC-..., NFR-..., TR-..., R-..., MIG-...>
- 관련 ADR: <ADR-NNN>

## 3. 컨텍스트 팩(이 순서로 읽는다)
1. docs/v1/01_AGILE_WORKING_AGREEMENT.md — 'DoD' 절(공통 + <영역>)
2. docs/PRD_V1.md — §<절>(줄 <a-b>), §<절>
3. docs/v1/<명세 문서>.md — '<절 이름>'
4. docs/v1/adr/ADR-NNN-<...>.md
5. 참고 코드(읽기 전용): <dfet:경로:줄>, <bodypath:경로:줄>

## 4. 작업 범위
- 수정 허용 경로(생성·수정):
  - <path/to/file>
  - <path/to/dir/**>
- 읽기 전용 참고 경로:
  - <path>
- 금지 경로(열지도 않음): 비밀 파일, output/, tmp/, <그 밖>
- 같은 스프린트의 다른 에이전트 작업(건드리지 않음): DF-XXX(<경로>), DF-YYY(<경로>)

## 5. 인터페이스 계약
<타입·함수 시그니처, 필드 이름과 타입, JSON 예시, 규칙 스니펫, 화면 상태. 코드 블록으로>

## 6. 수용 기준(원문)
| ID | 기준 | 테스트 종류 | 테스트 위치·이름(작성할 것) |
|---|---|---|---|
| AC-... | <PRD 원문> | 단위 | <path>::<test name with AC ID> |
| AC-DF-NNN.1 | <추가 기준> | <종류> | <...> |

## 7. 구현 메모
- 원본: <dfet:경로:줄 — 가져올 것>
- 반례(가져오지 않음): <dfet:경로:줄 — 이유>
- 문자열: <카탈로그 위치, 금지어 주의>
- 데이터: <합성 픽스처 위치와 가상 회원>

## 8. 검증 명령(모두 통과해야 PR을 Ready로 올릴 수 있다)
```bash
<명령 1>
<명령 2>
```
- 로컬에서 못 돌리는 검증(macOS 전용 등)은 CI 결과 링크로 대신하고 보고에 적는다.

## 9. 브랜치·커밋·PR
- 브랜치: <claude|codex>/DF-NNN-<slug>
- 커밋 제목: <type>(<scope>): <요약>
- 커밋 footer:
  Refs: DF-NNN
  Trace: <PRD ID 목록>
- PR: draft로 열고 .github/pull_request_template.md를 모두 채운다. 본문 첫 줄 `Closes #<이슈 번호>`.

## 10. 막혔을 때
- 30분 이상 같은 오류가 반복되면 멈추고 보고한다(우회 구현 금지).
- 범위 밖 수정이 필요하면 멈추고 보고한다.
- 테스트를 끄거나 skip하지 않는다.

## 11. 완료 보고(이슈 코멘트, 이 형식 그대로)
## 완료 보고 DF-NNN
- 브랜치 / PR: <branch> / #<PR>
- 수용 기준: <ID>: 통과(<test name>) | <ID>: 수동 확인 필요(<사유>)
- 실행한 명령과 결과: `<cmd>` → pass (<n> tests)
- 수정한 경로: <목록> (허용 경로 안: 예/아니오)
- 가정(AS-DEV-후보): 없음 | <내용, 관련 PRD Q-/AS->
- PRD 수정 제안: 없음 | <내용>
- 남은 위험·후속(부채 후보): 없음 | <내용>
- 막힘: 없음 | <내용>
- 비밀·실데이터 접근: 없음
````

## 예시: DF-011 static-guards

아래는 P0 스토리 DF-011(S03)을 위 템플릿으로 채운 예다. 이 예시를 작성하면서 현재 코드에 이미 있는 위반을 확인했고, 그래서 **기준선 허용 목록**을 두게 했다(아래 '구현 메모').

````markdown
# 작업 지시서: [DF-011] static-guards.sh로 grep 불변식을 CI에 건다

너는 D-FET Coach v1 저장소(TEhyeok/DFET_Coach, 트렁크 main)에서 이 스토리 하나만 구현하는 코딩 에이전트다.
(0. 절대 규칙은 템플릿과 같다)

## 1. 목표
금지 패턴이 트레이너 앱과 회원 앱 코드에 새로 들어오면 PR이 실패하게 한다. 이미 있는 위반은 기준선 목록으로 고정하고, 목록은 줄어들기만 한다.

## 2. 추적
- 스토리: DF-011 (EP-01, P0, 플래그 없음)
- PRD: NFR-03, NFR-11, AC-SOAP-01.9, AC-SOAP-05.8, AC-VIZ-06.1, AC-LINK-03.3, §9.5 링크 정책
- 관련 ADR: ADR-001, ADR-007, ADR-016

## 3. 컨텍스트 팩
1. docs/v1/01_AGILE_WORKING_AGREEMENT.md — 'DoD' 공통, '문서' 영역
2. docs/PRD_V1.md — §10.8 NFR-03·NFR-11, §9.5 '설계 근거'(링크 정책), §6.4.6 옮기지 않을 반례
3. docs/v1/10_TEST_PLAN.md — CI job 'static-guards'
4. .github/workflows/ci.yml(현재 4 job 구조 확인용)

## 4. 작업 범위
- 수정 허용 경로:
  - tool/lint/static-guards.sh (신규)
  - tool/lint/static-guards.allow (신규, 기준선 허용 목록)
  - tool/lint/test/static-guards.test.sh (신규, 셸 테스트. 임시 디렉터리에 위반 파일을 만들어 실패 확인)
  - tool/lint/test/fixtures/static-guards/** (신규, 가드별 위반·정상 샘플)
  - .github/workflows/ci.yml (job `static-guards` 추가만. 기존 job 수정 금지)
- 읽기 전용 참고: lib/**, trainer_app/**, ios/Runner/AppDelegate.swift
- 같은 스프린트의 다른 에이전트 작업: DF-020·DF-021(firestore.rules), DF-037(functions/src/shared/**), DF-017(trainer_app/App/AppShell/**)

## 5. 인터페이스 계약
- 실행: `bash tool/lint/static-guards.sh` → 위반 0이면 exit 0, 아니면 위반을 `G<번호> <파일>:<줄> <패턴>` 형식으로 출력하고 exit 1.
- 옵션: `--list-rules`(규칙 목록 출력), `--update-baseline`은 **만들지 않는다**(기준선은 손으로만 줄인다).
- 가드(ID는 카드 DF-011 '가드 ID 목록'의 G1~G9와 같다. PRD ID 아님):

| 가드 | 대상 경로 | 금지 내용 | 근거 |
|---|---|---|---|
| G1 | `trainer_app/Packages/TrainerCore/Sources/` 전체, `trainer_app/Packages/TrainerKit/Sources/` 중 FirebaseData 제외, `trainer_app/App/` | Firebase 모듈 import | NFR-03 |
| G2 | lib/**, trainer_app/**, admin_web/app/**, admin_web/lib/** | 다운로드 URL(`getDownloadURL`, `downloadURL(`) 호출 | §9.5 링크 정책, AC-LINK-03.3 |
| G3 | trainer_app/** | 로컬 UUID 회원 키(`"member-` + UUID) | AC-LINK-03.3, §6.4.6 |
| G4 | trainer_app/** | native_ 문서 ID | AC-SOAP-01.9, §6.4.6 |
| G5 | trainer_app/** | 인라인 필기 필드 | AC-SOAP-01.9, §6.4.6 |
| G6 | lib/**, trainer_app/** | isSharedWithMember를 true로 쓰기 | AC-SOAP-05.8 |
| G7 | lib/**, trainer_app/** | tapback.co 도메인 | NFR-11 |
| G8 | `trainer_app/Packages/TrainerKit/Sources/FirebaseData/`, `trainer_app/Packages/TrainerCore/Sources/SyncEngine/` | print 호출 | NFR-06, NFR-10 |
| G9 | lib/** (회원 앱) | 원 기록 컬렉션 경로 문자열 | AC-VIZ-06.1 |

- 패턴(grep -E, 스크립트에 그대로 넣는다):

```bash
G1='^[[:space:]]*import[[:space:]]+Firebase'
G2='getDownloadURL|downloadURL\('
G3='"member-(\\\(|"[[:space:]]*\+)'
G4='native_\\\('
G5='[Ii]nkDataBase64|"drawingData"'
G6='isSharedWithMember[^A-Za-z]*true'
G7='tapback\.co'
G8='(^|[^A-Za-z_])print\('
G9="collection\\(['\"](soap_notes|postureAssessments|bodyCompositionRecords|circumferenceMeasurements|bodyScans)['\"]\\)"
```

- G3·G4·G5는 레거시의 실제 형태를 모두 잡아야 한다(카드 AC-DF-011.2). G3: Swift 문자열 보간 `"member-\(UUID().uuidString)"`(dfet:ios/Runner/AppDelegate.swift:7978, :8117)과 연결 `"member-" + …`. G4: `"native_\(…)"` 문서 ID(:3838). G5: 필기 키 `"inkDataBase64"`(:3858)와 `nativeInkDataBase64`(Flutter), `"drawingData"` 키. Swift 프로퍼티 선언 `let drawingData: Data`(따옴표 없음)는 잡지 않는다. 예외는 `LegacySoapView.swift`의 읽기 전용 키 이름뿐이다(카드 AC-DF-011.2).
- 기준선 파일(`tool/lint/static-guards.allow`) 형식(한 줄에 하나, 사유 필수):
  `<가드ID> <경로> # <사유>`(파일+가드 단위, 줄 번호 없음). 사유에 제거 스토리 DF-NNN 또는 Q-DEV-후보를 적는다.
- 기준선 항목은 **파일+가드** 단위로 매칭한다(줄 번호는 바뀌므로 쓰지 않는다). 기준선에 있는 파일이라도 **다른 가드** 위반은 실패다. 줄을 지우거나 사유 없는 줄을 넣으면 실패다(카드 AC-DF-011.5).

## 6. 수용 기준(원문)
| ID | 기준 | 테스트 종류 | 테스트 위치·이름 |
|---|---|---|---|
| DF-011 acSummary | Feature의 import Firebase, getDownloadURL, member-+UUID, native_ ID, 인라인 필기, isSharedWithMember: true, tapback.co, FirebaseData print( 0건 | 스크립트 테스트 | tool/lint/test/static-guards.test.sh::G1~G9 위반 샘플(`tool/lint/test/fixtures/static-guards/G<n>_violation.*`)이 각각 해당 G번호로 실패(TC-DF011-01) |
| AC-DF-011.1 | Given `trainer_app/Packages/TrainerCore/Sources/` 전체와 `trainer_app/Packages/TrainerKit/Sources/` 가운데 `FirebaseData`를 뺀 모든 타깃, 그리고 `trainer_app/App/` When `import Firebase`로 시작하는 줄을 찾으면 Then 0건이다 | 스크립트 테스트 | ...::G1_firebase_import |
| AC-DF-011.2 | Given `trainer_app/**` When G2~G7 패턴을 찾으면 Then 모두 0건이다. 예외는 `LegacySoapView.swift`의 읽기 전용 키 이름뿐이다. 레거시 실제 형태: `avatarSeed: "member-\(UUID().uuidString)",`(AppDelegate.swift:7978 형태)와 `"member-" + UUID().uuidString`(G3), `"id": "native_\(seed)_\(date)",`(:3838 형태, G4), `"inkDataBase64": drawing.dataRepresentation().base64EncodedString(),`(:3858 형태, G5)는 위반이고, `let drawingData: Data`, `"memberId"`, `native_trainer_home`은 통과 | 스크립트 테스트 | ...::G2_to_G7_trainer_app, ...::G3_G4_G5_legacy_forms |
| AC-DF-011.3 | Given `Sources/FirebaseData/**`, `Sources/SyncEngine/**` When `print(`를 찾으면 Then 0건이다 | 스크립트 테스트 | ...::G8_print |
| AC-DF-011.4 | Given `lib/**` When 원 기록 컬렉션 문자열과 `getDownloadURL`을 찾으면 Then 결과가 `tool/lint/static-guards.allow`의 기준선 항목과 정확히 같다. 새 파일에서 발견되면 실패한다 | 스크립트 테스트 | ...::baseline_matches, ...::new_violation_fails(TC-DF011-02) |
| AC-DF-011.5 | Given 허용 목록 When 한 줄을 지우거나 사유 없는 줄을 추가하면 Then 실패한다. 모든 줄은 `<가드ID> <경로> # <사유>` 형식이어야 한다 | 스크립트 테스트 | ...::allow_line_removed_fails, ...::allow_line_without_reason_fails |
| TC-DF011-03 | CI job `static-guards`가 pull_request에서 실행되고 통과한다 | CI | PR 체크 |

## 7. 구현 메모
- 현재 코드에 이미 있는 위반(2026-09-24 작업 트리, 기준선에 넣을 것):
  - G9 `lib/services/firestore_service.dart:19` soap_notes → 제거 DF-315(MB-03·04를 memberSummaries로 교체). 이 파일은 Flutter 트레이너 셸도 쓰므로 DF-387까지 남을 수 있다.
  - G6 `lib/widgets/shells/trainer_shell.dart:565` → 제거 DF-387(MIG-09, Flutter 트레이너 폴백 제거)
  - G5 성격의 `nativeInkDataBase64`는 lib/에도 있다(`lib/widgets/shells/trainer_shell.dart:505`, `lib/screens/trainer/trainer_soap_notes_screen.dart:329`). G5 대상은 trainer_app/**뿐이므로 기준선 불필요. 제거는 DF-387.
  - G2 `lib/screens/create_request_screen.dart:100`(requests/ 영상), `lib/services/community_service.dart:45`(posts/ 이미지) → PRD §9.5는 '어느 앱도 쓰지 않는다'이지만 이 두 기존 경로를 없애는 스토리가 백로그에 없다. 기준선에 `Q-DEV-후보`로 넣고 완료 보고에 적는다(카드 ASM-P0-25).
  - 기준선 줄 예(파일+가드 단위, 줄 번호 없음): `G9 lib/services/firestore_service.dart # soap_notes 직접 조회. 제거 DF-315`, `G2 lib/services/community_service.dart # 기존 커뮤니티 업로드. §9.5 링크 정책과 충돌, Q-DEV로 소유자 결정 대기`
- Runner(`ios/Runner/AppDelegate.swift`)는 동결 대상이라 검사하지 않는다(tapback.co :6197 포함, DF-387에서 제거).
- `trainer_ios/`는 검사하지 않는다(DF-142에서 삭제).
- trainer_app/이 아직 없으면(DF-008 병합 전) 해당 규칙은 '대상 없음'으로 통과한다.
- `rg`(ripgrep)가 없으면 `grep -RnE`로 대체한다. 러너 기본 도구만 쓴다.
- grep은 `grep -rnE --include=*.swift --include=*.dart --include=*.ts --include=*.tsx`로 제한하고 `*/generated/*`, `*/build/*`, `*/.dart_tool/*`는 제외한다.

## 8. 검증 명령
```bash
bash tool/lint/static-guards.sh
bash tool/lint/test/static-guards.test.sh
bash -n tool/lint/static-guards.sh tool/lint/test/static-guards.test.sh
```

## 9. 브랜치·커밋·PR
- 브랜치: codex/DF-011-static-guards
- 커밋 제목: chore(ci): add static guard invariants
- footer: Refs: DF-011 / Trace: NFR-03, NFR-11, AC-SOAP-01.9, AC-SOAP-05.8, AC-VIZ-06.1, AC-LINK-03.3

(10·11은 템플릿과 같다)
````

## 재실행 시 덧붙이는 절

소유자가 변경을 요청하면 지시서 끝에 아래 절을 붙여 같은 에이전트에게 다시 준다. 2회 반려되면 스토리를 나누거나 소유자가 직접 처리한다(V1-01).

````markdown
## 12. 검토 피드백(<회차>차, <YYYY-MM-DD>)
- 반려 사유: <DoD 항목 번호 D1~D12 또는 영역 DoD 항목>
- 고칠 것:
  1. <구체적 수정, 파일·함수 단위>
- 고치지 말 것: <이미 승인된 부분>
- 추가 검증: <명령>
````

## 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: ASM-17→ASM-01-17(R10), DF-011 예시를 P0 카드 정본에 맞춤(R4 TrainerCore·TrainerKit 경로, 가드 G1~G9, `static-guards.allow`·`static-guards.test.sh`, 기준선 `<가드ID> <경로> # <사유>`, AC-DF-011.1~.5) | — | 없음 |

# 마이그레이션 런북

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-11 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §11(MIG-01~MIG-11 정본), D2, D9, D13, §0.2(이식 기준선), §9.3(SOAP v2), §9.4 R-21, §9.5(soapInk), §9.7(백업·리전), §10.4.3, §12.3, §12.4 |
| 관련 에픽·스토리 | EP-00, EP-13, EP-06, EP-22, EP-19 / DF-901, DF-930, DF-907, DF-030, DF-031, DF-028, DF-029, DF-911, DF-100, DF-931, DF-924, DF-138, DF-142, DF-330, DF-323, DF-387, DF-926 |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [범위와 원칙](#1-범위와-원칙)
2. [공통 준비](#2-공통-준비)
3. [MIG-01 미커밋 정리](#3-mig-01-미커밋-정리)
4. [MIG-02 운영 데이터 실사](#4-mig-02-운영-데이터-실사)
5. [MIG-03 soap_notes v2 이관](#5-mig-03-soap_notes-v2-이관)
6. [MIG-04 diagnosis와 규제 문구](#6-mig-04-diagnosis와-규제-문구)
7. [MIG-05 isSharedWithMember 레거시 처리](#7-mig-05-issharedwithmember-레거시-처리)
8. [MIG-06 인라인 필기 이전](#8-mig-06-인라인-필기-이전)
9. [MIG-07 로컬 UUID SOAP 초안](#9-mig-07-로컬-uuid-soap-초안)
10. [MIG-08 trainerWorkspaces 폐기](#10-mig-08-trainerworkspaces-폐기)
11. [MIG-09 Runner 내장 트레이너 동결과 제거](#11-mig-09-runner-내장-트레이너-동결과-제거)
12. [MIG-10 BodyPath 기존 기록](#12-mig-10-bodypath-기존-기록)
13. [MIG-11 롤백 계획](#13-mig-11-롤백-계획)
14. [에뮬레이터 리허설과 migrations CI](#14-에뮬레이터-리허설과-migrations-ci)
15. [가정·충돌·열린 질문](#15-가정충돌열린-질문)
16. [변경 이력](#16-변경-이력)

---

## 1 범위와 원칙

### 1.1 이 문서가 하는 일

- PRD §11의 MIG-01~MIG-11을 **소유자가 그대로 따라 실행할 수 있는 절차**로 옮긴다. 각 MIG마다 선행 조건, 실행 명령, 검증 쿼리, 롤백, 책임자, 증빙을 적는다.
- 매핑표·수용 기준의 정본은 PRD §11이다. 목표 스키마는 PRD §9.3과 [V1-05 §5](05_DATA_MODEL_AND_RULES.md#5-soap-스키마-v2), 규칙 코드는 [V1-05 §7](05_DATA_MODEL_AND_RULES.md#7-firestore-보안-규칙-초안)이다. 이 문서는 그 내용을 되풀이하지 않고 **실행 순서와 스크립트 설계**만 더한다.
- 이관 스크립트 구현 스토리(DF-030, DF-031, DF-100)의 수용 기준은 [V1-02 백로그](02_PRODUCT_BACKLOG.md)가 정본이다. 이 문서의 §5 설계는 그 스토리들이 따라야 할 **실행 계약**(CLI, 보고서, 필드 단위 변환, 롤백 근거)이다.
- 실행 기록 양식은 [V1-T10 이관 실행 기록](templates/MIGRATION_RUN_RECORD.md), 게이트 증빙 양식은 [V1-T07](templates/GATE_EVIDENCE.md)이다.

### 1.2 원칙(PRD §11 ①~⑤를 실행 규칙으로)

| # | PRD 원칙 | 이 런북의 실행 규칙 |
|---|---|---|
| ① | 운영 데이터 실사 먼저 | MIG-03~08의 운영 쓰기는 MIG-02 보고서(DF-907)가 있어야 시작한다. 보고서에서 0건인 하위 작업은 '해당 없음'으로 기록하고 건너뛴다(§4.6) |
| ② | 쓰기는 dry-run과 보고서 뒤에만 | 모든 스크립트는 기본이 dry-run이다. `--apply`는 직전 dry-run 보고서의 `runId`를 `--run-id`로 다시 넣어야 동작한다(§2.4) |
| ③ | 원본 보존, 모든 작업 멱등 | 이관 문서에는 원문을 `legacy`에 남기고, 같은 명령을 두 번 실행하면 두 번째는 쓰기 0건이다. 운영 적용 전 관리형 내보내기(managed export)를 2회 받는다(§5.8) |
| ④ | 실데이터 열람 최소화 | 보고서는 수량·분류만 담는다. 문서 ID, uid, 이름, 이메일, 메모, 지표 값, 필기, 파일 경로는 출력·기록하지 않는다. 보고서 원본은 저장소에 커밋하지 않는다 |
| ⑤ | 이관은 소유자가 Admin SDK로 | 운영 대상(`dfetmanage`) 명령은 소유자만 실행한다. AI 에이전트는 스크립트를 만들고 에뮬레이터로만 검증한다([V1-01](01_AGILE_WORKING_AGREEMENT.md) 에이전트 금지 행동) |

### 1.3 역할

| 역할 | 하는 일 | 하지 않는 일 |
|---|---|---|
| 소유자(CJH) | MIG-01 git 정리, 운영 내보내기, 운영 dry-run·apply, 규칙 배포, 공지, 트레이너 기기 확인, 증빙 기록 | — |
| AI 에이전트(Claude/Codex) | 스크립트·테스트·픽스처 작성(DF-030, DF-031, DF-100, DF-138, DF-330), 에뮬레이터 리허설, PR에 에뮬레이터 보고서 첨부 | `--project dfetmanage` 실행, `gcloud`/`firebase deploy`, 비밀 파일 열람, 운영 보고서 열람, git 병합·푸시 to main, 이슈 생성 |

### 1.4 일정 요약

달력은 [V1-03](03_RELEASE_AND_SPRINT_PLAN.md)이 정본이다. 게이트가 달력보다 우선한다.

| MIG | 무엇 | 스크립트·코드 스토리 | 소유자 실행 | 스프린트(잠정) |
|---|---|---|---|---|
| MIG-01 | 미커밋 87개 정리, G-01 | — | DF-901 | S01, 2026-09-29(화) 12:00까지 병합(약 1.5일, V1-01 ASM-01-18, SPRINT_01 ASM-S01-01) |
| MIG-09(동결) | Runner 트레이너 동결 선언 | — | DF-930 | S01 |
| MIG-04(문구) | 출시 앱 규제 문구 수정 | DF-028, DF-029 | DF-911(스토어 제출) | S04 |
| MIG-02 | 운영 실사(읽기 전용) | DF-030 | DF-907 | S04 |
| MIG-03~06 | dry-run 도구, 에뮬레이터 리허설 | DF-031 | — | S05 |
| MIG-11 | 적용→롤백→재적용 리허설, v1 차단 스위치 PR | DF-100 | — | S08 |
| MIG-03~06 적용, MIG-07 기기 확인 시작 | 운영 적용 | — | DF-924(선행 DF-931 규칙 배포) | S09 |
| MIG-08(1) | 신규 쓰기 중단(P1a 전환, PRD §11 MIG-08) | DF-100 스위치 PR에 포함((나) 경로일 때만 규칙 hunk) | DF-924 규칙 배포 때 함께 배포·확인 | S08 PR → S09 배포 |
| MIG-08(2~3) | 1회용 '이전 작업공간 가져오기'(표시명만) | DF-138 | 트레이너 확인 기록 | S14 |
| (trainer_ios 정리) | `trainer_ios/` 삭제, 태그 보존 | DF-142 | 태그 푸시 | S13 |
| MIG-08(4) | trainerWorkspaces 제거 | DF-330 | 내보내기·삭제 실행 | S25-S26 |
| MIG-10 | BodyPath 기존 기록 가져오기 | DF-323 | 트레이너 확인 | S25-S26 |
| MIG-09(제거) | Runner 트레이너 제거 | DF-387 | 동등성 검수·릴리스 | S30-S32 |

---

## 2 공통 준비

### 2.1 도구와 권한(소유자 기기)

| 항목 | 기준 | 확인 명령 |
|---|---|---|
| Node | 22.x(functions와 같음) | `node -v` |
| firebase-tools | 최신 안정판 | `firebase --version` |
| Java | 21(에뮬레이터) | `java -version` |
| gcloud CLI | 최신 | `gcloud --version` |
| gh CLI | 로그인됨 | `gh auth status` |
| jq | 1.6+ | `jq --version` |
| 운영 권한 | 소유자 Google 계정이 `dfetmanage`의 Owner 또는 `roles/datastore.importExportAdmin` + `roles/datastore.user` + `roles/storage.admin` + `roles/firebaseauth.viewer` | `gcloud projects get-iam-policy dfetmanage --flatten=bindings --filter="bindings.members:user:$(gcloud config get-value account)" --format="value(bindings.role)"` |
| 자격 증명 | **애플리케이션 기본 자격 증명(ADC)만 쓴다.** 서비스 계정 키 파일(`functions/service-account-key.json`)은 열거나 쓰지 않는다 | `gcloud auth application-default login` |
| 디스크 | FileVault 켜짐(보고서·백업이 로컬에 잠시 머문다) | `fdesetup status` |

### 2.2 대상 선택과 가드(`functions/scripts/migrations/lib/target.js`, DF-030)

모든 이관 스크립트는 같은 가드 모듈을 쓴다. 규칙은 DF-030·DF-100 수용 기준을 합친 것이다.

| 인자 | 의미 | 규칙 |
|---|---|---|
| `--emulator` | 에뮬레이터 대상 | `FIRESTORE_EMULATOR_HOST`(필수), `FIREBASE_STORAGE_EMULATOR_HOST`가 있어야 한다(`FIREBASE_AUTH_EMULATOR_HOST`는 있으면 함께 쓴다). 프로젝트는 `dfet-e2e` 고정([V1-10 §4.2](10_TEST_PLAN.md#42-firebase-에뮬레이터) 프로젝트 ID 표) |
| `--project dfetmanage` | 운영 대상 | 에뮬레이터 환경변수가 하나라도 있으면 거부(종료 코드 2). 읽기 전용 스크립트는 `--confirm-readonly-prod`를 함께 요구 |
| `--apply` | 쓰기 모드 | 없으면 dry-run. 운영에서는 `--run-id <직전 dry-run runId>`, `--report-dir <dir>`(그 runId의 dry-run 보고서가 있어야 함), `--i-am-owner`를 모두 요구 |
| `--run-id` | 실행 식별자 | dry-run이 만든다. 형식 `migNN-YYYYMMDDTHHMMZ-<4hex>`(예: `mig03-20261124T1100Z-7c2e`) |
| `--backup-confirmed <gs://…>` | 관리형 내보내기 경로 | 경로 아래 `*.overall_export_metadata` 객체가 있는지 **읽기로** 확인한 뒤에만 인라인 필기 제거 단계를 연다(§8) |
| `--out`/`--report-dir` | 보고서 저장 위치 | 저장소 밖 경로만 허용. 저장소 루트 아래면 거부 |

종료 코드: `0` 정상, `1` 실행 중 오류(부분 적용 가능, 보고서에 `failed` 수량), `2` 인자·가드 거부(쓰기 0건), `3` 검증 불일치(`--verify` 모드).

### 2.3 스크립트 배치(정본 이름)

```
functions/scripts/migrations/
├─ lib/
│  ├─ target.js              # §2.2 가드(DF-030)
│  ├─ report.js              # 보고서 직렬화·허용 키 검사(수량만)
│  ├─ legacyMapping.js       # 순수 변환 함수(DF-031, §5.4)
│  └─ inkMover.js            # MIG-06 업로드·해시 대조(DF-031, §8)
├─ mig02_inventory.js        # MIG-02 읽기 전용 실사(DF-030)
├─ mig03_06.js               # MIG-03·04(데이터)·05·06 실행기(DF-031, DF-100)
├─ mig03_06_rollback.js      # MIG-11 soap_notes 롤백(DF-031, DF-100)
└─ mig08_remove_trainer_workspaces.js   # MIG-08(4) 제거(DF-330)
functions/test/migrations/   # 에뮬레이터 e2e(npm run test:migrations)
functions/test/unit/legacy-mapping.test.js
tool/lint/no-writes.mjs      # MIG-02 스크립트 쓰기 호출 0건 검사
```

`functions/package.json` 추가 스크립트(DF-031): `"test:migrations": "node --test --test-concurrency=1 \"test/migrations/**/*.test.js\""`.

### 2.4 보고서 공통 형식

모든 보고서는 JSON 한 개다. `lib/report.js`가 허용 키 밖 값을 넣으면 예외를 던진다(TC: 보고서에 문자열 값은 `mig`, `runId`, `mode`, `target`, `startedAt`, `finishedAt`, `scriptSha`, 분류 키 이름만 허용).

```json
{
  "mig": "MIG-03",
  "reportVersion": 1,
  "runId": "mig03-20261124T1100Z-7c2e",
  "mode": "dry-run",
  "target": "dfetmanage",
  "scriptSha": "<git rev-parse HEAD 앞 12자리>",
  "startedAt": "2026-11-24T11:00:03Z",
  "finishedAt": "2026-11-24T11:02:41Z",
  "counts": { }
}
```

- 파일명: `<report-dir>/<runId>.<mode>.json`. 보고서는 저장소 밖 `~/dfet_mig_reports/`에 두고, V1-T10 기록에는 **수량만 옮겨 적는다.**
- 보고서 안의 한글 키(`작성 중`, `통증` 등)는 레거시 **분류 키**다. 내용이 아니다.

### 2.5 백업 버킷(소유자, 최초 1회, S08까지)

관리형 내보내기는 Blaze 요금제와 Firestore 데이터베이스와 **같은 위치**의 버킷이 필요하다(PRD §9.7 백업·리전, G-09 확인 항목).

```bash
gcloud config set project dfetmanage
LOC=$(gcloud firestore databases describe --database='(default)' --format='value(locationId)')
echo "$LOC"                              # V1-T10에 기록(G-09 리전 증빙과 같은 값)
gcloud storage buckets create gs://dfetmanage-mig-backups \
  --location="$LOC" --uniform-bucket-level-access --public-access-prevention
# 90일 뒤 자동 삭제(ASM-11-09). 보존 기간은 처리방침(G-09)에 적는다.
cat > /tmp/mig-lifecycle.json <<'JSON'
{"rule":[{"action":{"type":"Delete"},"condition":{"age":90}}]}
JSON
gcloud storage buckets update gs://dfetmanage-mig-backups --lifecycle-file=/tmp/mig-lifecycle.json
rm /tmp/mig-lifecycle.json
```

- 버킷 IAM은 소유자 계정과 Firestore 서비스 에이전트(`service-<번호>@gcp-sa-firestore.iam.gserviceaccount.com`, 내보내기 쓰기)만 둔다.
- 내보내기는 컬렉션 단위로 받는다(`--collection-ids`). `users`처럼 이관과 무관한 컬렉션은 받지 않는다(원칙 ④).

---

## 3 MIG-01 미커밋 정리

| 항목 | 내용 |
|---|---|
| PRD | §11.2, D13, G-01, RISK-04 |
| 스토리 | DF-901(owner-action, S01 월~화 12:00 병합. 새 경로 에이전트 작업은 먼저 시작 가능, 병합은 DF-901 뒤), 후속 DF-930(동결 선언), DF-902(라벨·마일스톤) |
| 책임자 | 소유자만. 에이전트 브랜치는 이 절차가 끝나고 `main`이 갱신된 뒤에 연다 |
| 완료 기준(G-01) | ① 분류표(§3.3) ② 보관 브랜치 `archive/trainer-ui-2026-09`와 tip 해시 ③ A 병합 PR의 CI 4 job(flutter, functions-and-rules, admin-web, ios-no-codesign) 초록 ④ `main`에 B 코드 없음(#4 예외는 기록) ⑤ 자격 증명 미스테이징 확인 ⑥ 작업 트리 전체 보존본 |

### 3.1 현황 스냅샷(2026-09-24 조사, 읽기 전용)

아래는 `git status --porcelain`, `git diff --stat`, 파일별 diff를 직접 열어 확인한 사실이다.

| 항목 | 값 |
|---|---|
| 현재 브랜치 | `feature/integrated-care-2026`, HEAD `d841412`(2026-08-10 `feat: unify clinical evidence experience`) |
| `main` | `3ef5b79`(초기 커밋 1개). `origin/main`과 같다 |
| 기능 브랜치 커밋 | `main` 대비 **18개 커밋이 원격에 없다**(원격 브랜치 `origin/feature/integrated-care-2026` 없음). 2026-08-02~08-10 작업 전체가 이 로컬 저장소에만 있다 |
| 미커밋 항목 | porcelain 88줄 = PRD가 센 87개 + 새 `docs/PRD_V1.md`. 수정 59개, 추적 안 됨 29줄(디렉터리 `output/`, `tmp/` 포함) |
| 수정 규모 | 59개 파일 +3,052/−1,260(`ios/Runner/AppDelegate.swift` +975/−118) |
| 무시되는 비밀 | `functions/.secret.local`, `functions/service-account-key.json` 둘 다 존재하고 `git check-ignore`로 무시됨을 확인. 단 `.secret.local` 무시 규칙은 **미커밋 `.gitignore` 변경**(`.gitignore:50`)에만 있다 |
| 원격 저장소 공개 범위 | `gh repo view TEhyeok/DFET_Coach` 결과 **PUBLIC**(§3.4 0단계에서 결정 필요) |
| 무시되는 로그·빌드물 | `build/`, `build_debug.log`, `build_error.log`, `build_log.txt`, `flutter_build_err.log`, `firestore-debug.log`, `functions/*-debug.log`, `ios/pod_install.log`, `ios_backup/`, `.firebase/` 등. 이미 무시되므로 조치 없음(h 분류) |

> 줄 번호 주의: PRD의 `dfet:ios/Runner/AppDelegate.swift` 줄 번호는 작업 트리(9,657줄) 기준이다. 이 절차를 마치면 **`main`의 AppDelegate는 HEAD 판(8,800줄)**이 되고, 작업 트리 판은 보관 브랜치 tip에만 남는다. 그래서 규제 수정(DF-028)은 `main` 기준 줄 번호로, 이식(DF-039 이후)은 보관 브랜치 tip 기준 줄 번호로 읽는다(§6.2 대응표).

### 3.2 분류 기준

PRD §11.2의 A·B·C에 커밋 묶음 (a)~(h)를 대응시켰다.

| PRD 분류 | 묶음 | 처리 | 기준 |
|---|---|---|---|
| A | (a) 보안·규칙 | `main` 병합 | 규칙 강화, 규칙 테스트 중 A 부분 |
| A | (b) Functions·백엔드 | `main` 병합 | callable 어댑터, 탈퇴, 커뮤니티 callable, 임상 수집 수정, 단위 테스트 |
| A | (c) 테스트·CI | `main` 병합 | CI e2e job, e2e 테스트, `.gitignore`, README 실행 안내 |
| A | (d) admin_web | `main` 병합 | 신규 페이지·API, 기존 화면 수정 |
| A(확장) | (e) 회원 앱 | `main` 병합 | PRD 표의 A 목록에 회원 앱 UI가 이름으로 없으나 B(트레이너 UI)·C(내용 미확인)에 해당하지 않으므로 A로 본다(ASM-11-01) |
| A | (g) 문서 | `main` 병합(0단계 결정에 따름) | PRD, 감사 보고서, 기능 명세 |
| B | (f) 트레이너 UI | `archive/trainer-ui-2026-09`에만 커밋, 병합 금지 | AppDelegate 확장, TrainerShell 채널·Flutter 폴백, trainerWorkspaces 서비스·규칙·테스트 |
| C | (h') 내용 미확인 | 커밋 보류 | `output/`, `tmp/`, `tool/*.py` 7개 |
| — | (h) 커밋 금지 | 이미 무시됨 | 비밀, 로그, 빌드물 |

### 3.3 전체 분류표(porcelain 88줄)

커밋 ID(C00~C13, B01)는 §3.4의 커밋 계획을 가리킨다. `+/-`는 `git diff --numstat`, 추적 안 된 파일은 줄 수.

**(c) 테스트·CI — 먼저 커밋**

| # | 상태 | 경로 | 규모 | 분류 | 커밋 | 근거 |
|---|---|---|---|---|---|---|
| 1 | M | `.gitignore` | +1 | A(c) | C00 | `functions/.secret.local` 무시 추가. **다른 커밋보다 먼저** 커밋해야 비밀이 스테이징될 여지가 없다 |
| 2 | M | `.github/workflows/ci.yml` | +2 | A(c) | C04 | functions e2e 단계. 합성 키 `INGEST_HMAC_KEYS={"e2e":"e2e-secret"}`는 테스트용 가짜 값 |
| 3 | M | `README.md` | +4 | A(c) | C04 | e2e 실행 안내 |
| 4 | ?? | `functions/test/clinical-emulator-e2e.js` | 143줄 | A(c) | C04 | e2e 테스트(합성 키만 사용, 실데이터 없음 확인) |

**(a) 보안·규칙**

| # | 상태 | 경로 | 규모 | 분류 | 커밋 | 근거 |
|---|---|---|---|---|---|---|
| 5 | M | `firestore.rules` | +43/−6 | **혼재** A(a)+B(f) | C01 / B01 | posts 강화(작업 트리 :163-195)는 A. trainerWorkspaces 블록(작업 트리 :112-136)은 B. §3.5 |
| 6 | M | `functions/test/firestore-rules.test.js` | +79 | **혼재** A(a)+B(f) | C01 / B01 | posts 시드(:51-54)·`community integrity boundaries`(:209-224)는 A. `trainer workspace boundaries`(:151-207)는 B |

**(b) Functions·백엔드**

| # | 상태 | 경로 | 규모 | 분류 | 커밋 | 근거 |
|---|---|---|---|---|---|---|
| 7 | M | `functions/index.js` | +194/−21 | A(b) | C02 | v2 onCall 어댑터(작업 트리 :32-48), `deleteOwnAccount`(:378-), `toggleCommunityLike`, `addCommunityComment`. trainerWorkspaces 관련 코드 없음 확인 |
| 8 | M | `functions/package.json` | +2/−1 | A(b) | C02 | `test:e2e` 스크립트, firebase-functions ^7.3.2 |
| 9 | M | `functions/package-lock.json` | +398/−378 | A(b) | C02 | 위 의존성 잠금 |
| 10 | M | `functions/src/clinical/ingestion.js` | +21/−15 | A(b) | C03 | 수집 수정 |
| 11 | M | `functions/src/clinical/scoring.js` | +7 | A(b) | C03 | 점수 수정 |
| 12 | M | `functions/test/clinical.test.js` | +21 | A(b) | C03 | 위 단위 테스트 |

**(d) admin_web**

| # | 상태 | 경로 | 규모 | 분류 | 커밋 |
|---|---|---|---|---|---|
| 13 | M | `admin_web/app/(console)/clinical/ingestions/page.tsx` | +21/−2 | A(d) | C05 |
| 14 | M | `admin_web/app/(console)/clinical/jobs/page.tsx` | +9/−1 | A(d) | C05 |
| 15 | M | `admin_web/app/(console)/content/page.tsx` | +5/−2 | A(d) | C05 |
| 16 | M | `admin_web/app/(console)/requests/page.tsx` | +2/−2 | A(d) | C05 |
| 17 | M | `admin_web/app/(console)/users/page.tsx` | +2/−1 | A(d) | C05 |
| 18 | M | `admin_web/app/api/admin/requests/route.ts` | +20/−3 | A(d) | C05 |
| 19 | M | `admin_web/app/globals.css` | +7 | A(d) | C05 |
| 20 | M | `admin_web/components/console-shell.tsx` | +2 | A(d) | C05 |
| 21 | M | `admin_web/components/content-editor.tsx` | +37/−14 | A(d) | C05 |
| 22 | M | `admin_web/components/ingestion-form.tsx` | +21/−11 | A(d) | C05 |
| 23 | M | `admin_web/components/request-status-editor.tsx` | +6/−1 | A(d) | C05 |
| 24 | ?? | `admin_web/app/(console)/admins/` (`page.tsx` 22줄) | 신규 | A(d) | C05 |
| 25 | ?? | `admin_web/app/(console)/analytics/` (`page.tsx` 51줄) | 신규 | A(d) | C05 |
| 26 | ?? | `admin_web/app/(console)/users/[uid]/` (`page.tsx` 103줄) | 신규 | A(d) | C05 |
| 27 | ?? | `admin_web/app/api/admin/approvals/` (`route.ts` 69줄) | 신규 | A(d) | C05 |
| 28 | ?? | `admin_web/app/evidence/` (`ingestion/page.tsx` 48줄) | 신규 | A(d) | C05 |
| 29 | ?? | `admin_web/components/admin-approval-actions.tsx` | 37줄 | A(d) | C05 |
| 30 | ?? | `admin_web/components/request-resolution-editor.tsx` | 68줄 | A(d) | C05 |

`users/[uid]/page.tsx:30`은 `soap_notes where memberId == uid`로 건수를 센다. PRD §9.3 호환 기간(`memberId` 병기)의 근거이므로 그대로 둔다.

**(e) 회원 앱**

| # | 상태 | 경로 | 규모 | 분류 | 커밋 | 비고 |
|---|---|---|---|---|---|---|
| 31 | M | `pubspec.yaml` | +1 | A(e) | C06 | `cloud_functions: 6.0.2` |
| 32 | M | `pubspec.lock` | +24 | A(e) | C06 | |
| 33 | M | `ios/Podfile.lock` | +24 | A(e) | C06 | cloud_functions pod |
| 34 | M | `macos/Flutter/GeneratedPluginRegistrant.swift` | +2 | A(e) | C06 | 생성물 |
| 35 | M | `lib/services/community_service.dart` | +90/−91 | A(e) | C07 | 좋아요·댓글을 callable로 |
| 36 | M | `lib/models/community/post.dart` | +3/−2 | A(e) | C07 | |
| 37 | ?? | `lib/models/community/community_comment.dart` | 29줄 | A(e) | C07 | |
| 38 | ?? | `lib/screens/community/post_detail_screen.dart` | 338줄 | A(e) | C07 | |
| 39 | M | `lib/screens/community/create_post_screen.dart` | +1/−1 | A(e) | C07 | |
| 40 | M | `lib/widgets/community/post_card.dart` | +8/−2 | A(e) | C07 | |
| 41 | M | `lib/screens/settings_screen.dart` | +87/−16 | A(e) | C08 | `deleteOwnAccount`(asia-northeast3) 호출, 탈퇴 시 `isTrainerGuestModeProvider` 초기화(기존 provider, HEAD `lib/router/app_router.dart:34`) |
| 42 | M | `lib/screens/subscription_screen.dart` | +120/−442 | A(e) | C08 | |
| 43 | M | `lib/services/payment_service.dart` | +6/−4 | A(e) | C08 | 서버 영수증 검증 전 권한 부여 중단(보안 수정) |
| 44 | ?? | `test/subscription_gate_test.dart` | 22줄 | A(e) | C08 | |
| 45 | ?? | `lib/screens/notification_center_screen.dart` | 306줄 | A(e) | C09 | |
| 46 | M | `lib/router/app_router.dart` | +19/−2 | A(e) | C09 | `/home/notifications`, `/home/myPage/requests`. `/trainer` 라우트(:114)는 기존 그대로 |
| 47 | M | `lib/widgets/shells/ios_shell.dart` | +7/−20 | A(e) | C09 | |
| 48 | M | `lib/widgets/shells/material_shell.dart` | +5/−2 | A(e) | C09 | |
| 49 | M | `lib/widgets/shells/adaptive_home_shell.dart` | +1/−3 | A(e) | C09 | |
| 50 | M | `lib/screens/tickets.dart` | +9/−2 | A(e) | C09 | |
| 51 | M | `lib/screens/create_request_screen.dart` | +4/−12 | A(e) | C09 | 규제 문구 :150은 DF-029 대상(이 커밋에서 고치지 않음) |
| 52 | M | `lib/services/firestore_service.dart` | +75 | **혼재** A(e)+B(f) | C10 / B01 | hydration(:32-47)은 A. `_trainerWorkspacesCollection`(:21-23)·`load/saveTrainerWorkspace`(:675-729)는 B |
| 53 | M | `lib/screens/dashboard.dart` | +63/−7 | A(e) | C10 | 수분 기록 연동 |
| 54 | M | `lib/widgets/hydration_dialog.dart` | +11/−4 | A(e) | C10 | |
| 55 | M | `lib/widgets/protein_foods_dialog.dart` | +20/−16 | A(e) | C10 | |
| 56 | M | `lib/widgets/breakfast_menu_dialog.dart` | +20/−15 | A(e) | C10 | |
| 57 | ?? | `test/protein_foods_dialog_test.dart` | 47줄 | A(e) | C10 | |
| 58 | M | `lib/models/clinical_reports.dart` | +8 | A(e) | C11 | `referenceMean`, `guides` |
| 59 | M | `lib/screens/microbiome/microbiome_screen.dart` | +63/−1 | A(e) | C11 | |
| 60 | M | `lib/screens/microbiome/microbiome_metric_screen.dart` | +4/−1 | A(e) | C11 | |
| 61 | M | `lib/widgets/clinical/alpha_metric_grid.dart` | +19/−2 | A(e) | C11 | |
| 62 | M | `lib/screens/blood/components/blood_trend_chart.dart` | +50/−10 | A(e) | C11 | PRD §6.5.8 개조 기준 원본 |
| 63 | M | `lib/screens/insights/components/axis_radar_chart.dart` | +54/−1 | A(e) | C11 | 누락 축 0점 금지 |
| 64 | ?? | `test/axis_radar_chart_test.dart` | 28줄 | A(e) | C11 | |
| 65 | M | `lib/demo/clinical_demo_app.dart` | +129 | A(e) | C11 | |
| 66 | M | `lib/demo/clinical_demo_data.dart` | +27 | A(e) | C11 | 합성 데모 데이터 |
| 67 | M | `test/clinical_demo_app_test.dart` | +7 | A(e) | C11 | |
| 68 | M | `test/clinical_reports_test.dart` | +16/−2 | A(e) | C11 | |
| 69 | M | `docs/deliverables/03_FUNCTIONAL_SPEC.md` | +4 | A(g) | C11 | 위 기능의 명세 3줄이라 기능 커밋에 함께 넣는다 |
| 70 | M | `lib/main.dart` | +2/−22 | A(e) | C12 | 웹은 관리자 콘솔 안내(`WebAdminHandoffApp`) |
| 71 | ?? | `lib/web_admin_handoff.dart` | 76줄 | A(e) | C12 | |
| 72 | ?? | `test/web_admin_handoff_test.dart` | 17줄 | A(e) | C12 | |

**(g) 문서**

| # | 상태 | 경로 | 규모 | 분류 | 커밋 | 비고 |
|---|---|---|---|---|---|---|
| 73 | M | `docs/reports/build_test_report.md` | +6/−4 | A(g) | C13 | |
| 74 | ?? | `docs/reports/full_page_audit_2026-08-10.md` | 118줄 | A(g) | C13 | 이메일·전화번호 패턴 0건 확인 |
| 75 | ?? | `docs/reports/task_order_evidence_matrix_2026-08-10.md` | 31줄 | A(g) | C13 | 같은 검사 0건. `output/` 경로 언급 1건(경로 문자열뿐) |
| 76 | ?? | `docs/PRD_V1.md` | 3,834줄 | A(g) | C13 | **0단계 결정 조건부**(공개 저장소면 특허 공개 범위 Q-17 확인 전 푸시 금지) |

**(f) 트레이너 UI → 보관 브랜치(B)**

| # | 상태 | 경로 | 규모 | 분류 | 커밋 | 근거 |
|---|---|---|---|---|---|---|
| 77 | M | `ios/Runner/AppDelegate.swift` | +975/−118 | B(f) | B01 | 일정·프로그램·작업공간 동기화(작업 트리 :160-197), 로컬 UUID 회원 모델(:7923-8303) 등 |
| 78 | M | `lib/widgets/shells/trainer_shell.dart` | +184 | B(f) | B01 | Android·Web Flutter 트레이너 홈(:60, :271), `load/saveNativeTrainerWorkspace` 채널 핸들러(:340-353) |
| 79 | ?? | `test/trainer_shell_android_test.dart` | 45줄 | B(f) | B01 | 위 폴백 테스트 |
| (5) | | `firestore.rules`의 B hunk | | B(f) | B01 | trainerWorkspaces 블록 |
| (6) | | `functions/test/firestore-rules.test.js`의 B hunk | | B(f) | B01 | 작업공간 규칙 테스트 |
| (52) | | `lib/services/firestore_service.dart`의 B hunk | | B(f) | B01 | 작업공간 로드·저장 |

**(h') 내용 미확인 → 커밋 보류(C)**

| # | 상태 | 경로 | 규모 | 처리 |
|---|---|---|---|---|
| 80 | ?? | `output/` | 파일 78개 | 커밋 금지. 내용을 열지 않는다. C00에서 `.gitignore`에 `/output/` 추가를 권고(ASM-11-02) |
| 81 | ?? | `tmp/` | 파일 2,996개 | 커밋 금지. 내용을 열지 않는다. C00에서 `/tmp/` 추가를 권고 |
| 82 | ?? | `tool/compose_report_visual_comparison.py` | 202줄 | 보류. `output`·`tmp` 경로 참조 3건 |
| 83 | ?? | `tool/compose_result_report_boards.py` | 428줄 | 보류. 참조 11건 |
| 84 | ?? | `tool/generate_exact_2025_template_report_2026.py` | 969줄 | 보류. HWP·DOCX 템플릿 처리 |
| 85 | ?? | `tool/generate_result_report.py` | 682줄 | 보류 |
| 86 | ?? | `tool/generate_result_report_hwpx.py` | 727줄 | 보류 |
| 87 | ?? | `tool/generate_template_based_result_report_2026.py` | 770줄 | 보류 |
| 88 | ?? | `tool/inspect_docx_template.py` | 241줄 | 보류 |

- `tool/*.py`는 과업 결과 보고서 생성기로 보이며 `output/`·`tmp/`를 입출력으로 쓴다. 소유자가 스크립트 안에 실명·연락처·실측값이 하드코딩돼 있지 않은지 확인한 뒤에만 별도 PR로 커밋한다(PRD §11.2 C, 백로그 외 작업).
- `tool/` 폴더에는 v1 도구(`tool/contracts`, `tool/lint`, `tool/backlog`)가 추가될 예정이다. 보류 중인 7개 파일을 실수로 스테이징하지 않도록 에이전트 브랜치에서도 `git add tool/<하위 폴더>` 형태로만 스테이징한다.

**(h) 커밋 금지(이미 무시됨)** — `functions/.secret.local`, `functions/service-account-key.json`, `**/firebase-debug.log`, `firestore-debug.log`, `build*.log`, `flutter_build_err.log`, `ios/pod_install.log`, `build/`, `ios_backup/`, `.firebase/`, `.claude/`, `.idea/`, `.DS_Store`, `admin_web/.next/`, `android/local.properties`. 조치 없음. 3.4의 5단계에서 스테이징되지 않았는지만 확인한다.

**합계 검증:** (c) 4 + (a) 2 + (b) 6 + (d) 18 + (e) 41(#31~#72 중 문서 #69 제외) + (g) 5(#69, #73~#76) + (f) 3 + (h') 9 = 88. 혼재 파일 3개는 A 쪽 번호로 한 번만 셌다.

### 3.4 실행 절차(소유자, S01 1일차 2026-09-28 오전)

모든 명령은 소유자 로컬 저장소에서 **한 터미널 세션으로** 실행한다(단계 사이에 `TS`·`BK`·`SNAP` 변수를 이어 쓴다). 에이전트는 실행하지 않는다. `BK`는 저장소 밖 백업 폴더다.

- 대화형 셸에서 `set -e`나 `exit`를 쓰면 터미널이 닫히므로 쓰지 않는다. 가드는 `&&`로 이어 실패 시 뒤 명령이 실행되지 않게 했다. 가드 실패 메시지가 보이면 그 자리에서 멈추고 §3.6을 따른다.

#### 0단계. 사전 확인과 공개 범위 결정(15분)

```bash
cd ~/dfet_coach/dfet_coach
export TS=20260928
export BK="$HOME/dfet_mig01_backup_$TS"
git switch feature/integrated-care-2026
test "$(git rev-parse --short HEAD)" = "d841412" || echo "STOP: HEAD가 조사 시점과 다름"
test "$(git status --porcelain | wc -l | tr -d ' ')" = "88" || echo "STOP: 항목 수가 다름. §3.3 표를 다시 맞춘다"
git rev-parse main origin/main          # 둘 다 3ef5b79…
gh auth status
gh repo view TEhyeok/DFET_Coach --json visibility -q .visibility   # 조사 시점 PUBLIC
```

**결정 D-MIG01-1: 저장소 공개 범위.** 이 절차는 로컬에만 있던 18개 커밋과 트레이너 UI 보관 브랜치를 처음으로 원격에 올린다. 공개 저장소면 PRD(특허 공개 범위 Q-17), 규제 문구가 남은 트레이너 UI, 과업 보고서가 공개된다.

| 선택 | 조치 | 결과 |
|---|---|---|
| (권고) 비공개 전환 | `gh repo edit TEhyeok/DFET_Coach --visibility private --accept-visibility-change-consequences` | 모든 커밋·보관 브랜치 푸시 가능. 단 비공개 저장소의 GitHub Actions는 무료 분량이 제한되고 macOS 러너는 분당 10배로 계산된다. `trainer-app` CI(macos-15) 비용을 V1-03 용량 계획에 반영한다(ASM-11-03) |
| 공개 유지 | C13에서 `docs/PRD_V1.md`를 빼고, 보관 브랜치는 원격에 푸시하지 않는다(로컬 + 번들 백업만) | 에이전트가 PRD·보관 브랜치를 원격에서 읽을 수 없으므로 작업 지시서에 필요한 발췌를 붙여야 한다 |

결정은 V1-T07 G-01 증빙에 적는다.

#### 1단계. 작업 트리 전체 보존(#1, RISK-04, 10분)

작업 트리를 건드리지 않는 방식으로 보존한다(`git stash`를 쓰지 않는다).

```bash
mkdir -p "$BK" && chmod 700 "$BK"
git rev-parse HEAD            > "$BK/HEAD.txt"
git status --porcelain        > "$BK/status.txt"
git diff --binary HEAD        > "$BK/tracked.patch"
# 추적 안 된 파일(무시 파일 제외, output/·tmp/ 포함). 저장소 밖 로컬 전용
git ls-files --others --exclude-standard -z | tar --null -T - -czf "$BK/untracked.tgz"
# 혼재 파일 3개의 작업 트리 원본(3단계에서 잘라낸 뒤 B 커밋 때 되살린다)
tar -cf "$BK/mixed.tar" firestore.rules functions/test/firestore-rules.test.js lib/services/firestore_service.dart
# 작업 트리 스냅샷 ref: 임시 인덱스로 만들어 현재 인덱스·작업 트리를 건드리지 않는다
export GIT_INDEX_FILE="$BK/index.tmp"
git read-tree HEAD
git add -A -- . ':(exclude)output' ':(exclude)tmp'
TREE=$(git write-tree)
unset GIT_INDEX_FILE
SNAP=$(git commit-tree "$TREE" -p HEAD -m "backup(MIG-01): worktree snapshot $TS (local only, never push)")
git update-ref "refs/backup/mig01-$TS" "$SNAP"
echo "$SNAP" > "$BK/snapshot.txt"
# 모든 ref(로컬 전용 18개 커밋 포함) 번들
git bundle create "$BK/dfet_all_refs_$TS.bundle" --all
git bundle verify "$BK/dfet_all_refs_$TS.bundle"
```

- 스냅샷 트리에 비밀이 들어가지 않았는지 확인한다: `git ls-tree -r --name-only "$SNAP" | grep -E 'secret\.local|service-account' || echo OK`. 출력이 `OK`여야 한다.
- `refs/backup/*`은 기본 push 대상이 아니다. 번들과 `untracked.tgz`는 `output/`·`tmp/`를 포함할 수 있으므로 **외부로 복사하지 않는다.**

#### 2단계. 운영 배포 상태 확인(#4, 10분)

trainerWorkspaces 규칙이 운영에 배포된 적이 있는지 확인한다.

```bash
gcloud config set project dfetmanage
TOKEN=$(gcloud auth print-access-token)
RS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://firebaserules.googleapis.com/v1/projects/dfetmanage/releases/cloud.firestore" | jq -r .rulesetName)
curl -s -H "Authorization: Bearer $TOKEN" "https://firebaserules.googleapis.com/v1/$RS" \
  | jq -r '.source.files[].content' | grep -c 'trainerWorkspaces' || true
```

- 결과 `0`(예상): trainerWorkspaces 블록은 B로 보관한다(기본 경로).
- 결과 `1 이상`: 운영 규칙에 블록이 있다. **#4 예외**로 규칙 블록과 그 테스트를 A(C01)에 남기고 MIG-08 완료(DF-330)까지 유지한다. 서비스 코드(`firestore_service.dart` B hunk)와 채널은 여전히 B다. 3단계의 규칙·테스트 자르기를 생략하고 V1-T07에 예외를 적는다.
- 함께 기록: App Store Connect의 최신 Runner 빌드 업로드 시각이 HEAD 커밋 시각(2026-08-10) 이후인지. 이후라면 작업 트리에서 빌드했을 수 있으므로 출시 빌드에 작업공간 동기화가 들어 있을 가능성을 V1-T07에 적고 MIG-02 `trainerWorkspaces.docs`로 확인한다.

#### 3단계. 기준 브랜치 만들기와 혼재 파일 자르기(15분)

```bash
git switch -c chore/DF-901-mig01-baseline      # 작업 트리 변경은 그대로 따라온다
```

혼재 파일 3개에서 B 줄을 잘라 A판을 만든다. 줄 가드가 하나라도 어긋나면 멈춘다(`sed -i ''`는 macOS 문법).

```bash
guard() { [ "$(sed -n "${2}p" "$1")" = "$3" ] || { echo "GUARD FAIL $1:$2"; return 1; }; }

# firestore.rules — trainerWorkspaces 블록(:112-135)과 뒤 빈 줄(:136). 2단계 결과가 0일 때만
guard firestore.rules 112 '    // --- Native Trainer Workspace ---' \
 && guard firestore.rules 114 '    match /trainerWorkspaces/{trainerId} {' \
 && guard firestore.rules 135 '    }' \
 && guard firestore.rules 137 '    // --- SOAP Notes Collection ---' \
 && sed -i '' '112,136d' firestore.rules && echo "rules cut OK"

# 규칙 테스트 — describe('trainer workspace boundaries')(:151-207)와 뒤 빈 줄(:208). 2단계 결과가 0일 때만
guard functions/test/firestore-rules.test.js 151 "describe('trainer workspace boundaries', () => {" \
 && guard functions/test/firestore-rules.test.js 207 '});' \
 && guard functions/test/firestore-rules.test.js 209 "describe('community integrity boundaries', () => {" \
 && sed -i '' '151,208d' functions/test/firestore-rules.test.js && echo "rules test cut OK"

# firestore_service.dart — 뒤쪽부터 자른다(앞쪽 줄 번호가 변하지 않게)
guard lib/services/firestore_service.dart 675 '  Future<Map<String, dynamic>?> loadTrainerWorkspace(String trainerId) async {' \
 && guard lib/services/firestore_service.dart 728 '  }' \
 && guard lib/services/firestore_service.dart 730 '  Future<void> deleteSoapNote(String id) async {' \
 && sed -i '' '675,729d' lib/services/firestore_service.dart \
 && guard lib/services/firestore_service.dart 21 '  CollectionReference get _trainerWorkspacesCollection =>' \
 && guard lib/services/firestore_service.dart 23 '' \
 && sed -i '' '21,23d' lib/services/firestore_service.dart && echo "service cut OK"

# 남은 B 흔적이 0인지
grep -c 'trainerWorkspace\|TrainerWorkspace' firestore.rules functions/test/firestore-rules.test.js lib/services/firestore_service.dart
# 기대: 세 파일 모두 :0 (2단계 예외 시 앞 두 파일은 0이 아니어도 된다)
git diff HEAD --stat -- firestore.rules functions/test/firestore-rules.test.js lib/services/firestore_service.dart
# 기대(예외 없음): firestore.rules +18/−6, 규칙 테스트 +21, firestore_service.dart +17
```

대안: 소유자가 대화형 `git add -p <파일>`로 같은 hunk를 골라도 된다. 결과는 위 grep·stat 기대값으로 검증한다.

#### 4단계. A 커밋(C00~C13, 30분)

각 커밋은 **경로를 명시해** 스테이징한다(`git add -A`, `git add .` 금지). 커밋 메시지는 Conventional Commits, footer에 `Refs: DF-901`과 `Trace: MIG-01, D13, G-01`을 넣는다.

```bash
c() { git commit -m "$1" -m "Refs: DF-901" -m "Trace: MIG-01, D13, G-01"; }

# C00 비밀 무시 규칙(가장 먼저). 권고안: output/·tmp/도 무시(ASM-11-02)
printf '\n# === MIG-01 C분류: 내용 확인 전 커밋 금지 ===\n/output/\n/tmp/\n' >> .gitignore
git add .gitignore
git diff --cached --name-only    # .gitignore 하나만
c "chore(ci): ignore functions/.secret.local and unreviewed output/tmp"

# C01 (a) 규칙
git add firestore.rules functions/test/firestore-rules.test.js
c "fix(rules): harden community posts and make reactions server-owned"

# C02 (b) Functions
git add functions/index.js functions/package.json functions/package-lock.json
c "feat(functions): add v2 callable adapter, deleteOwnAccount and community callables"

# C03 (b) 임상 수집
git add functions/src/clinical/ingestion.js functions/src/clinical/scoring.js functions/test/clinical.test.js
c "fix(functions): tighten clinical ingestion validation and scoring"

# C04 (c) CI·e2e
git add .github/workflows/ci.yml functions/test/clinical-emulator-e2e.js README.md
c "test(ci): run clinical ingestion e2e on the functions emulator"

# C05 (d) admin_web
git add 'admin_web/app/(console)/clinical/ingestions/page.tsx' 'admin_web/app/(console)/clinical/jobs/page.tsx' \
  'admin_web/app/(console)/content/page.tsx' 'admin_web/app/(console)/requests/page.tsx' \
  'admin_web/app/(console)/users/page.tsx' admin_web/app/api/admin/requests/route.ts admin_web/app/globals.css \
  admin_web/components/console-shell.tsx admin_web/components/content-editor.tsx \
  admin_web/components/ingestion-form.tsx admin_web/components/request-status-editor.tsx \
  'admin_web/app/(console)/admins' 'admin_web/app/(console)/analytics' 'admin_web/app/(console)/users/[uid]' \
  admin_web/app/api/admin/approvals admin_web/app/evidence \
  admin_web/components/admin-approval-actions.tsx admin_web/components/request-resolution-editor.tsx
c "feat(admin): add approvals, admins, analytics, member detail and evidence pages"

# C06 (e) 의존성
git add pubspec.yaml pubspec.lock ios/Podfile.lock macos/Flutter/GeneratedPluginRegistrant.swift
c "chore(member): add cloud_functions dependency"

# C07 (e) 커뮤니티
git add lib/services/community_service.dart lib/models/community/post.dart lib/models/community/community_comment.dart \
  lib/screens/community/post_detail_screen.dart lib/screens/community/create_post_screen.dart lib/widgets/community/post_card.dart
c "feat(member): route community likes and comments through callables"

# C08 (e) 탈퇴·구독
git add lib/screens/settings_screen.dart lib/screens/subscription_screen.dart lib/services/payment_service.dart test/subscription_gate_test.dart
c "fix(member): server-side account deletion and no client-granted entitlements"

# C09 (e) 알림·요청
git add lib/screens/notification_center_screen.dart lib/router/app_router.dart lib/widgets/shells/ios_shell.dart \
  lib/widgets/shells/material_shell.dart lib/widgets/shells/adaptive_home_shell.dart lib/screens/tickets.dart \
  lib/screens/create_request_screen.dart
c "feat(member): add notification center and coaching request routes"

# C10 (e) 수분·식단 대화상자(firestore_service.dart는 3단계에서 A판으로 잘린 상태)
git add lib/services/firestore_service.dart lib/screens/dashboard.dart lib/widgets/hydration_dialog.dart \
  lib/widgets/protein_foods_dialog.dart lib/widgets/breakfast_menu_dialog.dart test/protein_foods_dialog_test.dart
c "feat(member): persist hydration and refresh wellness dialogs"

# C11 (e)+(g) 임상 화면과 명세
git add lib/models/clinical_reports.dart lib/screens/microbiome/microbiome_screen.dart \
  lib/screens/microbiome/microbiome_metric_screen.dart lib/widgets/clinical/alpha_metric_grid.dart \
  lib/screens/blood/components/blood_trend_chart.dart lib/screens/insights/components/axis_radar_chart.dart \
  test/axis_radar_chart_test.dart lib/demo/clinical_demo_app.dart lib/demo/clinical_demo_data.dart \
  test/clinical_demo_app_test.dart test/clinical_reports_test.dart docs/deliverables/03_FUNCTIONAL_SPEC.md
c "feat(member): add reference comparison, missing-axis radar and demo states"

# C12 (e) 웹 진입점
git add lib/main.dart lib/web_admin_handoff.dart test/web_admin_handoff_test.dart
c "feat(web): hand off Flutter web entry to the admin console"

# C13 (g) 문서. 0단계에서 '공개 유지'면 docs/PRD_V1.md를 빼고 커밋
git add docs/reports/build_test_report.md docs/reports/full_page_audit_2026-08-10.md \
  docs/reports/task_order_evidence_matrix_2026-08-10.md docs/PRD_V1.md
c "docs: add PRD v1 and August audit reports"
```

4단계 확인:

```bash
git status --porcelain
# 기대(예외 없음): 아래만 남는다(혼재 파일 3개는 작업 트리=A판=커밋본이라 표시되지 않는다. B판은 6단계에서 되살림)
#  M ios/Runner/AppDelegate.swift
#  M lib/widgets/shells/trainer_shell.dart
# ?? test/trainer_shell_android_test.dart
# ?? tool/…py 7개                                ← C, 보류
git ls-files -s | grep -E 'secret\.local|service-account' && echo "STOP: 비밀 스테이징" || echo "OK 비밀 없음"   # #5
git log --oneline main..HEAD | wc -l            # 18 + 14 = 32
```

#### 5단계. 커밋본 검증(분리 작업 트리, 40분)

작업 트리에 B 변경이 남아 있으므로 **커밋본만 담은 별도 작업 트리**에서 CI와 같은 명령을 돌린다.

```bash
git worktree add ../dfet_mig01_verify chore/DF-901-mig01-baseline
cd ../dfet_mig01_verify
flutter pub get && flutter analyze && flutter test
npm ci --prefix functions && npm --prefix functions run lint && npm --prefix functions test
jq empty schemas/*.json
firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"
printf '%s\n' 'INGEST_HMAC_KEYS={"e2e":"e2e-secret"}' > functions/.secret.local   # CI와 같은 합성 키(무시 파일)
firebase emulators:exec --only functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"
npm ci --prefix admin_web && npm --prefix admin_web run lint && npm --prefix admin_web run typecheck \
  && npm --prefix admin_web test && npm --prefix admin_web run build
flutter build ios --release --no-codesign
cd - && git worktree remove ../dfet_mig01_verify --force
```

- 실패하면 원인 파일을 고치는 커밋을 **이 브랜치에** 추가한다(예: B를 뺀 뒤 남은 import). 커밋 메시지 `fix(member): …`, footer 같음.
- 커밋 단위 빌드는 보장하지 않는다. 기준은 브랜치 tip의 CI 초록이다(ASM-11-04).

#### 6단계. 보관 브랜치(B01, 10분)

```bash
git switch -c archive/trainer-ui-2026-09        # A tip에서 분기, 작업 트리 B 변경은 따라온다
tar -xf "$BK/mixed.tar"                          # 혼재 파일 3개를 작업 트리 원본으로 되살림
git add ios/Runner/AppDelegate.swift lib/widgets/shells/trainer_shell.dart test/trainer_shell_android_test.dart \
  firestore.rules functions/test/firestore-rules.test.js lib/services/firestore_service.dart
git commit -m "archive(trainer): preserve native trainer UI expansion (MIG-01 B, never merge)" \
  -m "Includes trainerWorkspaces rules/tests/service, Runner schedule/program/workspace sync, Flutter trainer fallback." \
  -m "Refs: DF-901" -m "Trace: MIG-01, MIG-08, MIG-09, D13"
ARCHIVE_TIP=$(git rev-parse HEAD); echo "$ARCHIVE_TIP" | tee "$BK/archive_tip.txt"
# 검증 1: 보관 브랜치 tip == 작업 트리 스냅샷(보류 C 7개만 차이)
git diff --name-only "refs/backup/mig01-$TS" "$ARCHIVE_TIP"
# 기대: .gitignore(C00에서 /output/·/tmp/ 추가분)와 tool/*.py 7개(스냅샷에만 있음)뿐
# 검증 2: 작업 트리에는 C만 남는다
git status --porcelain     # 기대: ?? tool/…py 7개(output/, tmp/는 C00으로 무시됨)
wc -l < ios/Runner/AppDelegate.swift   # 9657 — PRD 줄 번호의 기준선
```

- `ARCHIVE_TIP`이 **이식 기준선**이다(#7, PRD §0.2). [V1-00](00_README.md) '이식 기준선'과 PRD 변경 이력(소유자 편집)에 적는다.
- 이 tip에서 `dfet:ios/Runner/AppDelegate.swift:NNNN` 형식의 PRD·V1 문서 줄 번호가 그대로 맞는다.

#### 7단계. 푸시와 PR(10분)

```bash
git push -u origin chore/DF-901-mig01-baseline
# 0단계에서 비공개로 전환했을 때만:
git push origin archive/trainer-ui-2026-09
gh pr create --repo TEhyeok/DFET_Coach --base main --head chore/DF-901-mig01-baseline \
  --title "chore: MIG-01 baseline — integrated-care A changes (DF-901)" \
  --body "$(cat <<'EOF'
## 요약
- feature/integrated-care-2026의 기존 18개 커밋과 MIG-01 A분류 14개 커밋(C00~C13)을 main에 올린다.
- B분류(트레이너 UI)는 archive/trainer-ui-2026-09에 보관하고 병합하지 않는다.
- C분류(output/, tmp/, tool/*.py)는 커밋하지 않았다.

Refs: DF-901
Trace: MIG-01, D13, G-01

## 확인
- [ ] 분리 작업 트리에서 CI 명령 전체 통과(V1-11 §3.4 5단계)
- [ ] 비밀 파일 스테이징 0건
- [ ] trainerWorkspaces 흔적: firestore.rules / 규칙 테스트 / firestore_service.dart 0건(#4 예외 시 기록)
- [ ] 소유자 검토 완료
EOF
)"
```

#### 8단계. CI 확인과 병합(CI 대기 포함 40분)

```bash
gh pr checks --watch            # flutter, functions-and-rules, admin-web, ios-no-codesign 모두 pass
gh pr merge --rebase             # 선형 이력 유지, 32개 커밋 보존(ASM-11-05)
git switch main && git pull --ff-only
git diff --name-only main archive/trainer-ui-2026-09
# 기대(예외 없음): 정확히 6개
#   firestore.rules
#   functions/test/firestore-rules.test.js
#   ios/Runner/AppDelegate.swift
#   lib/services/firestore_service.dart
#   lib/widgets/shells/trainer_shell.dart
#   test/trainer_shell_android_test.dart
git grep -c 'trainerWorkspace' main -- firestore.rules lib functions ios || echo "OK main에 B 없음"   # 수용 기준
```

#### 9단계. 정리(5분)

```bash
# 기능 브랜치는 원격에 없고 번들·스냅샷에 보존되어 있다
git branch -D feature/integrated-care-2026
git push origin --delete chore/DF-901-mig01-baseline
git branch --list 'archive/*' 'chore/*'
```

- 이후 v1 작업은 모두 `main`에서 분기한다(AS-DEV-11).
- DF-930(동결 선언, §11.2)과 DF-902(라벨·마일스톤)를 이어서 실행한다.
- 백업 폴더 `BK`는 P0 종료 검토(DF-926)까지 보관한 뒤 삭제하고 V1-T07에 삭제일을 적는다.

### 3.5 혼재 파일 hunk 분리표

PRD §11.2 #3의 줄 범위는 조사 당시 값이다. 아래가 2026-09-24 작업 트리를 직접 연 결과다.

| 파일 | A hunk(작업 트리 줄) | B hunk(작업 트리 줄) | PRD 표기와 차이 |
|---|---|---|---|
| `firestore.rules` | posts 필드 검증·서버 카운터(:163-195), likes·comments `write: if false` | trainerWorkspaces 주석+블록(:112-135) + 빈 줄(:136) | PRD `:114-135`는 `match` 줄부터. 주석 2줄 포함해 :112부터 자른다 |
| `functions/test/firestore-rules.test.js` | posts 시드(:51-54), `community integrity boundaries`(:209-224) | `trainer workspace boundaries`(:151-207) + 빈 줄(:208) | PRD `:160-209`는 어긋남. 실제는 :151-207 |
| `lib/services/firestore_service.dart` | `_hydrationCollection`·`loadHydration`·`saveHydration`(:32-47) | `_trainerWorkspacesCollection`(:21-22) + 빈 줄, `loadTrainerWorkspace`·`saveTrainerWorkspace`(:675-728) + 빈 줄 | 일치 |

### 3.6 중단과 되돌리기

| 상황 | 조치 |
|---|---|
| 0~4단계 중 가드 실패·실수 | `git switch feature/integrated-care-2026` 뒤 `git reset --hard HEAD && git clean -fd -- . ':!output' ':!tmp'`를 **하지 않는다.** 대신 1단계 스냅샷으로 복원: `git checkout "refs/backup/mig01-$TS" -- .` (추적 파일), `tar -xzf "$BK/untracked.tgz"`(추적 안 된 파일) |
| 5단계 CI 실패가 반나절 안에 안 풀림 | PR을 열지 않고 S01 계획을 조정한다. 에이전트 작업은 contracts·docs(DF-001~005)처럼 `main`의 코드에 의존하지 않는 것만 `chore/DF-901-mig01-baseline` 기반으로 임시 진행(병합은 DF-901 뒤) |
| 병합 후 문제 발견 | `main`에 되돌림 커밋(`git revert`)을 PR로 올린다. force-push 금지 |

### 3.7 증빙(G-01, V1-T07)

- 분류표: 이 문서 §3.3 링크 + 실제 커밋 해시 목록(`git log --oneline 3ef5b79..main`).
- `ARCHIVE_TIP` 해시, 보관 브랜치 원격 푸시 여부(0단계 결정).
- CI 실행 링크 4개.
- `git check-ignore -v functions/.secret.local functions/service-account-key.json` 출력.
- 2단계 운영 규칙 확인 결과(0 또는 예외).
- 백업 폴더 위치(경로만, 내용 없음)와 삭제 예정일.

---

## 4 MIG-02 운영 데이터 실사

| 항목 | 내용 |
|---|---|
| PRD | §11.3 |
| 스토리 | DF-030(스크립트, S04), DF-907(운영 실행, S04) |
| 선행 | MIG-01(G-01), DF-037(Functions shared 구조) |
| 책임자 | 소유자(운영 실행). 에이전트는 에뮬레이터만 |

### 4.1 스크립트 계약(`mig02_inventory.js`)

- 쓰기 API 호출이 0건이다(`tool/lint/no-writes.mjs`가 `.set(`, `.update(`, `.delete(`, `.add(`, `batch(`, `runTransaction(`, `bulkWriter(`, `setCustomUserClaims(`, `.save(`, `.upload(`를 검사).
- 읽기 방법
  - `soap_notes`: `db.collection('soap_notes').select(<필요 필드>).stream()`로 한 번 훑는다. 필요 필드: `schemaVersion`, `trainerId`, `memberId`, `date`, `createdAt`, `updatedAt`, `painNow`, `diagnosis`, `isSharedWithMember`, `drawingData`, `structured`, `subjective`, `homeExercise`, `nextPlan`. 값은 메모리에서 분류만 하고 버린다.
  - `users`: `memberId` 형식 판정에 필요한 uid만 `db.getAll(...refs, {fieldMask: ['trainerId', 'role']})`로 100개씩 조회.
  - `trainers`: 전체 `select('memberIds')`.
  - `trainerWorkspaces`: 전체 문서. `membersJson`을 `JSON.parse`해 **배열 길이만** 센다.
  - Auth: `admin.auth().listUsers(1000, pageToken)`로 `customClaims` 키만 센다.
  - Storage: `bucket.getFiles({prefix: 'soapInk/', autoPaginate: true})` 개수만(이관 전에는 0이 정상).

### 4.2 보고서 형식

DF-030 형식을 기준으로 이관 설계에 필요한 항목을 더했다(추가분은 DF-030 구현 시 함께 넣는다, ASM-11-06).

```json
{
  "mig": "MIG-02", "reportVersion": 1, "runId": "mig02-20261021T0900Z-1a2b", "mode": "dry-run",
  "target": "dfetmanage", "scriptSha": "…", "startedAt": "…", "finishedAt": "…",
  "counts": {
    "soap_notes": {
      "total": 0,
      "schemaVersion2": 0,
      "metricType": {"rom": 0, "ROM": 0, "mmt": 0, "MMT": 0, "pain": 0, "통증": 0, "test": 0, "specialTest": 0,
                     "특수검사": 0, "functional": 0, "기능검사": 0, "exercise": 0, "general": 0, "empty": 0, "other": 0},
      "metricValueForm": {"number": 0, "range": 0, "multi": 0, "slashFive": 0, "symbolGrade": 0, "empty": 0, "other": 0},
      "workflowStatus": {"draft": 0, "작성 중": 0, "complete": 0, "완료": 0, "shared": 0, "공유됨": 0, "none": 0, "other": 0},
      "completedCategoriesFormat": {"short": 0, "long": 0, "mixed": 0, "none": 0},
      "memberIdFormat": {"uidAssigned": 0, "uidNotAssigned": 0, "uidNotInUsers": 0, "memberSeed": 0, "empty": 0},
      "assignmentMismatch": 0,
      "origin": {"flutter": 0, "trainerIos": 0, "nativeBridge": 0},
      "nativeIdCount": 0,
      "inlineInk": {"drawingData": 0, "nativeInkDataBase64": 0,
                    "sizeBuckets": {"lt100KB": 0, "100to500KB": 0, "500KBto5MB": 0, "gt5MB": 0}},
      "diagnosisNonEmpty": 0,
      "isSharedTrue": 0,
      "painNow": {"int0": 0, "int1to10": 0, "missing": 0, "other": 0},
      "textOverLimit": {"subjective": 0, "homeExercise": 0, "nextPlan": 0},
      "dateForm": {"number": 0, "timestamp": 0, "missing": 0},
      "trainerIdMissing": 0
    },
    "trainerWorkspaces": {"docs": 0, "memberEntryBuckets": {"0": 0, "1to10": 0, "11to50": 0, "gt50": 0},
                          "sizeBuckets": {"lt100KB": 0, "100to500KB": 0, "gt500KB": 0}},
    "trainers": {"docs": 0, "withMemberIds": 0, "memberIdsTotal": 0},
    "claims": {"authUsers": 0, "trainer": 0, "admin": 0, "superAdmin": 0},
    "usersRoleAdmin": {"withAdminClaim": 0, "withoutAdminClaim": 0},
    "admins": {"approved": 0},
    "storage": {"soapInkObjects": 0}
  }
}
```

분류 정의

| 키 | 판정 |
|---|---|
| `memberIdFormat.uidAssigned` | `users/{memberId}` 존재 **그리고** `trainers/{trainerId}.memberIds`가 `memberId`를 포함 |
| `uidNotAssigned` | `users`에 있으나 위 포함 조건 불성립 |
| `uidNotInUsers` | `member-` 접두사 아님, `users`에 없음 |
| `memberSeed` | `memberId`가 `member-`로 시작(로컬 seed, dfet:ios/Runner/AppDelegate.swift:3839·:8117, 보관 브랜치 tip 기준) |
| `assignmentMismatch` | `trainers.memberIds`와 `users.trainerId`가 서로 다른 트레이너를 가리킴 |
| `origin.trainerIos` | `structured.assessment.problemList` 키 존재(trainer_ios 저장 형식, dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:331) |
| `origin.nativeBridge` | `structured.subjective.nativeInkStrokeCount` 키 존재(dfet:lib/widgets/shells/trainer_shell.dart:321-322, `main` 기준) |
| `origin.flutter` | 그 밖 |
| `metricValueForm` | §5.4.3 `parseNumericValue` 분류와 같은 규칙 |
| `textOverLimit` | v2 길이 상한(§9.3) 초과: `subjective` 문자열 > 2,000자, `homeExercise`+exercise 덧붙임 > 2,000자, `nextPlan` > 2,000자 |

### 4.3 실행(소유자, DF-907, S04)

```bash
cd ~/dfet_coach/dfet_coach && git switch main && git pull --ff-only
npm ci --prefix functions
unset FIRESTORE_EMULATOR_HOST FIREBASE_STORAGE_EMULATOR_HOST FIREBASE_AUTH_EMULATOR_HOST
gcloud auth application-default login          # ADC, 키 파일 사용 금지
mkdir -p ~/dfet_mig_reports && chmod 700 ~/dfet_mig_reports
node functions/scripts/migrations/mig02_inventory.js \
  --project dfetmanage --confirm-readonly-prod --out ~/dfet_mig_reports
```

- 소요 시간은 문서 수에 비례한다. 운영 문서 수가 작다는 전제에서 수 분(ASM-11-07).
- 결과 JSON은 저장소에 커밋하지 않는다. 수량만 V1-T10 `docs/v1/migrations/MIG-02-YYYYMMDD-<runId>.md`에 옮긴다.

### 4.4 검증

- 보고서 전체에서 이메일 패턴·uid 형식 문자열이 0건인지: `jq -r '..|strings' <report> | grep -E '@|^[A-Za-z0-9]{28}$' || echo OK`.
- `soap_notes.total` = `metricType` 분류가 아닌, `memberIdFormat` 다섯 값의 합과 같다(누락 분류 없음).

### 4.5 롤백

읽기 전용이므로 없다.

### 4.6 보고서 → 하위 작업 결정표

| 보고서 값 | 0일 때 | 0보다 클 때 |
|---|---|---|
| `soap_notes.total - schemaVersion2` | MIG-03~06 운영 적용 '해당 없음'. **v1 쓰기 차단 스위치 배포(DF-100 → DF-924)는 여전히 한다** | §5 적용 |
| `inlineInk.drawingData + nativeInkDataBase64` | MIG-06 '해당 없음' | §8 |
| `isSharedTrue` | MIG-05 데이터 처리 '해당 없음' | §7 |
| `diagnosisNonEmpty` | MIG-04 데이터 처리 '해당 없음'(문구 수정은 여전히 필요) | §6 |
| `memberIdFormat.memberSeed + uidNotInUsers + uidNotAssigned` | MIG-07 서버 문서 처리 '해당 없음'(기기 확인은 여전히 필요) | §9에 수량 보고 |
| `trainerWorkspaces.docs` | MIG-08 2~4단계 '해당 없음'. DF-138·DF-330은 '규칙·코드 부재 확인'으로 축소 | §10 |
| `usersRoleAdmin.withoutAdminClaim` | DF-101에서 `users.role` 대체 경로 제거 가능 | 해당 관리자에게 claim을 먼저 부여(DF-026 설계) |
| `gt5MB` 필기 | — | 이관은 하되(Admin SDK는 크기 규칙 무관) 보고서에 수량을 남긴다 |

---

## 5 MIG-03 soap_notes v2 이관

| 항목 | 내용 |
|---|---|
| PRD | §11.4, §9.3, R-21, G-03 |
| 스토리 | DF-005(픽스처), DF-006(스키마 문서), DF-031(변환·dry-run·롤백 도구, S05), DF-100(v1 차단 스위치 PR·롤백 리허설, S08), DF-931(규칙 배포, S08), DF-924(운영 적용, S09) |
| 선행 | MIG-02 보고서, §9.3 확정(DF-006), 규칙 v2 배포(DF-931), MIG-06용 Storage 규칙 배포(DF-023 → DF-931), 백업 버킷(§2.5) |
| 함께 처리 | MIG-04(데이터), MIG-05, MIG-06 — 한 실행기 `mig03_06.js`, 한 `runId` |
| 책임자 | 소유자(운영), 에이전트(도구·리허설) |

### 5.1 흐름 한눈에

```
[P0 S05] DF-031  에뮬레이터: 레거시 픽스처 → dry-run → apply → 기대 v2 일치 → 재실행 쓰기 0
[P1a S08] DF-100 에뮬레이터: apply → rollback → apply 리허설 + v1 차단 스위치 draft PR
[P1a S08] DF-931 운영: 규칙 v2(스위치 true 상태)·Storage 규칙 배포
[P1a S09] DF-924 운영: 공지(T-7일) → 내보내기#1 → 스위치 배포(MIG-08 1단계 포함) → 내보내기#2 → dry-run → apply → verify → 태그
```

### 5.2 변환 대상과 결과 종류

`transformLegacySoap(doc, ctx)`는 문서마다 아래 셋 중 하나를 돌려준다.

| action | 조건 | 결과 |
|---|---|---|
| `already` | `schemaVersion == 2` | 쓰기 없음. 이관 문서면 `alreadyMigrated`, 원래 v2면 `nativeV2` |
| `migrate` | v1이고 §5.3 전환 조건을 모두 충족 | v2 문서로 **전체 교체**(트랜잭션 안 `tx.set(ref, v2)`), `migratedFrom` 부여 |
| `hygiene` | v1이지만 전환 조건 불충족(회원 미해결, 알 수 없는 status, 길이 초과 등) | v1 그대로 두고 MIG-04·05·06 위생 처리만 한다(§5.6). `legacy.hygieneRunId` 부여 |

`hygiene`가 DF-031 카드(AC-DF-031.7 "v2로 바꾸지 않고 원문을 유지")보다 한 걸음 더 나간 부분이다. PRD MIG-05 수용 기준 "이관 후 `isSharedWithMember=true` 0건"과 MIG-06 "인라인 필기 잔존 0건"이 **컬렉션 전체** 기준이라, 전환하지 못한 문서에도 위생 처리가 필요하다(충돌 CF-11-03).

### 5.3 v2 전환 조건

모두 참이어야 `migrate`다. 하나라도 거짓이면 `hygiene`이고 보고서 `skipReason.<키>`에 1을 더한다.

| # | 조건 | skipReason 키 |
|---|---|---|
| 1 | `trainerId`가 비어 있지 않은 문자열 | `trainerIdMissing` |
| 2 | `memberId`가 `uidAssigned`(§4.2 정의) | `memberSeed`, `uidNotInUsers`, `uidNotAssigned`, `memberIdEmpty`, `assignmentMismatch` |
| 3 | status 매핑 가능(§5.4.2) | `unknownStatus` |
| 4 | `sessionDate`를 정할 수 있음(§5.4.1) | `dateMissing` |
| 5 | 텍스트가 v2 상한 이내(`chiefComplaint`, `plan.homeExercise`, `plan.nextSession` 각 ≤2,000자) | `textTooLong` |
| 6 | 변환 결과 문서가 1,000,000바이트 미만(인라인 필기 제외 추정치) | `docTooLarge` |

- 이메일(`memberEmail`)로 회원을 추정하지 않는다(PRD §11.4).
- 조건 2에서 `trainers.memberIds`를 1차 기준으로 쓴다. 담당 관계의 진실원이기 때문이다(ADR-003). `users.trainerId`와 어긋나면 전환하지 않는다(ASM-11-08).

### 5.4 필드 단위 변환(migrate)

정본 매핑은 PRD §11.4·[V1-05 §5.6](05_DATA_MODEL_AND_RULES.md#56-v1v2-매핑-요약)이다. 아래는 **구현 수준**으로 모든 필드를 확정한 표다.

#### 5.4.1 최상위 필드

| v2 필드 | 값 | 비고 |
|---|---|---|
| `schemaVersion` | `2` | |
| `migratedFrom` | `{runId, schemaVersion: 1}` | |
| `trainerId` | 원본 `trainerId` | |
| `authorUid` | 원본 `trainerId` | F-LINK-03.6 |
| `memberUid` | 원본 `memberId` | 조건 2 충족분만 |
| `memberId` | 원본 `memberId`(그대로) | 호환 기간 병기(§9.3) |
| `isSharedWithMember` | `false` | MIG-05 |
| `sessionDate` | `Timestamp.fromMillis(date)`(숫자) 또는 원본 Timestamp. `date`가 없으면 origin이 `trainerIos`가 아닐 때만 `createdAt`으로 대체 | trainer_ios `createdAt`은 믿지 않는다(PRD §11.4) |
| `status` | §5.4.2 | |
| `finalizedAt` | status가 `finalized`일 때 `Timestamp.fromMillis(updatedAt)`. `updatedAt`이 없으면 `sessionDate` | |
| `subjective` | `{chiefComplaint, painNrs, painRegions: []}` | §5.4.4 |
| `plan` | `{nextSession: nextPlan ?? '', homeExercise}` | §5.4.5 |
| `legalNature` | `'coachingRecord'` | |
| `inkPath`, `inkRevision` | 인라인 필기가 있고 업로드·대조 성공 시 `soapInk/{noteId}/1.drawing`, `1` | §8 |
| `createdAt` | 원본 숫자면 `Timestamp.fromMillis`, Timestamp면 그대로, 없으면 `sessionDate` | |
| `updatedAt` | `FieldValue.serverTimestamp()` | |
| `legacy` | §5.4.6 | |
| (쓰지 않음) | `objective`, `exerciseAssessment`, `quickNote`, `memberNote`, `memberSummaryId`, `pendingMemberId` | `objective.metrics`에 들어갈 수 있는 레거시 metric은 없다(아래) |

- 원본 `assessment`(A 문자열, "임상 판단" 문구가 섞일 수 있음)와 `treatmentPlan`('치료계획' 의미)은 v2로 옮기지 않고 `legacy.flat`에만 둔다. `exerciseAssessment`는 트레이너가 addendum이나 draft 편집으로 새로 쓴다(ASM-11-10). 이로써 MIG-04 수용 기준 "exerciseAssessment가 레거시 diagnosis와 같은 문서 0건"이 구조적으로 보장된다.

#### 5.4.2 status

`structured.workflow.status` 기준(Flutter dfet:lib/models/soap_note.dart:62·81, trainer_ios dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:323).

| 원본 | v2 `status` |
|---|---|
| `draft`, `작성 중`, 키 없음, 빈 문자열 | `draft` |
| `complete`, `완료` | `finalized` |
| `shared`, `공유됨` | `finalized`(요약 자동 생성 없음, MIG-05) |
| 그 밖 | 전환하지 않음(`unknownStatus`) |

`legacy.completedCategories`: `S→subjective`, `O→objective`, `A→assessment`, `P→plan`, 긴 이름은 그대로, 그 밖 값은 원문 유지. 중복 제거, 원래 순서 유지.

#### 5.4.3 metric 처리

원본 `structured.metrics[]`(Flutter `SoapMetric` {type, label, side, value, unit, score, note}, dfet:lib/models/soap_note.dart:10-51)는 **전부** `legacy.metricsRaw`에 원문 그대로 복사한다. 그 위에 아래만 추가로 반영한다.

| 레거시 type | 추가 반영 | 이유 |
|---|---|---|
| `rom`, `ROM` | 없음 | joint·motion·activeOrPassive 없음 → 미완성(PRD §11.4) |
| `mmt`, `MMT` | 없음 | muscleGroup 없음 |
| `pain`, `통증` | 원본 `painNow`가 없을 때만, pain 행이 **정확히 1개**이고 값이 0~10 정수면 `subjective.painNrs` | PRD §11.4 |
| `test`, `specialTest`, `특수검사`, `functional`, `기능검사`, `general`, 빈 값, 그 밖 | 없음 | v2 임상 모드(Q-14) 또는 해당 없음 |
| `exercise` | `plan.homeExercise` 끝에 줄을 바꿔 `[레거시 exercise] <label>`(값이 있으면 ` <value>` 덧붙임) | PRD §11.4. 표기는 V1-05 §5.5 예시와 같다 |

`parseNumericValue(raw)`(보고서와 pain 판정 공용, 순수 함수)

```js
// functions/scripts/migrations/lib/legacyMapping.js
function parseNumericValue(raw) {
  if (typeof raw === 'number') return Number.isFinite(raw) ? {ok: true, value: raw, form: 'number'} : {ok: false, form: 'other'};
  if (raw == null) return {ok: false, form: 'empty'};
  const s = String(raw).trim().replace(/\s+/g, '');
  if (s === '') return {ok: false, form: 'empty'};
  const slash = s.match(/^([0-5])\/5$/);
  if (slash) return {ok: true, value: Number(slash[1]), form: 'slashFive'};
  if (/^[0-5][+-]$/.test(s)) return {ok: false, form: 'symbolGrade'};           // '4+' 실패
  if (/^-?\d+(\.\d+)?[-~–]\d+(\.\d+)?/.test(s)) return {ok: false, form: 'range'}; // '110-120' 실패
  if (/[,;]/.test(s) || (s.match(/\d+(\.\d+)?/g) || []).length > 1) return {ok: false, form: 'multi'};
  const stripped = s.replace(/(deg|도|°|grade|점)$/i, '');
  if (/^-?\d+(\.\d+)?$/.test(stripped)) return {ok: true, value: Number(stripped), form: 'number'};
  return {ok: false, form: 'other'};
}
```

- 파싱 실패 값을 0으로 채우지 않는다. 0은 원본이 숫자 0일 때만 나온다.
- `mapSide`: `좌→left`, `우→right`, `양측→bilateral`, `해당 없음`·빈 값→`none`, 영문 `left|right|bilateral|none`은 그대로, 그 밖은 원문(보고서 `sideOther`). `mapUnit`: `deg|도|°→deg`, `grade→grade`, 그 밖 원문. 두 함수는 `metricsRaw`에는 적용하지 않는다(원문 보존). 코덱의 '레거시 원문 보기' 표시용으로 export만 한다.

#### 5.4.4 subjective

| v2 키 | 값 |
|---|---|
| `chiefComplaint` | 원본 최상위 `subjective` 문자열(Flutter·trainer_ios 모두 문자열로 저장, dfet:lib/models/soap_note.dart:372, FirebaseTrainerRepository.swift:346). 빈 문자열이면 키를 쓰지 않는다 |
| `painNrs` | 원본 `painNow`가 0~10 정수면 그 값. **단 origin이 `trainerIos`이고 `painNow == 0`이면 `null`**(trainer_ios는 미입력도 0으로 저장, FirebaseTrainerRepository.swift:227·350, ASM-11-11). `painNow`가 없으면 §5.4.3 pain 규칙 |
| `painRegions` | `[]`. 원본 `bodyRegion`·`painSite`는 자유 텍스트라 부록 A.7 regionCode로 바꾸지 않고 `legacy.flat`에 둔다 |

#### 5.4.5 plan

| v2 키 | 값 |
|---|---|
| `homeExercise` | 원본 `homeExercise` + exercise 덧붙임(§5.4.3). 둘 다 없으면 `''` |
| `nextSession` | 원본 `nextPlan`. 없으면 `''`. 이관된 finalized 문서는 비어 있어도 된다(확정 최소 요건은 클라이언트 전환 시점 규칙, V1-05 §5.5) |

#### 5.4.6 legacy 블록

§9.3의 네 키에 롤백 근거 키를 더한다. `flat`·`structured`는 DF-031 카드(ASM-P0-33)와 같고, 나머지는 이 런북이 더한다(CF-11-04, DF-006에서 V1-05·`schemas/soap-note-v2.schema.json`에 함께 반영).

| 키 | 값 | 출처 |
|---|---|---|
| `metricsRaw` | 원본 `structured.metrics` 배열 그대로 | §9.3 |
| `diagnosisRaw` | 원본 `diagnosis`(비어 있지 않을 때) | §9.3, MIG-04 |
| `originalIsShared` | 원본 `isSharedWithMember`(키가 있을 때) | §9.3, MIG-05 |
| `completedCategories` | §5.4.2 정규화 | §9.3 |
| `flat` | 원본 최상위 필드 전부에서 `structured`, `drawingData`, `diagnosis`, `isSharedWithMember`를 뺀 맵(값·타입 그대로) | DF-031 |
| `structured` | 원본 `structured`에서 `metrics`와 `subjective.nativeInkDataBase64`를 뺀 맵 | DF-031 |
| `inkOrigin` | `'drawingData'` \| `'nativeInkDataBase64'`(인라인 필기가 있었을 때) | 이 런북 |
| `inlineInk` | 백업 확인 전까지 원래 필기 바이트(Bytes). `--backup-confirmed`가 있으면 쓰지 않는다 | 이 런북, §8 |
| `migratedAt` | `FieldValue.serverTimestamp()`(`updatedAt`과 같은 쓰기) | 롤백 충돌 판정용, 클라이언트는 쓸 수 없다 |

- `legacy`는 규칙상 클라이언트가 쓸 수 없다(V1-05 §7.3 화이트리스트 밖). 트레이너 앱 '레거시 원문 보기'만 읽는다. `diagnosisRaw`는 기본 화면에 표시하지 않는다(MIG-04).

#### 5.4.7 알고리즘

```js
// functions/scripts/migrations/mig03_06.js (요지)
for await (const snap of db.collection('soap_notes').orderBy(FieldPath.documentId()).stream()) {
  const ctx = await buildContext(snap, cache);        // users·trainers 조회(캐시), origin 판정
  const plan = transformLegacySoap({id: snap.id, data: snap.data()}, {...ctx, runId, backupConfirmed});
  report.add(plan.report);                            // 수량만
  if (mode === 'dry-run' || plan.action === 'already') continue;
  if (plan.ink) await inkMover.uploadAndVerify(plan.ink); // §8. 실패하면 이 문서 건너뜀(failed.ink)
  await db.runTransaction(async (tx) => {
    const cur = await tx.get(snap.ref);
    if (cur.get('schemaVersion') === 2 || cur.get('legacy.hygieneRunId') === runId) return; // 멱등
    if (!cur.updateTime.isEqual(snap.updateTime)) throw new Changed(snap.id);             // 동시 변경
    if (plan.action === 'migrate') tx.set(snap.ref, plan.v2);
    else tx.update(snap.ref, plan.hygieneUpdate);
  });
}
```

- 문서 단위 트랜잭션이다(DF-031). 초당 쓰기는 `--rate 20`(기본)으로 제한한다.
- `Changed` 예외는 `failed.changedDuringRun`으로 세고 다음 문서로 넘어간다. 스위치 배포 뒤라 정상이면 0이다.

### 5.5 CLI

```bash
# 에뮬레이터(에이전트·CI)
node functions/scripts/migrations/mig03_06.js --emulator                       # dry-run
node functions/scripts/migrations/mig03_06.js --emulator --apply --run-id T1   # 에뮬레이터 apply(보고서 확인 생략)
node functions/scripts/migrations/mig03_06.js --emulator --apply --run-id T1 --backup-confirmed local   # 인라인 제거까지

# 운영(소유자, DF-924)
node functions/scripts/migrations/mig03_06.js --project dfetmanage --report-dir ~/dfet_mig_reports
node functions/scripts/migrations/mig03_06.js --project dfetmanage --report-dir ~/dfet_mig_reports \
  --apply --run-id <dry-run runId> --backup-confirmed gs://dfetmanage-mig-backups/mig03/<TS>-post --i-am-owner
node functions/scripts/migrations/mig03_06.js --project dfetmanage --report-dir ~/dfet_mig_reports \
  --verify --run-id <runId>
```

| 인자 | 기본 | 설명 |
|---|---|---|
| `--apply` | 없음(dry-run) | §2.2 |
| `--run-id` | dry-run이 생성 | apply·verify에 필수 |
| `--backup-confirmed` | 없음 | 있으면 인라인 필기 제거까지, 없으면 `legacy.inlineInk`에 남기고 `inlineRetained` 집계 |
| `--limit N` | 없음 | 앞에서 N개만(리허설용). 운영 apply에서는 거부 |
| `--rate N` | 20 | 초당 트랜잭션 상한 |
| `--verify` | — | §5.9 쿼리만 실행(읽기 전용), 기대와 다르면 종료 코드 3 |

### 5.6 위생 처리(hygiene) 내용

v1 문서를 v2로 바꾸지 않고 `tx.update`로 아래만 바꾼다.

| 필드 | 변경 |
|---|---|
| `isSharedWithMember` | `true`였으면 `false`, `legacy.originalIsShared = true` |
| `diagnosis` | 비어 있지 않으면 `FieldValue.delete()`, `legacy.diagnosisRaw` = 원문. 빈 문자열이면 삭제만 |
| 인라인 필기 | §8 업로드·대조 → `inkPath`, `inkRevision = 1`, `legacy.inkOrigin`. `--backup-confirmed`가 있으면 원래 위치(`drawingData` 또는 `structured.subjective.nativeInkDataBase64`)를 `FieldValue.delete()` |
| `legacy.hygieneRunId` | `runId` |
| `legacy.migratedAt` | `serverTimestamp()` |

- 위생 처리 문서는 `schemaVersion`이 없는 v1 문서로 남고, MIG-03 스위치 뒤 클라이언트 쓰기가 영구 거부된다(R-21). 트레이너 앱은 레거시 읽기로 보여 준다.
- 코덱 영향: v1 문서에도 `inkPath`와 `legacy`가 있을 수 있다. DF-007·DF-009 코덱은 v1 읽기에서 `inkPath`가 있으면 Storage 필기를, 없으면 인라인을 쓴다(CF-11-05).

### 5.7 보고서(dry-run·apply 공통)

```json
{
  "mig": "MIG-03", "runId": "mig03-20261124T1100Z-7c2e", "mode": "apply", "target": "dfetmanage",
  "counts": {
    "scanned": 0,
    "already": {"alreadyMigrated": 0, "nativeV2": 0, "hygieneThisRun": 0},
    "migrate": {"planned": 0, "written": 0},
    "hygiene": {"planned": 0, "written": 0},
    "skipReason": {"trainerIdMissing": 0, "memberSeed": 0, "uidNotInUsers": 0, "uidNotAssigned": 0,
                   "memberIdEmpty": 0, "assignmentMismatch": 0, "unknownStatus": 0, "dateMissing": 0,
                   "textTooLong": 0, "docTooLarge": 0},
    "status": {"draft": 0, "finalized": 0},
    "metrics": {"rawPreserved": 0, "toPainNrs": 0, "toHomeExercise": 0, "toObjectiveMetrics": 0,
                "valueForm": {"number": 0, "slashFive": 0, "range": 0, "multi": 0, "symbolGrade": 0, "empty": 0, "other": 0}},
    "painNrs": {"fromPainNow": 0, "fromPainMetric": 0, "trainerIosZeroToNull": 0, "none": 0},
    "diagnosis": {"moved": 0, "emptyDeleted": 0},
    "shared": {"reset": 0},
    "ink": {"found": 0, "uploaded": 0, "skippedSameHash": 0, "verified": 0, "hashMismatch": 0,
            "pathConflict": 0, "gt5MB": 0, "inlineRemoved": 0, "inlineRetained": 0},
    "failed": {"ink": 0, "changedDuringRun": 0, "write": 0}
  }
}
```

- `toObjectiveMetrics`는 PRD 매핑상 항상 0이다. 0이 아니면 구현 오류이므로 CI 테스트가 실패해야 한다.
- dry-run의 `migrate.planned + hygiene.planned + already.*`의 합은 `scanned`와 같아야 한다.

### 5.8 운영 적용 절차(DF-924, S09)

**T-7일(S08 목요일 목표): 공지.** 동결된 Runner 트레이너와 Flutter 폴백 사용자에게 SOAP 쓰기가 종료되고 새 트레이너 앱(TestFlight)으로 옮긴다는 사실을 알린다. 문안(트레이너용, 금지어 검사 대상 아님이지만 부록 C를 따른다):

> [D-FET 트레이너 안내] 11월 24일(화) 저녁부터 기존 D-FET 앱 안의 트레이너 화면에서는 SOAP 기록을 새로 저장할 수 없습니다. 이미 저장된 기록은 계속 볼 수 있습니다. 새 기록은 새 D-FET Trainer 앱(TestFlight)에서 작성해 주세요. 기기에만 남아 있고 서버에 저장되지 않은 초안이 있다면 그 전에 알려 주세요.

(날짜는 실제 적용일로 바꾼다. 초안 확인은 §9 MIG-07.)

**T-1일: 리허설과 최신 실사.**

- [ ] `main`의 migrations CI 초록(DF-031, DF-100 테스트 포함).
- [ ] 에뮬레이터 적용→롤백→재적용 리허설 기록(V1-T10, 에이전트 첨부 가능).
- [ ] MIG-02 재실행(§4.3) — 수량이 크게 달라졌으면 적용을 미룬다.
- [ ] 스위치 PR(DF-100, `legacyV1WritesOpen()`을 `false`로, V1-05 §7.1 순서 3) 리뷰 완료, 병합 대기.
- [ ] MIG-08 1단계 확인(§10.1): (가) 경로면 `main` `firestore.rules`에 `trainerWorkspaces` 블록이 없음을 `git grep -c 'trainerWorkspaces' main -- firestore.rules` = 0으로 기록한다. (나) 경로면 스위치 PR에 §10.1의 쓰기 중단 블록이 들어 있고 규칙 테스트(본인 read 허용, create·update·delete 거부)가 초록인지 확인한다.
- [ ] G-03 증빙(DF-931 배포, S-09 실환경 확인) 완료.
- [ ] 백업 버킷(§2.5) 준비.

**T0(적용일, 사용량이 적은 시간대, 약 90분).**

| 순서 | 할 일 | 명령·확인 |
|---|---|---|
| 1 | 내보내기 #1(스위치 전 안전본) | `gcloud firestore export gs://dfetmanage-mig-backups/mig03/<TS>-pre --collection-ids=soap_notes` 완료까지 대기(`gcloud firestore operations list`) |
| 2 | 스위치 PR 병합과 규칙 배포 | `gh pr merge <DF-100 스위치 PR> --squash` → `git pull` → `git tag rules-YYYYMMDD-N` → `firebase deploy --project dfetmanage --only firestore:rules` → `git push origin rules-YYYYMMDD-N` |
| 3 | 배포 확인 | §2 3단계와 같은 방식으로 운영 규칙 원문을 받아 `grep -c 'legacyV1WritesOpen() { return false; }'` = 1. MIG-08 1단계: (가)면 `grep -c 'trainerWorkspaces'` = 0, (나)면 블록 안 `allow create, update, delete: if false;` = 1. 결과를 V1-T10에 MIG-08(1) 행으로 기록 |
| 4 | 내보내기 #2(스위치 뒤, 쓰기 없는 일관본) | `gcloud firestore export gs://dfetmanage-mig-backups/mig03/<TS>-post --collection-ids=soap_notes` |
| 5 | dry-run | §5.5 운영 dry-run. 보고서의 `scanned`가 MIG-02 `total`과 같은지, `failed` 0인지, `toObjectiveMetrics` 0인지 확인 |
| 6 | apply | §5.5 운영 apply(`--backup-confirmed …-post`). 종료 코드 0 |
| 7 | 재실행(멱등 확인) | 같은 apply 명령을 한 번 더: `migrate.written`·`hygiene.written` 0, `already.alreadyMigrated`가 1차 `migrate.written`과 같음 |
| 8 | verify | §5.5 `--verify`. 종료 코드 0 |
| 9 | 샘플 렌더 확인(MIG-06) | §8.5 |
| 10 | 태그와 기록 | `git tag mig03-apply-YYYYMMDD <스크립트를 실행한 main 커밋>` → `git push origin mig03-apply-YYYYMMDD`. V1-T10 `docs/v1/migrations/MIG-03-YYYYMMDD-<runId>.md`에 dry-run·apply·verify 수량 기록 |
| 11 | 이어서 | DF-925(플래그 개방)는 G-04·G-09·G-05a·G-03이 모두 충족됐을 때만 |

### 5.9 검증 쿼리(`--verify`)

모두 Admin SDK `count()` 집계다. 값은 출력하지 않는다.

| # | 쿼리 | 기대 | PRD 수용 기준 |
|---|---|---|---|
| V1 | `soap_notes.where('migratedFrom.runId','==',R).count()` | = `migrate.written`(누적) | MIG-03 |
| V2 | `where('migratedFrom.runId','==',R).where('authorUid','==',null)` → 0, 그리고 샘플 없이 `where('schemaVersion','==',2)` 중 `authorUid` 누락 0(`orderBy('authorUid')` 개수 비교) | 0 | 모든 이관 문서에 `authorUid` |
| V3 | `where('isSharedWithMember','==',true).count()` | 0 | MIG-05 |
| V4 | `where('diagnosis','!=',null).count()` | 0 | MIG-04 |
| V5 | `where('drawingData','!=',null).count()` | 0(`--backup-confirmed` 사용 시) | MIG-06 |
| V6 | `where('structured.subjective.nativeInkDataBase64','>','').count()` | 0(같음) | MIG-06 |
| V7 | `where('legacy.inlineInk','!=',null).count()` | 0(같음) | MIG-06 |
| V8 | `memberSummaries.count()` | 적용 전과 같음(0) | MIG-05 요약 자동 생성 없음 |
| V9 | `where('schemaVersion','==',2).where('exerciseAssessment.summary','!=',null)` 중 `migratedFrom.runId==R` | 0 | MIG-04(이관이 exerciseAssessment를 쓰지 않음) |
| V10 | Storage `soapInk/` 객체 수 | = `ink.uploaded + ink.skippedSameHash` | MIG-06 |

- V9의 `!=` 쿼리는 복합 인덱스가 필요할 수 있다. 없으면 스크립트가 `migratedFrom.runId==R` 결과를 스트림으로 훑어 `exerciseAssessment` 키 존재만 센다(값은 읽지 않음).
- 규칙 수용 기준(이관된 finalized 문서의 원문 update 거부, v1 쓰기 거부)은 운영에서 시험하지 않고 DF-022·DF-100 에뮬레이터 테스트(R-08, R-21)로 증빙한다.
- 교차 클라이언트 읽기(PRD §12.5): `contracts/fixtures/soap_legacy/expected_v2/*.json`을 Dart(DF-007)·Swift(DF-009) 코덱 테스트가 모두 읽는 것으로 증빙한다.

### 5.10 테스트(에이전트, DF-031·DF-100)

| ID | 종류 | 입력 | 기대 |
|---|---|---|---|
| TC-M03-01 | 단위 | `parseNumericValue` 표: `40`, `"40"`, `"40도"`, `"40°"`, `"4/5"`, `"4+"`, `"110-120"`, `"30, 40"`, `""`, `null` | 각각 number·number·number·number·slashFive·symbolGrade·range·multi·empty·empty |
| TC-M03-02 | 단위 | `mapStatus` 8개 표기 + `"완료됨"` | §5.4.2, 마지막은 `unknownStatus` |
| TC-M03-03 | 단위 | pain 규칙: painNow 5 / painNow 없음+pain행 1개 `"7"` / pain행 2개 / pain행 `"7-8"` | 5 / 7 / null / null |
| TC-M03-04 | 단위 | trainer_ios origin, painNow 0 | `painNrs: null`, `trainerIosZeroToNull` 1 |
| TC-M03-05 | 단위 | exercise 2행 + 기존 homeExercise | 줄바꿈으로 덧붙임, 원문은 metricsRaw |
| TC-M03-06 | 단위 | `memberId` 네 형식 | `member-` seed·미담당·users 없음·빈 값 → `hygiene`, 담당 uid → `migrate` |
| TC-M03-07 | 단위 | 원본 전 필드 → `legacy.flat`·`legacy.structured` | 원본 키 합집합 = v2 키 + `legacy.flat` 키 + `legacy.structured` 키 + 이동 필드(무손실) |
| TC-M03-08 | e2e | `contracts/fixtures/soap_legacy/*.json` 시드 → apply | 결과 = `expected_v2/*.json`(`updatedAt`, `legacy.migratedAt` 제외) |
| TC-M03-09 | e2e | apply 2회 | 2회차 쓰기 0 |
| TC-M03-10 | e2e | apply → rollback → apply | 롤백 뒤 = 시드 원본(인라인 필기 포함), 재적용 = TC-M03-08 |
| TC-M03-11 | e2e | 롤백 전 v2 문서 하나를 `updatedAt` 변경으로 편집 | 그 문서만 `conflictEdited`, 나머지 롤백 |
| TC-M03-12 | 단위 | 보고서 직렬화에 문자열 값(uid 모양) 주입 | 예외 |
| TC-M03-13 | 단위 | `target.js`: 운영 + 에뮬레이터 변수 / apply에 run-id 없음 / report 불일치 / `--i-am-owner` 없음 / 저장소 안 `--out` | 모두 종료 코드 2 |

---

## 6 MIG-04 diagnosis와 규제 문구

| 항목 | 내용 |
|---|---|
| PRD | §11.5, §3.4, F-PRIV-06, 부록 C |
| 스토리 | DF-028(Runner 동결 예외 수정, S04), DF-029(회원 앱 4개 파일, S04), DF-010·DF-040(copy-lint), DF-911(스토어 제출, S04), 데이터는 §5(DF-031·DF-924) |
| 선행 | MIG-01(`main` 기준 확정), DF-930(동결 선언), DF-010(보고 모드 린트) |
| 게이트 | G-05a 제출 전 배포(DF-910은 DF-911 뒤), P0 종료 시 출시 두 앱 빌드의 금지어 린트 통과(DF-040) |

### 6.1 데이터

§5에서 처리한다. `diagnosis` → `legacy.diagnosisRaw`, 최상위 키 삭제, `exerciseAssessment`에 복사 금지. 검증은 §5.9 V4·V9.

### 6.2 출시 앱 문구 — `main` 줄 번호 대응표

MIG-01 뒤 `main`의 Runner 파일은 HEAD 판(8,800줄)이다. PRD·DF-028의 줄 번호(작업 트리 9,657줄)와 다르므로 DF-028은 아래 **`main` 열**을 기준으로 고친다. 두 열 모두 2026-09-24 직접 확인했다.

| 대상 | PRD·보관 브랜치 tip(작업 트리) | `main`(HEAD `d841412` 판) | DF-028 조치 |
|---|---|---|---|
| 프로그램명 목록('체형 교정', '재활 트레이닝' 포함) | `AppDelegate.swift:2857` | `:2062` | 부록 C 대체어로 교체 |
| 프로그램 자리 표시 subtitle "운동 처방, 세트, 반복, 강도, 진행도를 관리합니다." | 없음(작업 트리에서 삭제됨) | `:613` | "운동 계획, 세트, 반복, 강도, 진행도를 관리합니다."로 교체(V1-12 X-06, C1-08) |
| 네이티브 SOAP 문서 ID `native_<seed>_<date>` | `:3838` | `:3043` | 동결 앱 코드는 두고(MIG-03 스위치 뒤 규칙이 거부), 수정 대상 아님 |
| `memberId` 로컬 seed | `:3839` | `:3044` | 같음 |
| diagnosis 자동 채움 `"diagnosis": selectedMember.subtitle` | `:3844` | `:3049` | 키 제거 |
| 필기 base64 인라인 | `:3858` | `:3063` | 같음(MIG-06 대상) |
| '치료계획, 홈운동…' 안내 | `:4319`, `:4328` | `:3524`, `:3533` | 대체어 |
| '치료계획' subtitle·placeholder | `:4725-4726` | `:3930-3931` | 대체어 |
| '세션 중 치료/운동 계획' placeholder | `:8717` | `:7860` | 대체어 |
| '진단/이슈' 입력 필드 | `:8958` | `:8101` | 입력 필드 제거 |
| 워크스페이스 `diagnosis` 인자·저장 | `:8367`, `:9031` | `:7510`, `:8174` | 자동 채움 제거와 함께 빈 값만 전달하도록 수정 |
| 미리보기 시드 `"diagnosis": "허리 관리"` | `:221`, `:332` | `:194`, `:305` | 미리보기 전용. 키 제거(린트 대상) |

회원 앱(4개 파일, `main`과 작업 트리 줄이 같다 — 해당 파일은 A 커밋에 변경이 없거나 줄 이동이 없음을 확인)

| 파일 | 줄 | 현재 문구 | DF-029 조치 |
|---|---|---|---|
| `lib/screens/guide_screen.dart` | :36-41 | "체형 분석", "AI를 이용해 체형 불균형을 분석합니다", "AI가 거북목, 골반 불균형 등을 분석" | 부록 C 대체 문장 |
| `lib/screens/onboarding_screen.dart` | :40 | "체형 교정" | 대체어 |
| `lib/screens/profile_setup_screen.dart` | :38 | "체형 교정" | 대체어 |
| `lib/screens/create_request_screen.dart` | :150 | '새로운 자세 교정 요청' | 대체어. 이 파일은 C09로 먼저 커밋된 뒤 DF-029가 고친다 |

- 대체어 자체는 부록 C와 [V1-12](12_COPY_ANALYTICS_AND_LINT.md)가 정본이다.
- 보관 브랜치의 같은 문구는 고치지 않는다(병합하지 않으므로). 대신 이식(DF-039 이후) 때 copy-lint가 새 앱 문자열 카탈로그에서 걸러낸다.

### 6.3 동결 예외 PR 규칙(DF-028)

- 라벨 `freeze-exception`, `regulatory`. PR 본문 '동결 예외 사유'에 "MIG-04 규제 문구·diagnosis 자동 채움 제거(PRD §11.5)"를 적는다.
- 변경 범위는 §6.2 표의 줄만. 다른 리팩터링 금지.
- 확인: `git grep -n '"diagnosis"' -- ios/Runner/AppDelegate.swift` 결과에서 자동 채움 줄이 없어짐, `node tool/lint/prohibited-terms.mjs --paths ios/Runner lib/screens`에서 해당 위반 0.

### 6.4 릴리스와 증빙

1. DF-028·DF-029 병합 → `member-vX.Y.Z` 태그 → 스토어 제출(DF-911).
2. DF-040으로 copy-lint 차단 모드 전환(출시 앱 문자열 포함).
3. DF-910 식약처 제출 증빙에 "출시 앱 문구 정리 배포 완료"를 첨부한다.

### 6.5 롤백

문구 수정은 되돌리지 않는다. 크래시가 생기면 이전 빌드로 단계적 출시를 멈추고 수정 빌드를 낸다(§12.4 '크래시 급증').

---

## 7 MIG-05 isSharedWithMember 레거시 처리

| 항목 | 내용 |
|---|---|
| PRD | §11.6, D9 |
| 처리 | §5(`migrate`는 `false` 고정, `hygiene`는 `true→false`), `legacy.originalIsShared` 보존. 요약 자동 생성 없음 |
| 검증 | §5.9 V3, V8. 회원 계정의 `soap_notes` list·get 거부는 DF-020 규칙(R-10)과 DF-022 테스트로 증빙 |
| 순서 주의 | 회원 앱이 아직 `soap_notes`를 직접 조회하는 경로(MB-03·04 교체 전)는 규칙 v2 배포(DF-931) 뒤 **권한 오류**를 받는다. 회원 앱은 오류를 빈 목록으로 삼키지 않고 '불러오기 실패'를 보여야 하며(§10.5), MB-03·04 교체는 P2 DF-315다. 그 사이 회원 앱 SOAP 탭은 실패 상태가 정상이다(ASM-11-12) |
| 롤백 | §13(`legacy.originalIsShared`로 복원). 단 규칙은 이미 회원 읽기를 막으므로 복원해도 노출되지 않는다 |

---

## 8 MIG-06 인라인 필기 이전

| 항목 | 내용 |
|---|---|
| PRD | §11.7, §9.5, NFR-05 |
| 스토리 | DF-031(`lib/inkMover.js`), DF-924(운영) |
| 선행 | Storage 규칙 배포(DF-023 → DF-931, soapInk 경로), 백업 확인(`--backup-confirmed`) |

### 8.1 대상

| 형식 | 위치 | 출처 |
|---|---|---|
| trainer_ios `drawingData`(Firestore Bytes, PKDrawing `dataRepresentation`) | 최상위 `drawingData` | dfet:trainer_ios/DFETTrainer/Data/FirebaseTrainerRepository.swift:88, :251, :356-357 |
| 네이티브 브리지 base64 문자열 | `structured.subjective.nativeInkDataBase64`(빈 문자열이면 필기 없음) | dfet:lib/widgets/shells/trainer_shell.dart:321(`main`), :505(보관 브랜치 tip) |

### 8.2 절차(`inkMover.uploadAndVerify`)

1. 바이트 준비: Bytes는 그대로, base64는 `Buffer.from(s, 'base64')`. 길이 0이면 필기 없음.
2. `sha256`과 `size` 계산.
3. 경로 `soapInk/{noteId}/1.drawing`. 객체가 이미 있으면 `customMetadata.sha256`을 비교해 같으면 업로드를 건너뛰고(`skippedSameHash`), 다르면 `pathConflict`로 이 문서를 건너뛴다.
4. 업로드: `file.save(bytes, {resumable: false, contentType: 'application/octet-stream', metadata: {customMetadata: {sha256, runId, source: 'MIG-06'}}, preconditionOpts: {ifGenerationMatch: 0}})`.
5. 대조: 다시 내려받아 `sha256`·`size`가 같은지 확인. 다르면 객체를 지우고 `hashMismatch`로 문서를 건너뛴다.
6. Firestore 기록(§5.4.7 트랜잭션 안): `inkPath`, `inkRevision = 1`, `legacy.inkOrigin`.
7. 인라인 제거: `--backup-confirmed`가 있고 그 경로의 내보내기 메타데이터가 확인됐을 때만. `migrate`는 v2 문서에 인라인을 싣지 않고, `hygiene`는 원래 필드를 `FieldValue.delete()`. 없으면 `migrate`는 `legacy.inlineInk`에 바이트를 남기고 `hygiene`는 원래 필드를 둔다(`inlineRetained`).
8. 백업 확인 없이 적용했다면, 내보내기를 받은 뒤 `--apply --run-id <같은 runId> --backup-confirmed …`로 다시 실행한다. 이미 이관된 문서는 `legacy.inlineInk`만 지우는 경량 경로를 탄다(멱등).

- PNG 미리보기(`soapInk/{noteId}/{rev}.png`)는 만들지 않는다. Node에서 PKDrawing을 렌더할 수 없기 때문이다. 트레이너 앱은 `.drawing`을 PencilKit으로 렌더한다(ASM-11-13).
- 5MB 초과 필기도 이관한다(Admin SDK는 크기 규칙 무관). 새 앱이 그 파일을 읽는 데는 문제가 없고, 새 개정본 업로드만 5MB 제한을 받는다. 수량은 `gt5MB`로 보고한다.

### 8.3 검증

§5.9 V5·V6·V7·V10. 해시 대조는 업로드 단계에서 문서마다 이미 수행한다.

### 8.4 롤백

`mig03_06_rollback.js`가 `legacy.inlineInk`가 있으면 그 바이트로, 없으면 Storage 객체를 내려받아 `sha256` 대조 뒤 원래 위치(`legacy.inkOrigin`)에 복원한다. Storage 객체는 `--delete-ink-objects`를 줄 때만 지운다(기본 유지).

### 8.5 샘플 렌더 확인(소유자, T0 9단계)

- 인라인 제거 **전**(내보내기 #2 뒤, apply 전)에 동결 Runner에서 필기가 있는 기록 3건을 열어 획이 보이는지 확인하고, apply 뒤 새 트레이너 앱(TestFlight, `soapV2` 플래그와 무관하게 읽기 가능)에서 같은 기록을 열어 비교한다.
- V1-T10에는 "3건 일치/불일치"만 적는다. 화면을 캡처하지 않는다(원칙 ④).
- 불일치가 있으면 인라인 제거를 하지 않은 상태로 멈추고(`--backup-confirmed` 없이 재적용) 원인을 조사한다.

---

## 9 MIG-07 로컬 UUID SOAP 초안

| 항목 | 내용 |
|---|---|
| PRD | §11.8, Q-06(기본값: 자동 이관 없음) |
| 스토리 | DF-924(서버 수량 보고, 기기 확인 시작), DF-387 선행 조건(제거 전 전원 기록) |
| 책임자 | 소유자 + 각 트레이너 |

### 9.1 서버 측

- MIG-03 보고서의 `skipReason.memberSeed`, `uidNotInUsers`, `uidNotAssigned`, `memberIdEmpty` 수량이 곧 '서버의 `member-` 문서 처리 결과'다. 이 문서들은 `hygiene` 처리 뒤 v1 읽기 전용으로 남는다.
- 기본 처리: 보존(읽기 전용). 트레이너가 새 앱에서 필요한 내용을 재입력한다(동의 ② 받은 회원만). 자동 연결·이메일 매칭 금지.
- 파기 시점: 보유기간 정책(Q-24) 확정 뒤 별도 결정. 현재 `purgeExpiredRecords`(DF-133) 대상 조건(`trainerId == null` + 보유기간 경과)에 들지 않는다(Q-DEV-11-01).

### 9.2 기기 측(트레이너별, S09 공지 뒤 ~ DF-387 전)

1. 트레이너가 동결된 Runner 트레이너 화면을 연다.
2. 회원 목록에서 서버 저장 표시가 없는 SOAP 초안이 있는지 확인한다(로컬 UUID 회원, `UserDefaults` 초안).
3. 필요한 초안만 새 앱에서 해당 회원(uid 담당 회원 또는 TR-14 대기 회원, 동의 ② 확인)으로 재입력한다.
4. 소유자가 V1-T10 변형 기록(`docs/v1/migrations/MIG-07-<트레이너 코드>.md`)에 **수량만** 남긴다: 확인 일자, 발견 초안 수, 재입력 수, 폐기 수, "로컬 초안 처리 완료" 체크. 트레이너 코드는 `T01`처럼 가명으로 쓴다.

- 동결 앱의 '로컬 초안 내보내기' 같은 새 기능은 만들지 않는다. 필요하면 소유자 승인 후 `freeze-exception` PR로만(PRD §11.8 대안).

### 9.3 수용 기준 증빙

- Runner 트레이너 제거(DF-387) 전에 MIG-02 `claims.trainer` 수와 같은 수의 '처리 완료' 기록.
- MIG-03 보고서에 `member-` 관련 수량.

### 9.4 롤백

해당 없음(자동 이관을 하지 않으므로). 동결 앱은 P3 제거 전까지 열람 수단으로 남는다.

---

## 10 MIG-08 trainerWorkspaces 폐기

| 항목 | 내용 |
|---|---|
| PRD | §11.9, Q-05, AS-21 |
| 스토리 | 1단계: DF-100(규칙 hunk, S08 스위치 PR)·DF-924(배포·확인, S09, P1a 전환). 2~3단계: DF-138(P1a S14). 4단계: DF-330(P2 S25-S26) |
| 선행 | MIG-01 2단계 결과, MIG-02 `trainerWorkspaces.docs`, F-LINK-01(대기 회원, DF-108) |

### 10.1 두 갈래

MIG-01 조사 결과 trainerWorkspaces 규칙·서비스·채널은 **HEAD에 없고 미커밋 작업 트리에만** 있었다. 따라서 경로가 둘로 갈린다.

| 경우 | 판정 근거 | 1단계 | 2~3단계(가져오기) | 4단계(제거) |
|---|---|---|---|---|
| (가) 운영 미배포, 문서 0 | MIG-01 2단계 `0`, MIG-02 `docs == 0` | `main` 규칙에 블록 없음 = 기본 거부. S09 DF-924에서 확인·기록만 | '해당 없음'. DF-138은 "가져오기 경로 없음" 확인으로 축소 | DF-330은 "match 블록·서비스 코드 없음" 확인과 기록으로 축소 |
| (나) 운영 배포됨 또는 문서 있음 | 2단계 `≥1` 또는 `docs > 0` | DF-100 스위치 PR(S08)에서 `create, update, delete: if false`로 바꾸고 `read`(본인)는 유지. DF-924(S09)가 v1 차단 스위치와 같은 배포로 내보낸다 | 아래 10.2 | 아래 10.3 |

(가)가 예상 경로다. 규칙이 배포된 적이 없는데 문서가 있으면(관리자 도구로 썼을 가능성) (나)로 간다. 그때 `main` 규칙에 읽기 블록이 없으므로 DF-100 스위치 PR이 **읽기 전용 블록을 추가**해야 한다(ASM-11-14). S14 DF-138의 가져오기가 이 블록의 본인 read에 기대므로 1단계는 가져오기보다 먼저 배포돼 있어야 한다.

1단계는 PRD §11 MIG-08 'P1a 전환'에 맞춰 v1 SOAP 쓰기 차단(MIG-03)과 **같은 규칙 배포(S09)** 로 묶는다. 새 트레이너 앱은 처음부터 이 컬렉션을 쓰지 않으므로(F-LINK-03.3) 앱 쪽 작업은 없고, 막아야 할 쓰기는 동결된 Runner·Flutter 폴백 경로다. (나) 경로의 규칙 블록(DF-100 PR에 넣는 hunk):

```
match /trainerWorkspaces/{trainerId} {
  // MIG-08 1단계(P1a 전환): 신규 쓰기 중단. 본인 read는 DF-138 1회용 가져오기용으로 DF-330 제거까지 유지
  allow read: if (isTrainer() && isOwner(trainerId)) || isAdmin();
  allow create, update, delete: if false;
}
```

블록은 V1-05 §7의 `trainerWorkspaces` 블록과 같다(`isTrainer`·`isOwner`·`isAdmin`은 기존 헬퍼, dfet:firestore.rules:5, :28, :33). 규칙 테스트는 `functions/test/rules/trainerWorkspaces.rules.test.js`에 본인 read 허용, 타인 read 거부, 본인 create·update·delete 거부 세 건을 둔다(DF-100 PR에 포함). V1-05 §7.1 배포 순서 표의 4번 행(DF-138, 'P1a 전환')은 이 문서 기준으로 DF-100 → DF-924(순서 3과 같은 배포)로 읽는다(CF-11-11).

### 10.2 1회용 가져오기(DF-138, (나)일 때)

- 트레이너 앱 TR-15(설정) 안 1회용 메뉴 '이전 작업공간 가져오기'. `trainerWorkspaces/{uid}`를 한 번 읽는다.
- `membersJson`은 `NativeTrainerMemberPayload` 배열이다(dfet:ios/Runner/AppDelegate.swift:8283-8302, 보관 브랜치 tip). 여기에는 이름 외에 이메일, 주관·객관·평가·계획 텍스트, 통증, 아바타 이미지가 들어 있다. **파싱 직후 `name`만 남기고 나머지는 메모리에서 버린다.** 로컬 저장·로그·분석 이벤트에 어떤 필드도 남기지 않는다. `scheduleItemsJson`은 파싱하지 않는다(Q-05, AS-21).
- 후보 목록(표시명만)에서 트레이너가 한 명씩: (1) 기존 담당 회원(uid)과 연결 표시만 하거나 (2) TR-14 흐름으로 대기 회원을 만든다(최소 정보 + 만 14세 확인). 자동 생성 0건.
- 완료 뒤 앱은 로컬에 '가져오기 완료'를 기록하고 메뉴를 숨긴다. 서버 `trainerWorkspaces`에는 쓰지 않는다(규칙상 불가).
- 수용 기준 증빙: `pendingMembers`에 건강정보 필드 0건(규칙 화이트리스트로 보장, R-18 계열 테스트), 트레이너별 가져오기 완료 기록(V1-T10 변형, 수량만).

### 10.3 제거(DF-330, (나)일 때, P2 종료 전)

```bash
# 1) 내보내기 백업
gcloud firestore export gs://dfetmanage-mig-backups/mig08/<TS> --collection-ids=trainerWorkspaces
# 2) dry-run: 문서 수·총 크기만
node functions/scripts/migrations/mig08_remove_trainer_workspaces.js --project dfetmanage --report-dir ~/dfet_mig_reports
# 3) 적용
node functions/scripts/migrations/mig08_remove_trainer_workspaces.js --project dfetmanage --report-dir ~/dfet_mig_reports \
  --apply --run-id <runId> --backup-confirmed gs://dfetmanage-mig-backups/mig08/<TS> --i-am-owner
# 4) 규칙 블록 제거 PR(DF-330) 병합 → rules 태그 → 배포
# 5) 확인
node functions/scripts/migrations/mig08_remove_trainer_workspaces.js --project dfetmanage --verify   # docs == 0
git grep -n 'trainerWorkspaces' main -- firestore.rules lib functions   # 0
```

- 가져오기를 끝내지 않은 트레이너가 있으면 P2 종료 시점에 소유자가 확인 후 진행한다(PRD §11.9 4).
- 삭제 연쇄(`deleteMemberCascade`, DF-132)는 trainerWorkspaces를 대상으로 삼지 않는다. 회원 키가 없는 blob이라 찾을 수 없기 때문이다. 이 제거가 곧 '삭제 연쇄 누락 해소'다(V1-05 §11).

### 10.4 롤백

`gcloud firestore import gs://dfetmanage-mig-backups/mig08/<TS> --collection-ids=trainerWorkspaces` 뒤 이전 `rules-*` 태그의 블록 재배포(§13).

---

## 11 MIG-09 Runner 내장 트레이너 동결과 제거

| 항목 | 내용 |
|---|---|
| PRD | §11.10, D2, NFR-01 |
| 스토리 | DF-930(동결 선언, S01), DF-028(동결 예외 첫 사례), DF-142(`trainer_ios/` 삭제, P1a), DF-387(제거, P3), DF-390 |
| 책임자 | 소유자 |

### 11.1 동결 대상 경로(`main` 기준)

| 경로 | 범위 |
|---|---|
| `ios/Runner/AppDelegate.swift` | 트레이너 화면·채널 전체(파일이 회원 앱 부트스트랩과 섞여 있으므로 파일 단위로 동결) |
| `lib/widgets/shells/trainer_shell.dart` | 전체 |
| `lib/screens/trainer/**` | `trainer_members_screen.dart`, `trainer_soap_notes_screen.dart`, `trainer_summary_screen.dart`(Android·Web 폴백) |
| `lib/router/app_router.dart`의 `/trainer` 라우트(:114)와 트레이너 리다이렉트(:62) | 해당 줄 |
| `lib/services/firestore_service.dart`의 SOAP 함수(`saveSoapNote` :660 등) | 해당 함수 |
| `trainer_ios/**` | 이식 원본. 신규 코드 금지, DF-142에서 삭제 |

### 11.2 동결 선언(DF-930, S01)

1. `.github/CODEOWNERS`(GH-09)에 위 경로를 소유자로 지정한다.
2. 라벨 `freeze-exception`을 만든다(DF-902의 `tool/backlog/labels.json`에 포함).
3. PR 템플릿(GH-08)의 '동결 예외 사유' 칸을 필수로 안내한다.
4. 허용 변경: 크래시, 데이터 유실, 보안·규제 수정(MIG-04 포함). 그 밖 변경은 병합하지 않는다.
5. 자동 차단은 두지 않는다. 동결 경로를 바꾸는 PR에 라벨이 없으면 소유자가 병합하지 않는 수동 통제다(Q-DEV-11-02).

### 11.3 MIG-03 스위치 뒤 동작

- 스위치 배포 뒤 동결 앱의 SOAP 저장(`saveNativeTrainerSoapNote` → Flutter `saveSoapNote`의 `set`)은 규칙에 거부된다. 동결 앱의 저장 실패 문구를 고치는 것은 동결 예외로도 하지 않는다(공지로 대신).
- 트레이너는 SOAP 작성을 새 앱으로 한다. 열람은 동결 앱에서 P3까지 가능하다(레거시 읽기 규칙).

### 11.4 기능 동등성 체크리스트(제거 조건)

DF-387 착수 전에 소유자가 채운다. 새 앱 대응이 '확인'이어야 제거한다.

| Runner 라우트·자산(`main` 기준 `NativeTrainerRoute` :7081, 보관 tip :7876) | 새 앱 | 처리 | 확인 증빙 |
|---|---|---|---|
| sessionBoard, summary | TR-01 | 이식 | DF-125 데모 |
| members(+등록 시트) | TR-02, TR-03, TR-14 | 이식, 데이터 모델 교체 | DF-113, DF-114, DF-108 |
| soap(Pencil, NRS, 바디맵, SceneKit, 작업공간) | TR-04~06 | 이식(SceneKit P2) | DF-116~123, DF-328 |
| SOAP 분석, 잔디 뷰, reports | TR-03, TR-10 | 이식 | DF-114, DF-214, DF-215, DF-329 |
| schedule | TR-01 로컬 '오늘' 목록 | 축소(AS-21) | DF-125 |
| program, alerts | 없음 | 이식 보류(AS-21) | 소유자 확인 기록 |
| settings | TR-15 | 이식 | DF-018 |
| MIG-07 기록 | — | 전 트레이너 '처리 완료' | §9.3 |
| Android 트레이너 사용자 | — | 0명 확인 | §11.5 |

### 11.5 제거 절차(DF-387, P3 S30-S32)

1. **Android·Web 트레이너 사용자 확인**: Firebase Auth는 플랫폼을 기록하지 않고 분석은 G-09 전 비활성이다. MIG-02 `claims.trainer` 명단(수량)과 트레이너 개별 확인으로 Android 사용자가 0명인지 기록한다(ASM-11-15).
2. 새 트레이너 앱 1.0이 모든 트레이너 기기에 설치됐는지 확인한다.
3. 회원 앱 제거 PR(동결 경로 전체, 라벨 `freeze-exception` 아님 — 계획된 제거):
   - `lib/widgets/shells/trainer_shell.dart` 삭제, `lib/screens/trainer/**` 삭제.
   - `app_router.dart`의 `/trainer` 라우트와 트레이너 리다이렉트를 "새 D-FET Trainer 앱을 사용해 주세요" 안내 화면으로 교체(트레이너 계정 로그인 시).
   - `AppDelegate.swift`에서 `dfet/native_trainer_home` 채널(`main` :30, :65), 트레이너 화면 타입 전체, `saveNativeTrainerSoapNote`·`nativeTrainerLogout` 호출(:146, :164) 제거.
   - `firestore_service.dart`의 SOAP 쓰기 함수 제거. 레거시 호환 필드 `memberId`를 쓰던 코드가 없어졌는지 확인하고, admin_web `users/[uid]/page.tsx:30` 건수 조회를 `memberUid`로 바꾸는 후속 작업을 PRD §9.3 호환 기간 종료 체크리스트에 올린다.
4. 확인
   ```bash
   git grep -c 'dfet/native_trainer_home' -- ios lib    # 0
   git grep -c "'/trainer'" -- lib/router               # 0 또는 안내 화면 라우트만
   flutter test && flutter build ios --release --no-codesign
   ```
5. `member-vX.Y.Z` 태그, 단계적 출시(Phased Release).
6. 수용 기준 증빙: 제거 릴리스 빌드에 채널 문자열 0건, 트레이너 계정 로그인 시 새 앱 안내, 회원 기능 회귀 테스트 통과(DF-390).

### 11.6 trainer_ios 정리(DF-142, P1a S13)

```bash
git switch main && git pull --ff-only
git tag archive/trainer_ios-final HEAD         # 삭제 직전 커밋
git push origin archive/trainer_ios-final
git switch -c chore/DF-142-remove-trainer-ios
git rm -r trainer_ios
# 문서·CI의 trainer_ios 경로 참조를 태그 경로(archive/trainer_ios-final:trainer_ios/...)로 갱신
git commit -m "chore(trainer): remove frozen trainer_ios (preserved at archive/trainer_ios-final)" -m "Refs: DF-142" -m "Trace: ADR-001, §10.2.1"
```

### 11.7 롤백

- 동결: 해당 없음.
- 제거 릴리스 문제: 단계적 출시 중지, 이전 빌드로(§13 표).

---

## 12 MIG-10 BodyPath 기존 기록

| 항목 | 내용 |
|---|---|
| PRD | §11.11, §10.4.3, G-07a, G-07 |
| 스토리 | DF-323(could, P2 S25-S26), 전제 DF-320(TR-13 가져오기), DF-917(G-07a), DF-935(lidarBeta 내부 개방) |
| 방식 | 별도 일괄 도구 없음. 트레이너가 TR-13 결과 패키지 가져오기를 한 건씩 실행 |

### 12.1 선행 체크리스트

- [ ] G-07a 증빙(로드맵 1~2, 결과 패키지 v1 내보내기, 패키지 테스트) — DF-917.
- [ ] `lidarBeta` 내부 트레이너 개방 — DF-935.
- [ ] 대상 회원 D-FET 동의 ②③ 서버 확인.
- [ ] **연구 참가자 제외 목록**: BodyPath 연구 자료(IRB·종이 동의서)의 Subject.code 목록을 소유자가 저장소 밖에서 관리한다. 목록에 있는 기록은 가져오지 않는다.

### 12.2 기록별 확인(트레이너 + 소유자)

| # | 조건 | 확인 방법 |
|---|---|---|
| 1 | 로드맵 단계 2 기준 폴더 → Scan·manifest 연결 | BodyPath 앱이 결과 패키지를 내보낼 수 있으면 충족(내보내기가 연결을 요구) |
| 2 | `isSynthetic == false` | TR-13 검증기가 거부(F-LIDAR-01) |
| 3 | 측정 시각 = `Scan.takenAt` | 없으면 검증기가 거부. 시각 추정 금지 |
| 4 | 동의 ②③ | TR-13이 서버 상태 확인 후 진행 |
| 5 | 매핑 | 최초 가져오기 때 트레이너가 회원을 확인하고 `linkMemberAlias`(system=bodypath) |
| 6 | 표시 | observedSection, 베타 라벨, 줄자값은 `referenceTapeCm`(보정 없음) |

### 12.3 검증

- `bodyScans` 중 `takenAt` 없음·`isSynthetic == true` 0건(규칙·검증기로 보장, 운영 `count()`로 확인).
- 같은 스캔 재가져오기: `meshSHA256` 중복 0건(`bodyScans.where('meshSHA256','==',h)`를 TR-13이 가져오기 전 확인).
- 동의 없는 회원 거부: DF-320 테스트.
- V1-T10 `MIG-10-YYYYMMDD.md`에 가져온 수, 거부 사유별 수만.

### 12.4 롤백

`lidarBeta` off(§12.4 'LiDAR 오해·실패율 급증'). 가져온 문서의 삭제는 동의 ③ 철회 경로(`purgeExpiredRecords`, DF-320 확장)나 회원 삭제 연쇄로만 한다. 별도 일괄 삭제 도구는 만들지 않는다.

---

## 13 MIG-11 롤백 계획

| 항목 | 내용 |
|---|---|
| PRD | §11.12, §12.4 |
| 스토리 | DF-031(롤백 도구), DF-100(리허설), 운영 실행은 소유자 |
| 원칙 | **v1 쓰기 차단 규칙은 어떤 롤백에서도 되돌리지 않는다**(R-21) |

### 13.1 대상별 롤백

| 대상 | 사전 조치 | 롤백 명령·절차 | 한계 |
|---|---|---|---|
| soap_notes 이관(MIG-03~06) | 내보내기 #1·#2, `legacy` 보존, runId | `mig03_06_rollback.js --project dfetmanage --run-id R --report-dir …`(dry-run) → `--apply --i-am-owner`. `migratedFrom.runId==R`인 문서는 `legacy`로 v1 재구성 후 `tx.set`, `legacy.hygieneRunId==R`인 문서는 위생 처리 역적용 | 적용 뒤 트레이너가 편집한 문서(`updatedAt != legacy.migratedAt` 또는 addenda 있음)는 `conflictEdited`로 건너뛴다. 소유자가 개별 판단 |
| 위 롤백 실패·대량 손상 | 내보내기 #2 | `gcloud firestore import gs://dfetmanage-mig-backups/mig03/<TS>-post --collection-ids=soap_notes` | import는 같은 ID 문서를 덮어쓰고, 이후 새로 생긴 문서는 지우지 않는다. 적용 뒤 작성된 v2 문서는 남는다 |
| 규칙·인덱스 | 배포마다 `rules-YYYYMMDD-N` 태그 | 아래 13.2 | v1 차단 스위치는 유지 |
| trainerWorkspaces 제거 | 내보내기, 트레이너 확인 기록 | §10.4 | |
| 트레이너 앱 전환 | P3 전까지 동결 앱 존재 | 단계적 출시(TestFlight 빌드 만료·배포 중지). 동결 앱은 열람 전용 | 동결 앱은 SOAP를 쓸 수 없다 |
| Runner 트레이너 제거 | 단계적 배포 | 배포 중지, 이전 빌드로 | |
| 기능 | 플래그 | §12.4(해당 플래그 off) | |

### 13.2 규칙 롤백 절차

```bash
git fetch --tags
git switch -c fix/rules-rollback-<TS> rules-YYYYMMDD-<이전 N>
# MIG-03 적용 뒤라면: 이전 태그가 스위치 true 시절이어도 반드시 false로 만든다
grep -n '@mig03-switch' firestore.rules
sed -i '' 's/function legacyV1WritesOpen() { return true; }/function legacyV1WritesOpen() { return false; }/' firestore.rules
grep -c 'legacyV1WritesOpen() { return false; }' firestore.rules    # 1
firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"
firebase deploy --project dfetmanage --only firestore:rules,storage
git tag rules-YYYYMMDD-<새 N> && git push origin rules-YYYYMMDD-<새 N>
```

- 이 브랜치의 변경은 PR로 `main`에 되돌림 커밋으로도 반영한다(다음 배포가 롤백을 덮어쓰지 않게).

### 13.3 soap_notes 롤백 재구성 규칙(`mig03_06_rollback.js`)

| v1 필드 | 복원 값 |
|---|---|
| 최상위 필드 | `legacy.flat` 전체 |
| `structured` | `legacy.structured` + `metrics = legacy.metricsRaw` |
| `diagnosis` | `legacy.diagnosisRaw`(있을 때) |
| `isSharedWithMember` | `legacy.originalIsShared`(있을 때), 없으면 키 없음 |
| 인라인 필기 | `legacy.inkOrigin`에 따라 `drawingData`(Bytes) 또는 `structured.subjective.nativeInkDataBase64`(base64). 바이트는 `legacy.inlineInk` 또는 Storage 객체(해시 대조) |
| 제거되는 키 | `schemaVersion`, `migratedFrom`, `authorUid`, `memberUid`, `sessionDate`, `status`, `finalizedAt`, `subjective`(v2 맵 → `legacy.flat.subjective` 문자열로), `plan`, `legalNature`, `inkPath`, `inkRevision`, `legacy`, v2 `createdAt`·`updatedAt`(→ `legacy.flat`의 숫자 값) |

- 롤백 보고서: `restored`, `hygieneReverted`, `conflictEdited`, `inkRestoredFromStorage`, `inkHashMismatch`, `failed`.
- 멱등: `migratedFrom`이 없고 `legacy.hygieneRunId`가 없으면 이미 롤백된 것으로 보고 건너뛴다.

### 13.4 리허설(수용 기준, DF-100)

에뮬레이터에서 적용 → 롤백 → 재적용이 모두 성공한다(TC-M03-10, TC-M03-11). 결과는 V1-T10 에뮬레이터 기록으로 DF-100 PR에 첨부하고, DF-924 T-1일 체크리스트에서 최신 `main`으로 다시 확인한다.

### 13.5 롤백 결정 기준(§12.4 '이관 오류' 구체화)

| 증상 | 판단 | 조치 |
|---|---|---|
| verify V1~V10 중 하나라도 불일치 | 즉시 | 플래그 개방(DF-925) 보류 → 원인 조사 → 필요 시 롤백 |
| 트레이너 앱에서 이관 문서 열람 실패가 여러 건 | 즉시 | 규칙·코덱 확인 → 코덱 수정이 빠르면 수정, 아니면 롤백 |
| 필기 렌더 불일치(§8.5) | 인라인 제거 전이면 멈춤 | 인라인 유지 상태로 원인 조사 |
| 보고서 `failed` > 0 | 수량 확인 | 해당 문서만 재실행(멱등), 반복 실패는 조사 |

---

## 14 에뮬레이터 리허설과 migrations CI

### 14.1 로컬 리허설(에이전트·소유자)

```bash
npm ci --prefix functions
firebase emulators:exec --only firestore,storage --project dfet-e2e \
  "npm --prefix functions run test:migrations"
```

`functions/test/migrations/` 구성

| 파일 | 내용 |
|---|---|
| `helpers/seed.js` | `contracts/fixtures/soap_legacy/*.json`(봉투 `{_fixture, path, data}`, 태그 `$ts`·`$serverTimestamp`·`$bytes`·`$int`, [P0 DF-005 픽스처 규약](backlog/P0.md#fixture-contract))을 Admin SDK로 시드. 가상 트레이너·회원(`fx-trainer-001`, `fx-member-001`)과 `trainers.memberIds` 포함 |
| `mig02.test.js` | DF-030 TC |
| `mig03_06.test.js` | TC-M03-08~11 |
| `mig08.test.js` | DF-330 dry-run·apply·verify |

- 픽스처는 합성 데이터만이다. 실데이터·운영 보고서를 픽스처로 옮기지 않는다.
- 기대 결과 경로는 `contracts/fixtures/soap_legacy/expected_v2/*.json`으로 통일한다(CF-11-02).

### 14.2 CI `migrations` job(DF-031)

```yaml
  migrations:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: {node-version: "22", cache: npm, cache-dependency-path: functions/package-lock.json}
      - uses: actions/setup-java@v4
        with: {distribution: temurin, java-version: "21"}
      - run: npm ci --prefix functions
      - run: node tool/lint/no-writes.mjs functions/scripts/migrations/mig02_inventory.js
      - run: npm --prefix functions exec -- node --test test/unit/legacy-mapping.test.js
      - run: npm install --global firebase-tools
      - run: firebase emulators:exec --only firestore,storage --project dfet-e2e "npm --prefix functions run test:migrations"
```

트리거는 `functions/scripts/migrations/**`, `contracts/fixtures/soap_legacy/**`, `firestore.rules` 변경 PR이다(V1-04 CI 표).

---

## 15 가정·충돌·열린 질문

### 15.1 가정(ASM-11-NN)

| ID | 가정 | 근거·관련 | 확인 시점 |
|---|---|---|---|
| ASM-11-01 | 회원 앱 UI 변경(§3.3 e)은 PRD 표에 이름이 없지만 B·C가 아니므로 A로 본다 | PRD §11.2 분류표, D13 | DF-901 소유자 확인 |
| ASM-11-02 | C00에서 `.gitignore`에 `/output/`, `/tmp/`를 추가한다(PRD "C … .gitignore 검토"의 구체안) | PRD §11.2 C | DF-901 |
| ASM-11-03 | 저장소를 비공개로 바꾸면 Actions 분량(특히 macOS 10배)이 제한되므로 `trainer-app` CI 빈도를 경로 필터·야간으로 조정할 수 있다 | ADR-013, V1-04 CI | DF-901 결정 직후, V1-03 용량 |
| ASM-11-04 | 32개 커밋의 개별 빌드 가능성은 보장하지 않고 PR tip CI로 판정한다 | G-01 | DF-901 |
| ASM-11-05 | DF-901 PR은 18개 기존 커밋을 보존하기 위해 스쿼시가 아닌 rebase 병합을 쓴다(ADR-014의 스쿼시 원칙에 대한 1회 예외). 브랜치 보호(선형 이력)는 DF-902 이후 켠다 | ADR-014, AS-DEV-11 | DF-901 |
| ASM-11-06 | MIG-02 보고서에 DF-030 형식보다 많은 분류 키(`metricValueForm`, `origin`, `painNow`, `textOverLimit`, `dateForm`, `assignmentMismatch`, `usersRoleAdmin`, `storage`)를 넣는다 | PRD §11.3 원칙 ①, §5 설계 입력 | DF-030 |
| ASM-11-07 | 운영 `soap_notes`·`trainerWorkspaces` 문서 수는 수천 건 이하(알파 전 운영). 스크립트는 스트리밍으로 쓰되 성능 튜닝은 하지 않는다 | PRD §12(1인 → 동료) | DF-907 보고서 |
| ASM-11-08 | MIG-03 회원 해석은 `trainers.memberIds`를 1차 기준으로 쓰고 `users.trainerId`와 어긋나면 전환하지 않는다 | ADR-003, PRD §11.4 memberId 행 | DF-907 `assignmentMismatch` |
| ASM-11-09 | 이관 백업 버킷 보존은 90일. 처리방침·파기 증빙에 적는다 | PRD §9.7 백업·리전, Q-24(법률 검토 대상) | G-09(DF-909) |
| ASM-11-10 | 레거시 `assessment`·`treatmentPlan`은 v2로 옮기지 않고 `legacy.flat`에만 둔다. `nextPlan`은 `plan.nextSession`, `subjective`(문자열)는 `subjective.chiefComplaint`로 옮긴다 | PRD §11.4 표에 텍스트 필드 매핑 없음, MIG-04 규제 취지 | DF-031 리뷰 |
| ASM-11-11 | trainer_ios 출처 문서의 `painNow == 0`은 미입력으로 보고 `painNrs = null` | PRD C 원칙(미입력과 0 구분), FirebaseTrainerRepository.swift:227 | DF-907 `painNow.int0` × `origin.trainerIos` |
| ASM-11-12 | 규칙 v2 배포(DF-931, S08)부터 MB-03·04 교체(DF-315, P2)까지 회원 앱의 트레이너 기록 탭은 '불러오기 실패' 상태다 | PRD D9, R-10 | DF-931 전 소유자 확인(회원 공지 필요 여부) |
| ASM-11-13 | 이관 필기에는 PNG 미리보기를 만들지 않는다 | §9.5(`.png`는 선택) | DF-031 |
| ASM-11-14 | trainerWorkspaces가 (나) 경로면 DF-100 스위치 PR(S08)이 `main` 규칙에 읽기 전용 블록을 새로 추가하고 DF-924(S09)가 배포한다 | PRD §11 MIG-08 'P1a 전환', §11.9, MIG-01 #4 | DF-907 |
| ASM-11-15 | Android 트레이너 사용자 확인은 트레이너 개별 확인으로 한다(Auth는 플랫폼 미기록, 분석은 G-09 전 비활성) | PRD §11.10 | DF-387 |
| ASM-11-16 | 배포 명령은 `firebase deploy --project dfetmanage --only …` 순서로 적는다(R7). 이관 에뮬레이터 프로젝트는 `dfet-e2e`, 픽스처 태그는 P0 DF-005 픽스처 규약(`$ts`·`$serverTimestamp`·`$bytes`·`$int`)을 따른다. DF-901은 2026-09-29(화) 12:00까지 병합한다(ASM-01-18, ASM-S01-01) | 교차 정합성 조정(R7), V1-10 §4.2, P0 ASM-P0-01, V1-01 ASM-01-18 | 정합 패스 2(2026-09-24) |

### 15.2 스파인·다른 문서와의 충돌(CF-11-NN)

| ID | 충돌 | 이 문서의 처리 | 정리 필요 문서 |
|---|---|---|---|
| CF-11-01 | 스크립트 이름이 문서마다 다르다: DF-031 카드 `mig03_06.js`·`mig03_06_rollback.js`·`lib/target.js`, DF-100 카드 `mig03_soap_v2.js`·`mig03_rollback.js`·`lib/applyGuard.js`, P2 카드 `mig08-remove-trainer-workspaces.js` | DF-031 카드 이름을 정본으로 삼고(§2.3), DF-100의 가드 규칙(`--run-id` 일치, `--i-am-owner`)은 `lib/target.js`에 합쳤다. MIG-08은 `mig08_remove_trainer_workspaces.js`(snake) | V1-02 P1a(DF-100), P2(DF-330) 카드 |
| CF-11-02 | 이관 기대 결과 경로가 셋이다: `contracts/fixtures/soap_legacy/expected_v2/`(DF-005·DF-031 카드), `contracts/fixtures/soap_legacy_expected/`(V1-05 §13.4), `contracts/fixtures/soap_v2/migrated/`(DF-100 카드) | `soap_legacy/expected_v2/`로 통일 | V1-05 §13.4, DF-100 카드 |
| CF-11-03 | AC-DF-031.7은 미해결 회원 문서를 "원문 유지"라 하는데, PRD MIG-05·06 수용 기준(`isSharedWithMember=true` 0건, 인라인 잔존 0건)은 컬렉션 전체 기준 | 전환은 하지 않되 위생 처리(§5.6)를 한다 | DF-031 AC 추가 |
| CF-11-04 | PRD §9.3 `legacy` 맵은 네 키로 정의되어 있으나 롤백에 `flat`·`structured`(DF-031 ASM-P0-33)와 `inkOrigin`·`inlineInk`·`hygieneRunId`·`migratedAt`(이 문서)이 필요하다 | §5.4.6에 정의. `legacy`는 서버 전용이라 클라이언트 규칙 영향 없음 | DF-006(스키마 문서·JSON Schema), V1-05 §5, PRD §9.3 개정 제안(§13.4 절차) |
| CF-11-05 | 위생 처리된 v1 문서에도 `inkPath`·`legacy`가 생긴다. 코덱 스토리(DF-007, DF-009)는 v1에 이 필드가 없다고 가정할 수 있다 | v1 읽기에서 `inkPath` 우선 규칙을 명시 | DF-007·DF-009 카드, V1-05 §5.6 코덱 공통 |
| CF-11-06 | PRD·DF-028 카드의 Runner 줄 번호(:2857, :3844, :4319 …)는 작업 트리 기준이다. MIG-01 뒤 `main`은 HEAD 판이라 줄이 다르다 | §6.2 대응표로 `main` 줄을 제공 | V1-02 P0 DF-028 카드, V1-08 |
| CF-11-07 | PRD §11.2 #3의 규칙 테스트 줄 범위 `:160-209`는 실제 `:151-207`과 다르다 | §3.5에 실제 값 | PRD 변경 이력(소유자) |
| CF-11-08 | 원격 저장소가 PUBLIC이다. 스파인은 보관 브랜치 원격 푸시와 PRD 커밋을 전제한다 | 0단계 결정 D-MIG01-1 추가 | V1-01, ADR-014, ADR-019, 00_README |
| CF-11-09 | `main`이 초기 커밋뿐이고 기능 브랜치 18개 커밋이 원격에 없다. 스파인은 "A분류만 main에 병합"이라 적었지만 실제로는 기존 18개 커밋도 함께 올라간다 | §3.4에서 한 PR로 32개 커밋 병합 | V1-03 S01 계획(DF-901 소요 시간 약 3.5시간) |
| CF-11-10 | DF-100 카드는 "백업 → 스위치 배포 → dry-run" 순서, 이 문서는 내보내기를 스위치 전·후 두 번 받는다 | 두 번 받는 쪽이 상위집합이라 호환 | DF-100 카드 체크리스트 |
| CF-11-11 | 백로그 스파인은 DF-138(S14) acSummary에 '규칙 신규 쓰기 false'를 두지만, PRD §11 MIG-08과 V1-04 컬렉션 표는 신규 쓰기 중단을 'P1a 전환'(S09)에 둔다 | 1단계(규칙 hunk)는 DF-100 스위치 PR(S08)로 옮기고 DF-924(S09) 배포에서 확인한다. DF-138은 2~3단계(1회용 가져오기)만 맡고, 1단계는 '배포돼 있음'을 선행 조건으로 확인한다 | V1-02 P1a(DF-100·DF-138 카드, AC-DF-138.1은 DF-100으로 이동), V1-05 §7.1 순서 4, V1-03 S08·S09, tool/backlog/issues.json |

### 15.3 열린 질문(Q-DEV-11-NN)

| ID | 질문 | 기본값 | 관련 |
|---|---|---|---|
| Q-DEV-11-01 | 위생 처리만 된 v1 문서(`member-` seed 등)를 언제 파기하는가 | P3까지 보존, Q-24 확정 뒤 결정 | Q-06, Q-24, MIG-07 |
| Q-DEV-11-02 | 동결 경로 PR에 `freeze-exception` 라벨을 CI로 강제할 것인가 | 수동 통제 | MIG-09, DF-930 |
| Q-DEV-11-03 | 적용일 트레이너 공지 채널(메신저, 이메일)과 회원 대상 공지 필요 여부(ASM-11-12) | 트레이너만 직접 연락 | DF-924 |

---

## 16 변경 이력

| 버전 | 날짜 | 내용 | 작성 |
|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성. MIG-01 실제 분류(88항목), MIG-02~11 실행 절차와 스크립트 계약 | CJH(에이전트 초안) |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정(정합 패스 2): DF-901 시점(화 12:00), 배포 명령 순서(R7), 픽스처 태그 `$ts`, 이관 에뮬레이터 프로젝트 `dfet-e2e`(§2.2·§14.1·§14.2), §6.2 main :613 행, ASM-11-16 | CJH(에이전트) |

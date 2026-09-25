# contracts/fixtures/ — SOAP 교차 픽스처(DF-005)

Dart 코덱(DF-007), Swift 코덱(DF-009), JSON Schema 검증(DF-006), 이관 하네스(DF-030·DF-031)가 **같은 JSON 파일 하나**를 읽는다. 복사본을 만들지 않는다. Swift 테스트는 `#filePath`로 저장소 루트를 찾아 이 폴더를 직접 읽고, Flutter 테스트는 저장소 루트에서 돈다(V1-10 §5.3).

- 규약의 정본: [P0 DF-005 '픽스처 규약'](../../docs/v1/backlog/P0.md#fixture-contract). 아래 1~4번은 그 절을 옮긴 것이다. 두 곳이 어긋나면 P0 카드가 우선한다(ASM-P0-01).
- 필드 정본: PRD §9.3, [V1-05 §5](../../docs/v1/05_DATA_MODEL_AND_RULES.md#5-soap-스키마-v2). 레거시 어휘와 이관 규칙: PRD §11.4~§11.7, V1-05 §5.6.
- 검사: `tool/contracts/test/fixtures.test.mjs`(TC-DF005-01~04). CI `contracts` job이 자동으로 돈다.
- 모든 값은 합성이다. 운영 문서, `output/`, 실제 회원의 이름·메모·필기에서 가져오지 않는다. 이 경로는 금지어 린트의 예외 경로다(PRD 부록 C.3).

## 1. 봉투

파일 하나에 문서 하나. 최상위 키는 정확히 셋이다.

```json
{
  "_fixture": {
    "id": "soap_v2/finalized_no_metrics",
    "description": "확정 최소 요건(회원·날짜·한 줄·다음 계획)만 채운 v2 노트",
    "writer": "synthetic",
    "prdRefs": ["AC-SOAP-06.3", "§6.4.4"],
    "expect": { "roundTrip": "identical", "metricCount": 0, "uninterpretable": 0 }
  },
  "path": "soap_notes/fx-note-v2-001",
  "data": {
    "schemaVersion": 2,
    "trainerId": "fx-trainer-001", "authorUid": "fx-trainer-001",
    "memberUid": "fx-member-001", "memberId": "fx-member-001", "pendingMemberId": null,
    "sessionDate": { "$ts": "2026-09-28T01:00:00Z" },
    "status": "finalized",
    "quickNote": "가상 회원 A, 오른쪽 어깨가 뻐근하다고 말함",
    "objective": { "metrics": [], "refs": { "postureAssessmentIds": [], "bodyCompositionRecordIds": [], "circumferenceMeasurementIds": [], "bodyScanIds": [] }, "snapshots": [] },
    "plan": { "nextSession": "어깨 가동성 운동 이어서 진행", "homeExercise": "" },
    "legalNature": "coachingRecord",
    "isSharedWithMember": false,
    "finalizedAt": { "$ts": "2026-09-28T02:00:00Z" },
    "createdAt": { "$ts": "2026-09-28T01:00:05Z" },
    "updatedAt": { "$ts": "2026-09-28T02:00:00Z" }
  }
}
```

- `_fixture.writer`: `synthetic`(손으로 작성) | `dart`(DF-007 기록 모드) | `swift`(DF-009 기록 모드).
- `_fixture.expect` 키: `roundTrip`(`identical`), `metricCount`(v2 `objective.metrics` 길이), `uninterpretable`(해석 불가 행 수), `legacyMetricCount`(레거시 원본 metrics 길이). 파일에 해당하는 키만 쓴다.
- 코덱과 스키마 검증은 `data`만 대상으로 한다. `_fixture`와 `path`는 테스트 하네스만 읽는다(이관 하네스는 `path`로 시드한다).

## 2. 타입 태그(`data` 안에서만 쓴다)

| 태그 | 뜻 | Dart | Swift(`JSONValue`) |
|---|---|---|---|
| `{"$ts": "<ISO 8601, Z 또는 오프셋>"}` | Firestore Timestamp | `Timestamp` | `.timestamp(Date)` |
| `{"$serverTimestamp": true}` | 쓰기 페이로드의 서버 시각 자리 | `FieldValue.serverTimestamp()` | `.serverTimestamp` |
| `{"$bytes": "<base64>"}` | 레거시 인라인 바이너리(`drawingData`) | `Blob` | `.bytes(Data)` |
| `{"$int": n}` | Firestore 정수여야 하는 값: `painNrs`, `mmtGrade`의 `value`, `inkRevision`, `trialIndex` | `int` | `.int(Int64)` |
| 맨 숫자 | 실수 허용 값(`value` 등). 비교는 값으로(45 == 45.0) | `num` | `.number(Double)` |

## 3. 합성 식별자

문서 ID·uid는 `fx-` 접두사(`fx-trainer-001`, `fx-member-001`, `fx-pending-001`, `fx-note-v2-001`). 예외는 레거시 표기를 재현하는 두 가지뿐이다: 네이티브 문서 ID `native_fx_<yyyymmdd>`와 레거시 회원 seed `member-00000000-0000-4000-8000-00000000000N`. 이름은 '가상 회원 A' 형식, 이메일은 `@example.invalid`만 쓴다.

## 4. 파일 목록(이름 고정, snake_case)

| 파일 | 내용 | `expect` |
|---|---|---|
| `soap_v2/finalized_no_metrics.json` | 지표 0개, §6.4.4 확정 최소 요건만(AC-SOAP-06.3) | `metricCount: 0` |
| `soap_v2/draft_rom_mmt_pain.json` | draft. romDeg + joint·motion·activeOrPassive, mmtGrade(`$int`) + muscleGroup, painNrs(`$int`)·painRegions | `metricCount: 2` |
| `soap_v2/pending_member_draft.json` | `memberUid: null`, `memberId` 없음, `pendingMemberId: "fx-pending-001"` | `metricCount: 0` |
| `soap_v2/refs_snapshots_pending_policy.json` | `objective.refs`와 `snapshots`(`changeStatus: "pendingPolicy"`) | `metricCount: 1` |
| `soap_v2/forward_compat_unknown_code.json` | 카탈로그에 없는 `metricCode: "futureMetricX"` 행 1개 + 정상 행 1개(F-SOAP-06.2) | `metricCount: 2, uninterpretable: 1` |
| `soap_legacy/flutter_rom_mmt_test_general.json` | Flutter 편집기 어휘 `rom\|mmt\|test\|general`, value 문자열 `"110-120"`·`"4+"`, status `complete`, completedCategories `subjective` | `legacyMetricCount: 4` |
| `soap_legacy/native_bridge_label_only.json` | `rom·mmt·exercise` label만(dfet:lib/widgets/shells/trainer_shell.dart:483-490), ID `native_fx_20260928`, `memberId: "member-00000000-0000-4000-8000-000000000001"`, `diagnosis` 자동 채움 합성 문자열, `structured.subjective.nativeInkDataBase64`(64바이트 합성), `isSharedWithMember: true` | `legacyMetricCount: 3` |
| `soap_legacy/schema_doc_vocab.json` | 스키마 문서 어휘 `pain\|functional\|specialTest`, status `완료` | `legacyMetricCount: 3` |
| `soap_legacy/trainer_ios_korean_enum.json` | `ROM\|통증\|MMT\|기능검사\|특수검사`, side `좌\|우\|양측\|해당 없음`, unit `도`, workflow `작성 중`, completedCategories `S` | `legacyMetricCount: 5` |
| `soap_legacy/status_shared_korean.json` | status `공유됨`, `isSharedWithMember: true`, type `general`과 빈 값 | `legacyMetricCount: 1` |
| `soap_legacy/drawing_data_bytes.json` | `drawingData`(`$bytes`, 작은 합성값) | `legacyMetricCount: 0` |
| `soap_legacy/expected_v2/<입력과 같은 이름>.json` | MIG-03~06 기대 v2 결과. **DF-031이 만든다**(이 스토리 범위 아님) | — |
| `soap_v2/{flutter,swift}_written_{finalized_no_metrics,draft_rom_mmt_pain,pending_member_draft}.json` | 기록 모드 산출물. `flutter_*`는 DF-007, `swift_*`는 DF-009가 커밋한다 | `writer: dart\|swift`, `roundTrip: identical` |

- 기대 결과 경로는 `contracts/fixtures/soap_legacy/expected_v2/`로 통일한다(`soap_legacy_expected/`, `soap_v2/migrated/`, `*.expected_v2.json` 표기는 쓰지 않는다. V1-11 CF-11-02).
- 네이티브 브리지 줄 번호(`trainer_shell.dart:483-490`)는 PRD 기준선의 것이다. 현재 main에서 같은 코드는 `lib/widgets/shells/trainer_shell.dart`의 `nativeRomEntries`·`nativeMmtEntries`·`nativeExerciseEntries`를 `SoapMetric`으로 바꾸는 부분이다.

## 5. 이 폴더의 작성 관례(검사가 강제한다)

규약 1~4번을 적용하면서 정한 세부 관례다. `fixtures.test.mjs`가 모두 검사한다.

- **서식**: `contracts/*.json`과 같다. UTF-8, LF, 2칸 들여쓰기, 끝에 줄바꿈 하나(`JSON.stringify(doc, null, 2)` + `\n`). Dart·Swift 기록 모드 산출물도 이 서식으로 쓴다.
- **`_fixture`**: 키는 정확히 `id`, `description`, `writer`, `prdRefs`, `expect` 다섯이다. `id`는 `contracts/fixtures/` 기준 상대 경로에서 `.json`을 뺀 값이다. `expect.roundTrip`은 v2 입력과 기록 모드 산출물에만 쓴다.
- **`path`**: `soap_notes/<문서 ID>`. 문서 ID는 `fx-` 접두(규약 3번 예외 `native_fx_<yyyymmdd>`는 `soap_legacy/`에서만).
- **`metricCount`**: `objective`가 없는 문서(대기 회원 생성 페이로드)는 0으로 센다.
- **`legacyMetricCount`**: `data.structured.metrics` 길이다(레거시 원본 metrics의 위치, dfet:docs/firestore_schema.md).
- **태그 객체**: 키가 정확히 하나다. `$ts`는 초 단위까지 쓴 ISO 8601(`Z` 또는 `+09:00` 같은 오프셋), `$serverTimestamp`는 `true`만, `$bytes`는 패딩 있는 표준 base64, `$int`는 정수만. `data` 밖(`_fixture`, `path`)과 `data` 안 모두 이 넷 외의 `$` 키는 없다(두 로더가 실패한다, V1-10 §6.1).
- **레거시 정수 필드도 `$int`**: 레거시 앱은 밀리초 시각(`date`, `createdAt`, `updatedAt`, `workflow.followUpDate`)과 `painNow`·`painWorst`·`score`·`nativeInkStrokeCount`를 Dart `int`·Swift `Int`로 써서 Firestore에 정수로 저장됐다. 그래서 이 값도 `$int`로 적는다. 레거시 `value`는 원본대로 **문자열**이다(`"110-120"`, `"4+"`, Swift가 쓴 `"120.0"`).
- **`null`과 키 없음은 다르다**: 코덱 비교 규칙(V1-10 §6.1)과 같다. 예: `pending_member_draft`는 `memberId`·`isSharedWithMember`·`objective`·`plan` 키가 없고, `subjective.painNrs`는 미입력이라 `null`이다(0과 구분, AC-SOAP-01.7).
- **v2 문서**: `schemaVersion: 2`, `legalNature: "coachingRecord"`, `trainerId == authorUid`, `memberUid`·`pendingMemberId` 중 정확히 하나만 값, `memberId`가 있으면 `memberUid`와 같은 값, `isSharedWithMember`가 있으면 `false`. `diagnosis`, `structured`, `drawingData`, `nativeInkDataBase64` 키는 어디에도 없다. 알려진 metricCode 행은 카탈로그의 `unit`, `allowedSourceGrades`, `sideRule`과 부가 필드(romDeg: `joint`·`motion`·`activeOrPassive`, mmtGrade: `muscleGroup`과 0~5 `$int`)를 지킨다.
- **이름·메모**: 이름 필드(`memberName`, `trainerName`)는 `가상 회원 A`·`가상 트레이너 A` 형식만 쓴다. 자유 문장에 '<두 글자 이상 한글>회원' 꼴은 `가상 회원`·`대기 회원`만 허용한다. 전화번호 형식은 쓰지 않는다. trainer_ios 데모 문장(dfet:trainer_ios/DFETTrainer/Domain/SoapModels.swift:111-119)은 어떤 픽스처에도 넣지 않는다(AC-SOAP-06.3).
- **인라인 필기 바이트**: 실제 PencilKit 데이터가 아니다. `nativeInkDataBase64`는 바이트 0x00~0x3F(64바이트)의 base64 문자열(레거시 원본처럼 태그 없는 **문자열**), `drawingData`는 ASCII `fx-drawing-bytes`(16바이트)의 `$bytes`다.

## 6. 픽스처 추가·변경 절차

1. **정본을 먼저 고친다.** 파일 이름·`expect` 키·태그를 바꾸려면 P0 DF-005 규약(또는 새 스토리 카드)을 먼저 고친다. v2 필드를 바꾸려면 PRD §9.3과 V1-05 §5가 먼저다(§9.3 변경 절차).
2. **손으로 작성한다.** 값은 모두 합성이다(규약 3번). 날짜는 2026-09 이후 가상 세션 날짜를 쓴다.
3. **서식을 맞춘다.** `node -e 'const f=process.argv[1];const fs=require("fs");fs.writeFileSync(f,JSON.stringify(JSON.parse(fs.readFileSync(f,"utf8")),null,2)+"\n")' <파일>`.
4. **검사를 고치고 돌린다.** 새 파일이 규약 4번 표에 있는 이름이면 `fixtures.test.mjs`의 파일 목록(`V2_INPUTS`, `LEGACY_INPUTS`, 허용된 기록 모드·`expected_v2` 이름)을 같은 PR에서 고친다. 표 밖의 새 묶음(`body/`, `summaries/` 등)은 봉투·태그·합성 규칙 검사를 자동으로 받는다.
5. **소비자 테스트를 같은 PR에서 돌린다.** 픽스처가 바뀌면 DF-006 스키마 테스트가 먼저 실패해야 하고, Dart(DF-007)·Swift(DF-009) 교차 왕복 테스트와 이관 dry-run(DF-031)의 기대값도 같은 PR에서 고친다. PR 라벨은 `schema-change`.
6. **기록 모드 산출물**(`soap_v2/{flutter,swift}_written_*.json`)은 코덱 스토리가 기록 모드로 만들고 `writer: dart|swift`, `expect.roundTrip: identical`을 적는다. 손으로 고치지 않는다.

## 검증

```bash
jq empty contracts/fixtures/*/*.json
node --test 'tool/contracts/test/**/*.test.mjs'   # TC-DF005-01~04(fixtures.test.mjs) 포함
```

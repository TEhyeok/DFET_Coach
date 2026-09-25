# contracts/ — 지표·어휘 단일 원본

트레이너 앱(Swift), 회원 앱(Dart), Functions, 관리자 웹이 함께 쓰는 지표 코드와 어휘의 **단일 원본**이다(ADR-005). 네 소비자는 이 JSON을 직접 고치지 않고, `tool/contracts/generate.mjs`(DF-004)가 만든 생성물을 쓴다.

- 형식의 유일한 규범 명세: [V1-05 §13](../docs/v1/05_DATA_MODEL_AND_RULES.md#13-contracts-json-형식)
- 값의 정본: [PRD 부록 A·B](../docs/PRD_V1.md#부록-a-지표-카탈로그). PRD와 다르면 PRD가 우선한다.

## 파일과 PRD 대응

| 파일 | 내용 | PRD 절 | V1-05 절 | 만든 스토리 |
|---|---|---|---|---|
| `metric-catalog.v1.json` | `metrics[]` 22개(부록 A.1 코드, A.2 판정 메타), `excludedMetricCodes` 3개(부록 A.4) | 부록 A.1, A.2, A.4, F-SOAP-06.1 | §13.1, §6.2 | DF-003 |
| `vocab.v1.json` | enum 33개와 `jointMotionPairs` | 부록 A.3, A.5~A.7, 부록 B | §13.2, §6.1, §6.3~§6.5 | DF-003 |
| `feature-flags.v1.json` | 기능 플래그 키 | §6.0.2, 부록 B.7(ADR-010) | §13.3 | DF-027(예정) |
| `audit-actions.v1.json`, `analytics-events.v1.json` | 감사 action, 분석 이벤트 허용 목록 | §5.5, F-PRIV-06.3(ADR-015) | §13.3 | DF-033(예정) |
| `prohibited-terms.v1.json` | 금지어·대체어 | 부록 C | — | DF-010(예정) |
| `fixtures/**`, `vectors/**` | 교차 픽스처, 알고리즘 벡터 | F-SOAP-06, AC-ASM-03.x, T01~T25 | §13.4 | DF-005 외 |

## 공통 규칙(V1-05 §13 요약)

- 키는 영문 camelCase만 쓴다. 한글은 `nameKo`, `labelsKo`의 **값**에만 둔다(부록 A 운영 규칙).
- MDC 수치, 문헌 URL, 정책 값은 넣지 않는다. 판정용 MDC는 승인 정책(`insightPolicyVersions`)에만 있다(ADR-009).
- 최상위 공통 키: `contract`, `version`(파일 이름의 `v1`과 같은 주 버전), `revision`(호환되는 추가·초안 확정마다 1 증가), `source`(PRD 절, ASCII).
- 배열 순서는 PRD 표 순서를 따른다. 생성기는 이 순서를 그대로 옮긴다.
- 서식: UTF-8, LF, 2칸 들여쓰기, 끝에 줄바꿈 하나(`JSON.stringify(doc, null, 2)` + `\n`과 같다).
- vocab의 enum은 모두 `{status, confirmBy?, values, labelsKo?}` 객체다. `status`가 `draft`이면 `confirmBy`(확정 책임 스토리)가 필수다.
- `nameKo`·`labelsKo` 값은 금지어 린트 대상이다(공통 + 트레이너 세트, DF-010). 회원 화면 문장은 이 라벨이 아니라 `docs/v1/data/copy_ko.json`의 회원 문구를 쓴다.

## 변경 절차

1. **부록 A·B를 먼저 고친다.** 새 metricCode나 어휘 값은 PRD 부록에 먼저 올라가 있어야 한다(PRD 수정은 소유자만, 에이전트는 제안만).
2. 같은 PR에서 [V1-05 §13](../docs/v1/05_DATA_MODEL_AND_RULES.md#13-contracts-json-형식) 표와 이 폴더의 JSON을 고친다.
3. `node tool/contracts/generate.mjs`로 생성물을 다시 만들고 **같은 PR에 커밋한다**(DF-004 병합 뒤).
4. `tool/contracts/test/`의 기대값(손으로 옮긴 표)을 같은 PR에서 고치고 테스트를 돌린다.
5. 스키마·규칙에 닿으면 V1-05 §14 체크리스트(같은 PR 동시 갱신)를 따른다. PR 라벨은 `schema-change`.

**생성물은 손으로 고치지 않는다.** `trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/**`, `lib/contracts/generated/**`, `functions/src/shared/generated/**`, `admin_web/lib/generated/**`는 생성기 출력이며, CI `contracts` job의 `generate.mjs --check`가 손으로 고친 흔적을 막는다(DF-004).

## 버전 규칙

| 변경 | 방법 |
|---|---|
| 호환되는 추가(새 enum 값, 새 metricCode, 새 enum) | 같은 파일에서 `revision` + 1 |
| 초안 확정(`draft` → `confirmed`) | `status`를 `confirmed`로 바꾸고 `confirmBy`를 지운 뒤 `revision` + 1 |
| 호환을 깨는 변경(값 이름 변경·삭제, 필드 의미 변경) | **`*.v2.json` 새 파일**을 만든다. `*.v1.json`은 그대로 둔다 |

## 초안 블록

| 블록 | 상태 | 확정 스토리 | 근거 |
|---|---|---|---|
| `joint`, `motion`, `muscleGroup`, `regionCode`, `activeOrPassive` | `draft` | DF-916 | 부록 A.5~A.7 '초안 — P1a 진입 전 확정' |
| `jointMotionPairs.pairs` | `draft`, 빈 배열 | DF-916 | 부록 A.5 '허용 조합은 확정 시 표로 정한다'(ASM-P0-04). 확정 전 코덱은 조합을 검사하지 않는다 |
| `clothing` | `draft` | DF-915 | V1-05 §13.2(ASM-05-04) |

## labelsKo 출처

`labelsKo`는 UI 표시 라벨의 기본값이다. 정본은 부록 B 한글명과 V1-12 문구 덱(`docs/v1/data/copy_ko.json`)이다(V1-05 §13.2).

| enum | 출처 |
|---|---|
| `sourceGrade`, `changeStatus`, `mdcSource` | 부록 B.4 한글명 |
| `unit` | V1-05 §13.2 예시(= 문구 덱 `unit.*`) |
| `reasonCode`, `side`, `syncState`, `consentType`, `soapStatus`, `fasting`, `timeOfDayBand`, `landmarkCode`, `activeOrPassive`, `joint`, `motion`, `muscleGroup`, `regionCode` | 문구 덱 `reason.*`, `side.*`, `sync.*`, `consent.type.*`, `soap.status.*`, `tr11.fasting.*`, `timeOfDay.*`, `landmark.*`, `metric.rom.*`, `joint.*`, `motion.*`, `muscleGroup.*`, `region.*` |
| `reliabilityTier` | `reference`·`beta`는 문구 덱 `reliability.*`. `tier1`은 덱에 없어 '1등급'으로 둠(트레이너 화면은 tier1에 칩을 붙이지 않는다, V1-07) |
| `consentAction`, `consentChannel` | 문구 덱 `tr14.consent.grant`·`tr14.withdraw.title`, `mb06.history.channel.*` |
| `pendingMemberStatus`, `summaryStatus` | 문구 덱 `ad02.status.*`, `tr06.shared`·`tr06.revoked`(날짜 자리표시 제외) |
| `postureStatus`, `measurementStatus` | 문구 덱 `soap.status.*`·`record.voided`. `measurementStatus.active`는 덱에 없어 '유효'로 둠 |
| `postureView` | 문구 덱 `tr07.view.*` |
| `clothing` | V1-07 TR-07 문구 키 `tr07.checklist.clothing.*` |
| `circumferenceProtocolId` | 부록 A.1 둘레 정의의 짧은 이름. 측정 안내 문장은 문구 덱 `tr12.protocol.*` |

덱에 없어서 여기서 정한 라벨(`reliabilityTier.tier1`, `measurementStatus.active`, `circumferenceProtocolId.*`)은 V1-12 문구 덱에 올릴 후보다.

## 검증

```bash
jq empty contracts/*.json
npm ci --prefix tool                             # ajv, ajv-formats
node tool/contracts/generate.mjs --check         # 메타 스키마(schemas/contracts-meta.schema.json) + 교차 검증 + 생성물 드리프트
node --test 'tool/contracts/test/**/*.test.mjs'  # TC-DF003-01~03, TC-DF004-01~04
```

CI `contracts` job이 위 명령을 돈다(DF-004). 생성기 동작·이름 규칙은 [tool/contracts/README.md](../tool/contracts/README.md)에 있다.

# 개발용 에뮬레이터 시드 (`functions/scripts/dev`)

에뮬레이터에 가상 트레이너, 가상 회원, 동의 상태, 기능 플래그, custom claim을 명령 하나로 채운다(DF-042).
로그인(DF-012), 담당 회원 로드(DF-013), 트레이너 앱 `--use-emulator` 수동 확인, 통합 테스트(DF-107)가 이 시드를 쓴다.
시드 경로·ID·프로젝트의 정본은 [V1-10 §5.2·§5.4](../../../docs/v1/10_TEST_PLAN.md)와 ASM-10-24다.

**에뮬레이터 전용이다.** 운영 Firebase 프로젝트에는 쓸 수 없고, 쓰는 방법도 코드에 없다.

## 실행

```bash
# 터미널 1: 에뮬레이터(프로젝트 ID demo-dfet. demo- 접두는 실제 리소스에 닿지 않는다)
firebase emulators:start --only auth,firestore,storage,functions --project demo-dfet

# 터미널 2: 합성 시드
export FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099
node functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json
```

한 번에 돌리려면 `emulators:exec`를 쓴다. 이 명령은 에뮬레이터 환경 변수와 `GCLOUD_PROJECT`를 알아서 넣는다.

```bash
firebase emulators:exec --only auth,firestore,storage,functions --project demo-dfet \
  "node functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json"
```

| 옵션 | 뜻 |
|---|---|
| `--seed <file>` | 필수. 시드 JSON 경로 |
| `--project <id>` | 선택. 없으면 `GCLOUD_PROJECT`(emulators:exec가 넣음), 그것도 없으면 `demo-dfet` |

포트는 `firebase.json`의 `emulators`(Auth 19099, Functions 5001, Firestore 18080, Storage 19199)를 따른다.

## 안전장치(AC-DF-042.2)

- `FIRESTORE_EMULATOR_HOST`나 `FIREBASE_AUTH_EMULATOR_HOST`가 없거나 비어 있으면 **아무것도 읽거나 쓰지 않고 종료 코드 2**로 끝난다. 인자 해석보다 먼저 검사한다.
- 프로젝트 ID는 `demo-*` 또는 CI 에뮬레이터 ID(`dfet-e2e`, `dfet-rules-test`)만 허용한다. 그 밖이면 종료 코드 2다.
- 자격 증명을 읽지 않는다. `GOOGLE_APPLICATION_CREDENTIALS`는 시작할 때 지운다. 가드를 끄는 옵션은 없다.
- 시드 파일의 uid는 `synth`/`SYNTH` 접두, 이메일은 `@example.invalid`(RFC 2606 예약 도메인)만 허용한다. 어긋나면 종료 코드 1이다.
- 로그에는 건수만 찍는다(uid·이름·이메일 없음).

## 비밀번호

모든 시드 계정의 비밀번호는 고정된 합성 값 **`emulator-only-password`**다. 에뮬레이터 Auth 전용이며 비밀이 아니다. 운영 계정이나 다른 곳에 쓰지 않는다.

## 기본 시드 `functions/test/fixtures/emulator-seed.v1.json`

| 대상 | 내용 |
|---|---|
| Auth | `synthTrainerA`·`synthTrainerB`(claim `trainer`), `synthAdmin`(claim `admin`), `synthMember0001`~`synthMember0003`(claim 없음). 이메일 `<uid>@example.invalid` |
| `trainers/synthTrainerA` | `memberIds: [synthMember0001, synthMember0002]` |
| `trainers/synthTrainerB` | `memberIds: []` |
| `users/synthMember0001`~`0003` | 표시명 '가상회원 가/나/다'. 0001·0002는 `trainerId`·`assignedTrainerId = synthTrainerA`, 0003은 담당 없음 |
| `memberConsentStates/synthMember0001` | ① `required` ② `healthData` ③ `bodyImaging` 모두 granted, 문서 버전 `{type}--1.0` |
| `appConfig/features` | 8키. `soapV2`·`bodyComposition` true, `gut`·`blood`·`insights`·`bodyAssessment`·`memberShare`·`lidarBeta` false(V1-10 §5.4) |

플래그가 false면 규칙이 create를 거부한다. 개발 중 '동기화 실패'가 보이면 먼저 `appConfig/features` 값을 확인한다.

P1a 추가분(published 동의 문서 5종, 대기 회원 `SYNTHpending00000001`)과 오류 주입 변형(`emulator-seed.no-consent.v1.json`, `emulator-seed.consent-fail.v1.json`)은 DF-107이 같은 형식으로 더한다.

## 시드 파일 형식

```json
{
  "_seed": {"id": "emulator-seed.v1", "description": "…", "writer": "synthetic", "projectId": "demo-dfet", "refs": []},
  "auth": [{"uid": "synthTrainerA", "email": "synthTrainerA@example.invalid", "displayName": "…", "claims": {"trainer": true}}],
  "firestore": [{"path": "trainers/synthTrainerA", "data": {"memberIds": [], "createdAt": {"$serverTimestamp": true}}}]
}
```

- 최상위 키는 `_seed`, `auth`, `firestore` 셋뿐이다.
- `data` 안의 타입 태그는 P0 픽스처 규약과 같다: `{"$ts": "<ISO 8601>"}` → Timestamp, `{"$serverTimestamp": true}` → 서버 시각. 기본 시드의 시각은 실행 시각 기준이다(V1-10 §5.2).

## 멱등(AC-DF-042.4)

두 번 실행해도 결과가 같다. Auth 계정은 있으면 시드 값으로 갱신하고 claim은 병합하지 않고 통째로 바꾼다. Firestore 문서는 `set()`(merge 없음)으로 덮어쓴다. 시드에 없는 문서·계정은 건드리지 않는다. 서버 시각 필드만 실행 시각으로 새로 찍힌다.

## 테스트

| ID | 파일 | 실행 |
|---|---|---|
| TC-DF042-02 | `functions/test/unit/dev/seed-emulator.test.js` | `npm --prefix functions test` |
| TC-DF042-01 | `functions/test/e2e/seed-emulator.test.js` | `firebase emulators:exec --only auth,functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"` |

<!--
GH-08 PR 템플릿. 규칙의 정본: docs/v1/01_AGILE_WORKING_AGREEMENT.md ('완료 정의(DoD)', '브랜치·커밋·PR 규칙')
- PR 하나 = 스토리 하나. 생성물을 뺀 변경 400줄 이하 권장.
- 제목: <type>(<scope>): <요약> (DF-NNN)   예) feat(contracts): add metric catalog v1 (DF-003)
- 에이전트는 로컬 검증 전이면 draft, 지시서 검증 명령을 모두 통과하면 Ready로 연다. 구현 에이전트는 자기 PR을 병합하지 않는다.
- 병합은 rebase 병합이다(DEC-20). 스프린트 PR은 CI 필수 체크 초록 + 다른 세션의 적대적 리뷰 승인 시 병합 담당 AI가, PRD·D1~D4 영향·소유자 보류 PR은 소유자가 병합한다(V1-01 '에이전트 권한 경계' 병합 행).
- 커밋이 그대로 main에 남으므로 커밋마다 Refs:·Trace: footer를 붙이고 fixup·wip 커밋은 병합 전에 정리한다.
- 실데이터·비밀·output/·tmp/ 내용·공개 URL·배포 명령 결과를 넣지 않는다.
-->

Closes #<이슈 번호>

## 요약

- 스토리: DF-NNN <제목> (에픽 EP-NN, 단계 <P0|P1a|P1b|P2|P3>)
- 무엇을 바꿨나(1~3줄):
- 작성: <claude | codex | human> / 브랜치: `<type|claude|codex>/DF-NNN-<slug>`

## 추적

```
Refs: DF-NNN
Trace: <PRD ID 목록, 예: F-SOAP-01.1, AC-SOAP-01.3, NFR-15, TR-04>
```

## 수용 기준별 증빙

| ID | 기준(요지) | 증빙 종류 | 증빙(테스트 이름·CI 링크·스크린샷·기록) | 결과 |
|---|---|---|---|---|
| AC-... | | 단위 / 규칙 에뮬레이터 / e2e / 교차 픽스처 / UI / 스냅샷 / 실기기 / 수동 | | 통과 |
| AC-DF-NNN.1 | | | | |

## 테스트 결과

**이 PR 생성 시점에 활성인 필수 체크**(V1-01 '필수 체크 활성화 표' 기준, 아직 없는 체크는 지운다):
`flutter` · `functions-and-rules` · `admin-web` · `ios-no-codesign` · `contracts` · `trainer-app` · `docs-and-backlog` · `copy-lint`(보고 | 차단) · `static-guards` · `migrations` · `trainer-app-emulator-it`

- copy-lint가 보고 모드이면 위반 요약: 없음 | <n건, 파일:줄>

실행한 명령과 결과를 붙인다(해당 없는 줄은 지운다).

```
xcodegen generate --spec trainer_app/project.yml && git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj   → 
swift test --package-path trainer_app/Packages/TrainerCore                                                       → 
xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -destination '<iPad 시뮬레이터>'  → 
flutter analyze && flutter test                                                                                  → 
npm --prefix functions run lint && npm --prefix functions test                                                   → 
firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules" → 
firebase emulators:exec --only functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e" → 
npm --prefix admin_web run lint && npm --prefix admin_web run typecheck && npm --prefix admin_web test && npm --prefix admin_web run build → 
node tool/contracts/generate.mjs --check                                                                         → 
node tool/lint/prohibited-terms.mjs                                                                              → 
bash tool/lint/static-guards.sh                                                                                  → 
node tool/lint/doc-headers.mjs && node tool/backlog/validate_backlog.mjs                                         → 
```

## 기능 플래그

- [ ] 플래그 무관
- [ ] 플래그 뒤에 있음: `<soapV2 | bodyComposition | bodyAssessment | memberShare | lidarBeta>` — false일 때 진입점 0(AC-IA-02), 규칙 featureOn 조건 확인
- [ ] 새 플래그 키 추가 없음(키는 contracts/feature-flags.v1.json에서만 추가)

## 스키마·규칙·계약 영향(같은 PR 동시 갱신)

- [ ] 영향 없음
- [ ] Firestore 필드·컬렉션 변경 → `docs/firestore_schema.md`, `docs/v1/05_DATA_MODEL_AND_RULES.md`, Swift·Dart 매핑, `contracts/fixtures/**`, 규칙 테스트를 이 PR에서 함께 고쳤다 (schema-change)
- [ ] `firestore.rules` / `storage.rules` 변경 → R-NN / S-NN 테스트 추가·갱신, 허용·거부 쌍, 새 쿼리의 규칙 증명과 인덱스 (rules-change)
- [ ] 어휘·이벤트·금지어 변경 → `contracts/*.json`과 생성물(`generate.mjs --check`)을 함께 커밋했다
- [ ] callable·트리거·쿼리 변경 → `docs/v1/06_API_SPEC.md` 갱신
- [ ] 화면·상태 변경 → `docs/v1/07_TRAINER_APP_SPEC.md` 또는 `08_MEMBER_APP_AND_ADMIN_SPEC.md` 갱신

## 규제 문구·개인정보

- [ ] 사용자 노출 문자열은 카탈로그(Localizable.xcstrings / Flutter 문자열 위치)에 있고 금지어 린트를 통과했다(PRD 부록 C). 회원 노출 문자열은 회원 규칙 세트와 부록 B.8 문장만 사용
- [ ] 진단·질환명·KCD 입력 경로나 표시가 없다(PRD §3.4)
- [ ] 로그·분석 이벤트·감사 metadata에 건강 수치, 판정 결과, 동의 유형, 이름·이메일, 자유 메모, 경로, uid 원문, 초대 코드 원문이 없다(NFR-10). 새 이벤트는 analytics-events 허용 목록에 먼저 등록
- [ ] 저장이 있는 기능은 syncState를 §6.0.3 문구대로만 표시하고, 오류 주입 시 '동기화됨'이 거짓으로 뜨지 않는다(C-05, NFR-06)
- [ ] 쿼리·권한 오류를 빈 목록으로 삼키지 않는다('불러오기 실패'와 재시도)
- [ ] getDownloadURL, 문서 안 바이너리(base64·Bytes), 공개 링크를 새로 쓰지 않았다(PRD §9.5)
- [ ] 합성 데이터만 사용했다. 실데이터·비밀·`output/`·`tmp/` 내용을 열거나 커밋하지 않았다
- [ ] 개인정보 영향 있음(privacy-impact): <동의·삭제 범위표 §9.7·감사 이벤트 반영 내용>

## 동결 예외

- [ ] 해당 없음
- [ ] `freeze-exception`: Runner 내장 트레이너 또는 `trainer_ios/` 수정. 허용 사유: 규제 수정(PRD §3.4-3·4·8, MIG-04) | 크래시 수정. 대상 줄: `dfet:ios/Runner/AppDelegate.swift:<줄>`. 최소 diff 확인

## 영역별 DoD

해당 영역만 체크한다(V1-01 '영역별 DoD').

- [ ] 트레이너 iOS: Firebase import는 FirebaseData·App 타깃만, Data·Sync에 print·강제 언래핑 없음, `/// TR-NN` 주석, 접근성 식별자 `trNN.<element>`, 상태 매트릭스 스냅샷, (레이아웃) 1/3 Split View 스크린샷, (needs-device-test) V1-T09 기록 첨부
- [ ] Flutter 회원 앱: 골든 diff 확인, iOS 15.5 빌드, 원 기록 컬렉션 직접 조회 없음, 4탭 유지, textScaler 200%
- [ ] Functions: asia-northeast3·v2 onCall, 기존 callable 이름·리전 불변, 표준 오류 코드·`{ok:true}`, 트랜잭션+감사 기록, 멱등 테스트, 새 의존성 없음
- [ ] 규칙·Storage: R-/S- ID가 테스트 제목에 있음, 100% 통과, 운영 배포는 하지 않음(DF-931)
- [ ] admin_web: 생성된 contracts로 zod, recordHealthRead 호출, admin claim 판정
- [ ] 계약: 합성 픽스처, 파괴적 변경은 `.v2` 새 파일, 부록 A 선행
- [ ] 이관 스크립트: 기본 dry-run, 수량만 보고, 멱등·롤백 리허설, V1-T10 양식
- [ ] 문서: 헤더 표준, 코드 근거 직접 확인, PRD 미수정

## 가정·제안

- AS-DEV 후보(관련 PRD Q-/AS-): 없음 | <내용>
- PRD 수정 제안: 없음 | <내용>
- 남은 위험·후속(부채 후보): 없음 | <내용>

## 스크린샷(UI 변경 시, 가상 회원만)

<!-- 실제 회원 정보가 보이는 화면을 올리지 않는다 -->

## 병합 전 확인(병합 담당: DEC-20 병합 담당 AI 또는 소유자)

- [ ] 위 '활성인 필수 체크'가 V1-01 활성화 표와 맞고 모두 초록이다(아직 만들어지지 않은 체크는 요구하지 않음. 이 PR이 새 체크를 만든다면 그 체크도 초록)
- [ ] 수용 기준마다 증빙이 있다(D1)
- [ ] 위험 라벨별 검토를 했다(rules-change·schema-change·privacy-impact·regulatory는 diff 정독. AI 병합이면 적대적 리뷰가 V1-01 '소유자 검토 체크' 표의 확인을 대신 수행하고 결과에 적는다)
- [ ] 수정 경로가 작업 지시서의 허용 경로 안이다(에이전트 PR)
- [ ] 적대적 리뷰 승인(구현 에이전트와 다른 세션). PRD·D1~D4 영향 또는 소유자 보류 PR이면 **소유자 검토 완료**
- [ ] PR 제목 `<type>(<scope>): <요약> (DF-NNN)`, 모든 커밋에 `Refs:`·`Trace:` footer, rebase 병합(스쿼시·머지 커밋 금지)
- [ ] 병합 뒤: 병합 근거(체크·리뷰 링크) 코멘트, 이슈 Done, Projects 필드 갱신

# 문구·분석 이벤트·린트 명세

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-12 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §3.1, §3.2, §3.4, §3.6, §3.8, §5.3, §5.4, §5.5, §6.0.3, §6.5.0, §7.1, §7.2, §7.6, §7.7, §8.1~§8.6, §9.7(auditLogs), §10.5, NFR-06, NFR-10, NFR-11, 부록 A, 부록 B.4·B.8, 부록 C.1~C.3 |
| 관련 에픽·스토리 | EP-06, EP-02, EP-05, EP-08, EP-10, EP-12, EP-14, EP-17, EP-18, EP-00 / DF-010, DF-033, DF-040, DF-041, DF-028, DF-029, DF-016, DF-017, DF-110, DF-120, DF-122, DF-126, DF-137, DF-204, DF-208, DF-209, DF-224, DF-306, DF-309, DF-311, DF-315, DF-316, DF-327, DF-921 |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [범위와 정본 관계](#1-범위와-정본-관계)
2. [문구 원칙(보이스·표기)](#2-문구-원칙보이스표기)
3. [상태·출처·변화 표시 어휘](#3-상태출처변화-표시-어휘)
4. [문구 키 체계](#4-문구-키-체계)
5. [분석 이벤트 카탈로그](#5-분석-이벤트-카탈로그)
6. [성공·가드레일 지표 계산 매핑](#6-성공가드레일-지표-계산-매핑)
7. [금지어 린트 설계](#7-금지어-린트-설계)
8. [G-10 표시·광고 수동 검수 체크리스트](#8-g-10-표시광고-수동-검수-체크리스트)
9. [스토리 대응과 구현 순서](#9-스토리-대응과-구현-순서)
10. [가정·충돌·열린 질문](#10-가정충돌열린-질문)
11. [변경 이력](#11-변경-이력)

---

## 1 범위와 정본 관계

### 1.1 이 문서가 정하는 것

| 영역 | 이 문서가 정본인 것 | 정본이 아닌 것(참조) |
|---|---|---|
| 문구 | 문구 키 이름, 한국어 확정 문장, 대상(audience), 적용 화면, 플레이스홀더 | 문구의 **의미**와 금지 경계는 PRD §3·§6.0.3·§7.7·부록 B.8·C. 화면 배치는 [V1-07](07_TRAINER_APP_SPEC.md)·[V1-08](08_MEMBER_APP_AND_ADMIN_SPEC.md) |
| 분석 | 이벤트 이름, 보내는 시점, 속성·타입·허용 값, 구간(band) 경계, 금지 속성 | 이벤트 원칙은 PRD §5.5·NFR-10·[ADR-015](adr/ADR-015-analytics-privacy.md). API 경계(서버 응답 뒤 전송)는 [V1-06 §11.1](06_API_SPEC.md) |
| 지표 | M-01~M-11, M-G1~M-G5의 계산식과 데이터 출처 | 지표 정의·목표값은 PRD §5.3·§5.4. 서버 집계 문서 형태는 [V1-06 §6.10](06_API_SPEC.md) |
| 린트 | 규칙 세트 데이터 형식, 경로·대상 매핑, 예외(허용) 목록, CI 배치, 모드 전환, 테스트 벡터 | 금지어 목록의 **내용**은 PRD 부록 C. 설계 결정은 [ADR-016](adr/ADR-016-regulatory-copy-lint.md) |

PRD와 이 문서가 어긋나면 PRD가 우선한다. 이 문서의 다른 개발 문서 카드(backlog)에 적힌 '문구 키(제안)'는 여기서 확정본으로 대체된다. 카드 제안과 다르게 확정한 키는 [10.2](#102-다른-문서스파인과의-충돌)에 적었다.

### 1.2 기계 판독 파일 3종

| 파일 | 문서 ID | 내용 | 코드 정본으로의 이동 | 이동 스토리 |
|---|---|---|---|---|
| [data/forbidden_terms.json](data/forbidden_terms.json) | V1-12-D1 | 부록 C 규칙 세트, 정규화, 인과 패턴, 약어, 식별자 규칙, 경로 매핑, 예외 목록, 테스트 벡터 25개 | 같은 구조로 `contracts/prohibited-terms.v1.json`에 복사한다. `testVectors`는 `contracts/vectors/prohibited-terms.v1.json`으로 분리한다 | DF-010 |
| [data/analytics_events.json](data/analytics_events.json) | V1-12-D2 | 이벤트 16종, 속성 스키마, 구간 정의, 금지 속성, SDK 설정 | `contracts/analytics-events.v1.json`에 복사한다(`events`, `bands`, `forbiddenPropertyKeys`, `forbiddenKeyPatterns`). 설명 필드(`desc`, `trigger`)는 그대로 둔다 | DF-033 |
| [data/copy_ko.json](data/copy_ko.json) | V1-12-D3 | 문구 키 789개(트레이너 505, 공유 93, 회원 104, 관리자 57, 동의 초안 26, 알림 3, 스토어 1) | 코드로 복사하지 않는다. 각 플랫폼 카탈로그(§4.4)로 **옮겨 적는다**. 이 파일은 docs에 남는 문구 정본이며 copy-lint가 대상별 규칙으로 검사한다 | DF-017(트레이너 카탈로그 생성), 각 화면 스토리 |

- **ASM-12-01** docs/v1/data의 JSON 두 개(D1, D2)는 설계 시드다. DF-010·DF-033 병합 뒤에는 `contracts/*.json`이 코드 정본이 된다. 이후 변경은 contracts를 고치고, 같은 PR에서 이 문서의 해당 표와 data 파일을 함께 고친다. 둘이 다르면 contracts가 이긴다. D3(copy_ko.json)는 계속 문구 정본이다.
- 세 파일은 이 저장소 초안을 만든 생성기에서 함께 만들어졌고, 생성 시점에 **덱 전체 789개 문자열이 D1 규칙으로 위반 0건**, **D1 테스트 벡터 25개가 모두 기대값과 일치**함을 확인했다. DF-010의 Node 구현도 같은 결과를 내야 한다(TC-12-LN-01).

### 1.3 역할별 읽는 법

| 작업 | 먼저 읽을 절 | 함께 볼 파일 |
|---|---|---|
| 트레이너 화면 스토리(TR-01~TR-15) | §2.2, §3, §4.1~§4.6, §4.9의 해당 화면 표 | copy_ko.json(`tr*`, `sync.*`, `sourceGrade.*`, `change.*`, `reason.*`) |
| 회원 앱 스토리(MB-01~MB-06) | §2.3, §3.3~§3.5, §4.2, §4.4 | copy_ko.json(`mb*`, `common.*`, `consent.*`) |
| 관리자 화면(AD-01~AD-07) | §2.4, §4.9 관리자 표 | copy_ko.json(`ad*`, `audit.*`, `flag.*`) |
| 분석 전송기·이벤트(DF-126, DF-204 등) | §5 전체, §6 | analytics_events.json |
| 금지어 린트(DF-010, DF-040, DF-041) | §7 전체 | forbidden_terms.json |
| 서버 요약 검사(DF-309) | §7.3, §7.5, §7.10 | forbidden_terms.json |
| 단계 종료 검토(DF-926~DF-938) | §6 | V1-T06 |

---

## 2 문구 원칙(보이스·표기)

### 2.1 모든 표면 공통

| # | 원칙 | 근거 | 확인 방법 |
|---|---|---|---|
| W1 | 사용목적은 **운동 지도와 일상 건강관리 기록**이다. 진단·치료·경감·예방·재활을 암시하는 동사·명사를 쓰지 않는다. 부정문 고지('진단이나 치료를 위한 정보가 아닙니다')는 §3.1 원문만 허용한다 | §3.1, §3.4, 부록 C.1 | copy-lint 공통 세트 + allowEntries AE-01·AE-02 |
| W2 | 수치는 값·단위·출처·측정 시각을 함께 보인다. 출처 없는 수치 문장은 만들지 않는다 | C-01, F-VIZ-07.1 | 컴포넌트 규칙(SourceGradeChip, `source_grade_chip.dart`) |
| W3 | 저장 상태는 §6.0.3 다섯 문구만 쓴다. '저장됨' 단독 문구, '완료!' 같은 감탄형 성공 메시지는 없다 | §6.0.3, NFR-06 | 정적 가드(DF-011)에 `"저장됨"` 리터럴 0건 규칙 추가 제안(ASM-12-19) |
| W4 | 판정이 없으면 '산정 준비 중'(트레이너) / 하단 한 줄(회원)이다. '변화 없음'은 쓰지 않고 '유지(오차 범위 내)'를 쓴다 | §7.6, §7.7 | 문구 키 고정(`change.*`, `mb.change.*`) |
| W5 | 누락은 '미측정'·'미입력'·'비교할 측정이 없습니다'로 드러낸다. 추정·보간 문장('비슷했을 거예요')을 쓰지 않는다 | C-04, 부록 C.2 | 인과 패턴 C2-04(경고) |
| W6 | 인과를 단정하지 않는다. '함께 관찰됐어요', '연관 가능성이 있어요'만 쓴다 | §7.7, 부록 C.2 | 인과 패턴 C2-01~C2-03(경고), G-10 |
| W7 | 진단성 라벨(거북목, 측만, 골반 틀어짐·불균형) 대신 관찰 문구를 쓴다('머리 전방 자세 관찰', '골반 좌우 높이 차이 관찰') | F-ASM-03.7, §7.7 | C1-11, C1-11b |
| W8 | 점수·등급·정상/비정상 표현을 만들지 않는다(규준 없음) | §7.7, F-VIZ-01.6 | C1-19, C1-22 |
| W9 | 오류 문장은 '무엇이 안 됐는지 + 무엇을 하면 되는지' 순서로 한 문장이나 두 문장이다. 서버 원문·코드·스택을 보이지 않는다 | V1-06 §3.5 | messageKey → 문구 키 매핑(§4.6) |
| W10 | 느낌표·이모지·과장 부사('완벽하게', '확실히')를 쓰지 않는다 | §3.1(사용목적은 표시·광고로 판단) | 리뷰 체크리스트(GH-08) |

### 2.2 트레이너 앱 보이스

- **어조.** 라벨은 명사형으로 짧게 쓴다('기록 완료', '동기화 실패'). 안내·오류 문장은 해요체를 쓰되 동작 지시는 '-하세요/-해 주세요'로 쓴다. 동의 화면처럼 회원이 직접 읽는 화면(TR-14 동의 카드)은 회원 보이스(§2.3)를 따르고 대상은 `shared`다.
- **허용 약어**(부록 B.8, F-SOAP-07.3): SOAP, S/O/A/P, ROM, AROM, PROM, MMT, NRS, MDC. 화면 라벨에는 CVA, BMI, C7, ASIS, LiDAR도 쓴다(해부·기기 명칭). 원 기록 텍스트에서 목록 밖 약어는 **경고**만 한다(§7.5).
- **트레이너 용어**: '의미 있는 개선/악화', '판정 불가 · {사유}', 'MDC 미확보', '산정 준비 중', '스크리닝', '관측 단면 · 실측 대조 전 · 베타/참고'. 회원 화면에는 쓰지 않는다.
- **S 라벨**은 '오늘 불편·요청'이다. '주호소'를 쓰지 않는다(§3.4-6). A는 '운동 관점 평가'다(§3.4-1).
- **Live(TR-04) 문구 최소화**: 모달 문구 없음(M1). 예외는 저장 실패·동의 부재 안내 두 가지뿐이다.
- **위험도 라벨 금지**: '고위험' 같은 라벨을 두지 않는다(F-SOAP-01.11).

### 2.3 회원 앱 보이스

- **어조.** 해요체(-어요/-예요), 쉬운 한국어, 주어는 '트레이너'나 생략. 회원을 '회원님'으로 부르는 것은 TR-14 동의 카드 안내 한 곳뿐이다.
- **변화 문장은 부록 B.8 세트만** 쓴다(`mb.change.*`). '개선·악화·판정·의미 있는'은 회원 규칙 세트에서 차단한다(부록 C.3, F-VIZ-06.9).
- **약어는 풀어 쓴다.** 허용 약어는 BMI(표기 '체질량지수(BMI)')와 서비스명 D-FET뿐이다(ASM-12-12). SOAP는 '트레이너 기록'·'세션 기록 요약', NRS는 '통증 점수(0–10)', MDC는 '측정 오차 범위', CVA는 '머리·목 정렬 각도'다.
- **회원에게 보이지 않는 것**: photoAuto·observedSection·modelEstimate·aiAppearance 값, 통증 점수(요약 기본 제외), 판정 불가 사유 중 noMdc·referenceMetric·betaMetric(배지 없음), 결과지 사진, 트레이너 A 원문(F-SOAP-05.5, F-VIZ-06.4).
- **동의·권리 화면**은 결과를 먼저 말한다('철회하면 ~돼요'). 법률 검토(G-04)로 바뀔 문장은 `legalReview` 표시가 있는 초안이다(§4.8).
- **'추후 추가 예정'을 쓰지 않는다.** 꺼진 기능은 진입점을 숨긴다(§8.4). 서버가 `flag.disabled`를 돌려주면 '지금은 사용할 수 없는 기능이에요.'를 보인다(ASM-12-09).

### 2.4 관리자 웹 보이스

- 합쇼체 짧은 문장('게시할 수 없습니다'). 기존 admin_web 문구 톤(예: dfet:admin_web/app/(console)/settings/reference-ranges/page.tsx:13의 '관리합니다')을 따른다.
- 공통 금지어 세트만 적용한다. 운영자는 트레이너 용어('판정', 'MDC')를 그대로 쓴다(AD-04). 회원 이름·건강 수치를 감사 로그 화면 문구에 넣지 않는다(§9.7).

### 2.5 알림

- 회원 보이스 + 회원 규칙 세트. 건강 수치, 지표명, 통증 부위, 트레이너 이름을 넣지 않는다(F-SOAP-05.12).
- v1 알림 문장은 `notify.summaryShared`('트레이너가 새 기록을 공유했어요'), `notify.consentReconfirm`, `notify.consentRevised` 세 개뿐이다. 발송 주체와 템플릿 위치는 알림 도입 때 정한다(Q-DEV-12-06).

### 2.6 표기 규칙

| 항목 | 규칙 | 예 |
|---|---|---|
| 값과 단위 | 붙여 쓴다. 단위는 `unit.*` 키 | `2.9°`, `72.4kg`, `23.1%`, `81.0cm`, `23.1kg/m²` |
| 정밀도 | 각도·kg·%·cm 소수 첫째 자리, NRS·MMT 정수(§7.5 Δ 규칙과 같음) | `45.0°`(0 생략 금지) |
| 음수 | ASCII 하이픈 대신 U+2212 '−'를 쓴다(VoiceOver가 '마이너스'로 읽음) | `−3.2°` |
| 범위 | 물결표 `~`, 척도 표기는 PRD처럼 en dash `–` | `0.1~600kg`, `0–10`, `0–5` |
| 구분자 | 공백 + 가운뎃점 + 공백 `' · '` | `판정 불가 · 기기 변경` |
| 날짜(트레이너) | `yyyy.MM.dd`, 시각 포함 시 `yyyy.MM.dd HH:mm`(24시간, 기기 시간대) | `2026.11.02 14:05` |
| 날짜(회원) | `M월 d일`, 연도가 다르면 `yyyy년 M월 d일` | `11월 2일` |
| 개수 | 숫자 + 단위 명사, 복수형 없음 | `동기화 대기 3건`, `이전 버전 2개` |
| 측면 | 해부학적 좌우(대상자 기준) 한국어 `왼쪽/오른쪽/양측`. 차트 끝 라벨만 `L`·`R` | F-ASM-02.7, F-VIZ-03.8 |
| 동의 번호 | 원문자 ①~⑤ | `동의 ②③ 필요` |
| 문장 끝 | 라벨·버튼은 마침표 없음. 두 문장 이상이거나 오류 안내는 마침표 | — |

### 2.7 사용목적 문구와 적용 위치(§3.1)

| 용도 | 키 | 적용 위치 | 스토리 |
|---|---|---|---|
| 기본(설명서·앱스토어) | `store.purpose` | App Store Connect 설명(트레이너 앱, 회원 앱 개정 시), 설명서, 웹 소개, 영업 자료 첫 문단 | DF-922, DF-921(G-10) |
| 앱 UI 짧은 고지 | `common.disclaimer.short` | TR-15 설정 하단, TR-06 미리보기 하단(트레이너 시점), MB-01·MB-04 하단은 회원 문구와 함께 | DF-018, DF-311, DF-316 |
| 회원 리포트·요약 하단 | `common.disclaimer.member` | MB-01, MB-02, MB-04 하단, TR-06 회원 미리보기 하단 | DF-315, DF-316 |

- 문구를 바꾸면 부록 C 검사와 G-10을 거친다(§3.1). 두 고지는 부정문이라 금지어가 들어 있으므로 **정확 일치**로만 허용한다(AE-01, AE-02). 한 글자라도 다르면 위반이다(PT-V16).

### 2.8 피해야 할 흐름과 문구(§3.2)

| 흐름(§3.2 금지) | 문구에 나타나는 신호 | 이 문서의 대응 |
|---|---|---|
| 질환 입력 → 평가 → 자동 처방·난이도 조정 | '처방', '재활', 질환명 입력란 라벨 | C1-06~C1-08, C1-11, 입력 라벨 금지(scopes `input`) |
| 진료용 전송 | '진료', '진료용', '의료기관에 전송' | C1-10 |
| 체형 점수·등급 | '체형 점수', '근골격 기능 등급' | C1-18, C1-19 |
| 확인 없는 자동 판정 노출 | '자동으로 판정했어요' | 회원 세트 '판정' 차단, 공유는 TR-06 명시 버튼만 |
| 환자군 표적 광고 | '○○ 환자용', '디스크·측만 대상' | C1-09, C1-11, G-10 |

---

## 3 상태·출처·변화 표시 어휘

이 절은 화면마다 반복되는 상태 문구의 **유일한 매핑표**다. 컴포넌트(트레이너 `DesignSystem`, 회원 `lib/widgets/clinical/`)는 enum 값에서 이 키를 고르는 함수 하나만 두고, 화면 코드에 문자열을 직접 쓰지 않는다.

### 3.1 저장 상태(syncState, §6.0.3)

| syncState | 키 | 문구 | 표시 조건 | 함께 보이는 것 |
|---|---|---|---|---|
| `localSaved` | `sync.localSaved` | 기기에 저장됨 | SwiftData 저장 성공 뒤 | 대기 건수가 있으면 `sync.localSavedWithPending` '기기에 저장됨 · 동기화 대기 {count}건' |
| `syncing` | `sync.syncing` | 동기화 중 | Outbox 처리 중 | — |
| `synced` | `sync.synced` | 동기화됨 | `hasPendingWrites == false` + 업로드 크기·SHA-256 대조 성공 | — |
| `syncFailed` | `sync.syncFailed` | 동기화 실패 | 규칙 거부·재시도 한도 초과 | 사유 `sync.reason.*` 한 줄 + `common.retry` + `sync.localKept` |
| `awaitingConsent` | `sync.awaitingConsent` | 동의 확인 대기 | 현장 동의가 서버에서 확인되기 전 | 사진 촬영 진입에는 `consent.awaiting.photoDisabled` |

- 사유 선택: 규칙 거부(permission-denied·failed-precondition) → `sync.reason.ruleDenied`, 네트워크(unavailable·deadline-exceeded, 오프라인) → `sync.reason.network`(이 경우는 syncFailed가 아니라 대기이므로 배지는 `sync.syncing`이나 `localSaved`), 업로드 대조 실패 → `sync.reason.uploadMismatch`, internal 5회 연속 → `sync.reason.retryLimit`. 서버 `details.messageKey`가 있으면 그 문장을 두 번째 줄에 보인다(§4.6).
- 노트 상태 라벨은 syncState와 **나란히** 보인다: `soap.status.draft` '작성 중', `soap.status.finalized` '확정됨', `soap.status.pendingFinalize` '확정 대기'. 체형평가 오프라인 확정은 `posture.status.pendingConfirmSync` '확정 대기 · 동기화 중'(AC-ASM-04.5).
- 회원 앱에는 syncState가 없다. 오프라인이면 `common.offlineStale`만 보인다(§8.4).

### 3.2 표시 상태(§6.0.3)

| 상태 | 트레이너 키 | 회원 키 | 비고 |
|---|---|---|---|
| 미구현 | `common.comingSoon` '추후 추가 예정' | (진입점 숨김) | v2 기능에는 쓰지 않음(§8.4) |
| 정책 미승인 | `change.pendingPolicy` '산정 준비 중' | `mb.change.pendingPolicyFooter` '변화 비교 기준을 준비하고 있어요'(하단 한 줄) | 수치는 보인다(AC-C-03.1) |
| 베타 | `sourceGrade.observedSection` '관측 단면 · 실측 대조 전 · 베타/참고' | (노출 안 함) | 모든 값 옆에 필수, '측정값' 금지(C1-23) |
| 스크리닝 | `sourceGrade.photoAuto.chip` '스크리닝' + 점선 테두리 | (노출 안 함) | 판정 제외 |
| 참고 | `reliability.reference` '참고' | `mb.reliability.reference` '참고용' | 배지 없음 |
| 판정 불가 | `change.indeterminate.withReason` '판정 불가 · {reason}' | 조건 사유만 `mb.change.indeterminate` | 사유 없는 표시는 테스트 실패(AC-VIZ-07.4) |
| 미측정 | `common.unmeasured` '미측정' | `common.unmeasured` | 0으로 표시 금지 |
| 확정 전(체형 draft) | `change.draft` '확정 전' | — | F-VIZ-01.3 |
| 참고 지표 | `change.referenceNoJudgement` '참고 지표 · 판정하지 않음' | — | F-VIZ-01.3 |

### 3.3 출처 등급(sourceGrade, §7.1)

| sourceGrade | 트레이너 키 · 문구 | 회원 키 · 문구 | 회원 노출 |
|---|---|---|---|
| `tape` | `sourceGrade.tape` 줄자 실측 | `mb.sourceGrade.tape` 줄자로 잰 값 | 예 |
| `device` | `sourceGrade.device` 기기 측정 · {deviceModel} | `mb.sourceGrade.device` 체성분계 측정 | 예 |
| `photoManual` | `sourceGrade.photoManual` 사진 측정(확정) | `mb.sourceGrade.photoManual` 사진으로 확인한 값 | 예 |
| `photoAuto` | `sourceGrade.photoAuto` 사진 자동 추정 · 스크리닝 | — | 아니요 |
| `observedSection` | `sourceGrade.observedSection` 관측 단면 · 실측 대조 전 · 베타/참고 | — | 아니요 |
| `modelEstimate` | `sourceGrade.modelEstimate` 모델 추정(표시 안 함) | — | 아니요 |
| `aiAppearance` | `sourceGrade.aiAppearance` AI 외형 · 실측 아님(표시 안 함) | — | 아니요 |
| `selfReport` | `sourceGrade.selfReport` 본인 보고 | `mb.sourceGrade.selfReport` 직접 알려 준 값 | 요약 기본 제외 |
| `trainerObserved` | `sourceGrade.trainerObserved` 트레이너 관찰 | `mb.sourceGrade.trainerObserved` 트레이너 확인 | 예(MB-04 O) |
| `derived` | `sourceGrade.derived` 계산값 | `mb.sourceGrade.derived` 계산한 값 | 예 |

- 모르는 sourceGrade 값을 받으면 **렌더하지 않는다**(AC-C-01.1). '해석 불가'로 표시하는 것은 SOAP 레거시 지표(F-SOAP-06.2) 한 경우뿐이다.

### 3.4 변화 상태(changeStatus)

| changeStatus | 글리프(§6.5.0) | 트레이너 키 · 문구 | 회원 키 · 문구(B.8) | 회원 표시 조건(§7.6) |
|---|---|---|---|---|
| `meaningfulImprovement` | 목표 방향 화살표 | `change.meaningfulImprovement` 의미 있는 개선 | `mb.change.meaningfulImprovement` 측정 오차보다 큰 변화가 정한 목표 방향으로 나타났어요 | `mdcSource=inHouse` + `policyVersion` 있음 |
| `withinError` | `=` | `change.withinError` 유지(오차 범위 내) | `mb.change.withinError` 측정 오차 범위 안이에요 | 같음 |
| `meaningfulDecline` | 반대 방향 화살표 | `change.meaningfulDecline` 의미 있는 악화 | `mb.change.meaningfulDecline` 측정 오차보다 큰 변화가 목표와 반대 방향으로 나타났어요 | 같음 |
| `indeterminate` | 점선 원 | `change.indeterminate.withReason` 판정 불가 · {reason} | `mb.change.indeterminate` 이번에는 비교할 수 없어요({reason}) | 조건 사유(deviceChanged·conditionMismatch·protocolChanged·noComparison)만 |
| `pendingPolicy` | 없음 | `change.pendingPolicy` 산정 준비 중 | 배지 없음 + `mb.change.pendingPolicyFooter` | 항상 배지 없음 |

- 방향 `none` 지표의 중립 상태('의미 있는 증가/감소')는 키를 만들지 않는다(Q-16 전 렌더 금지).
- 문헌 MDC만 있는 지표·noMdc·referenceMetric 지표가 섞인 회원 리포트는 하단에 `mb.change.valuesOnlyFooter` '변화 비교는 기준이 준비된 수치에만 보여 드려요'를 한 줄 둔다(ASM-12-07). 정책 자체가 없으면 `mb.change.pendingPolicyFooter`가 우선한다.
- 트레이너 오프라인에서 판정 자리는 `common.onlineRequired` '온라인 필요'다(ADR-009).

### 3.5 판정 불가 사유(reasonCode)

| reasonCode | 트레이너 짧은 라벨 | 트레이너 툴팁(`.detail`) | 회원 `{reason}` |
|---|---|---|---|
| `deviceChanged` | `reason.deviceChanged` 기기 변경 | 기기가 바뀌어 이전 기록과 비교할 수 없습니다(F-BC-03.4 원문) | `mb.reason.deviceChanged` 측정 기기가 바뀌었어요 |
| `conditionMismatch` | `reason.conditionMismatch` 조건 불일치 | 측정 조건({condition})이 달라 비교할 수 없습니다. `{condition}`은 `condition.*` | 자세: `mb.reason.conditionMismatch.photo` 촬영 조건이 달라요 / 신체조성·둘레: `mb.reason.conditionMismatch.measure` 측정 조건이 달라요(ASM-12-06) |
| `protocolChanged` | `reason.protocolChanged` 프로토콜 변경 | 촬영·측정 프로토콜 버전이 달라 비교할 수 없습니다 | conditionMismatch와 같은 문장 |
| `noComparison` | `reason.noComparison` 비교할 측정 없음 | 비교할 측정이 없습니다 | `mb.reason.noComparison` 비교할 이전 기록이 없어요 |
| `noMdc` | `reason.noMdc` MDC 미확보 | 측정 오차 기준(MDC)이 없어 변화를 판정하지 않습니다 | (배지 없음) |
| `referenceMetric` | `reason.referenceMetric` 참고 지표 | 참고 지표라 값과 추이만 보여 줍니다 | (배지 없음) |
| `betaMetric` | `reason.betaMetric` 베타 지표 | 베타 값이라 같은 부위 나란히 보기만 제공합니다 | (노출 안 함) |

추이선 끊김(seriesBreak) 라벨: `series.break.device` '기기 변경: {from} → {to}', `series.break.protocol` '프로토콜 변경', `series.break.condition` '조건 불일치: {condition}'(F-VIZ-03.3). 점이 하나면 `chart.singlePoint` '비교할 측정이 없습니다 · 판정 불가'(F-VIZ-03.10). 직선 도움말은 `chart.lineHelp`.

### 3.6 화면 상태(§8.4) → 키

| 상태 | 트레이너 앱 | 회원 앱 |
|---|---|---|
| 빈 상태 | 화면별 `trNN.empty` + 다음 행동 버튼 1개(예 `tr01.empty` + `tr01.addMember`) | `mb01.empty`, `mb03.empty` |
| 동의 없음 | `consent.needed.healthData` / `consent.needed.bodyImaging` / `consent.needed.healthAndImaging` / `consent.needed.research` (탭하면 TR-14) | 영역 숨김 + `mb01.consentHidden` |
| 산정 준비 중 | `change.pendingPolicy` | 배지 없음 + `mb.change.pendingPolicyFooter` |
| 판정 불가 | `change.indeterminate.withReason` + 툴팁 `reason.*.detail` | 조건 사유만 `mb.change.indeterminate` |
| 베타 | `sourceGrade.observedSection`, `reliability.beta` | — |
| 오프라인·동기화 | `sync.localSavedWithPending`, `sync.awaitingConsent`, `soap.status.pendingFinalize` | `common.offlineStale` |
| 동기화 실패 | `sync.syncFailed` + `sync.reason.*` + `common.retry`. '동기화됨'을 표시하지 않음 | 동의 변경·코드 입력 실패 시 해당 messageKey 문장 + `common.retry` |
| 추후 추가 예정 | `common.comingSoon` | 쓰지 않음 |
| 불러오기 실패 | `common.loadFailed` + `common.retry`(빈 상태 문구와 동시 표시 금지) | `mb01.loadFailed` |

### 3.7 VoiceOver 문장(§8.6 A-03)

| 키 | 템플릿 | 규칙 |
|---|---|---|
| `a11y.metric` | {metricName} {value}{unit}, {side}, 출처 {source}, {date}, 변화 {status} | `{status}`는 §3.4 트레이너 라벨 또는 '산정 준비 중'. side가 none이면 `{side},` 조각을 뺀다 |
| `a11y.metric.withReason` | … 변화 {status}, 사유 {reason} | indeterminate일 때 |
| `a11y.beta` | 실측 대조 전 베타 참고값 | observedSection 값 라벨 끝에 덧붙인다 |
| `mb.a11y.metric` | {metricName} {value}{unit}, {date}, 출처 {source} | 자격 있는 highlight만 뒤에 `mb.change.*` 문장을 이어 붙인다. 판정 단어를 읽지 않는다 |

- 차트는 Swift Charts 오디오 그래프(트레이너), Flutter `Semantics` 요약(회원)을 쓰며 요약 문장도 이 규칙(출처·끊김 수·밴드 출처)을 따른다(A-03).
- 음수는 '−'(U+2212)로 적어 '마이너스'로 읽히게 한다(§2.6).

---

## 4 문구 키 체계

### 4.1 키 문법과 네임스페이스

- 정규식: `^[a-z][a-zA-Z0-9]*(\.[a-zA-Z0-9]+)+$`. 점으로 나눈 lowerCamel 조각 2개 이상.
- 형태: `<네임스페이스>.<영역>[.<세부>].<의미>`. 의미 조각은 명사나 동작(`recordComplete`, `retry`)이고, 문장 내용을 키에 옮겨 적지 않는다.
- 같은 문장이라도 뜻이 다르면 키를 나눈다(예 `tr08.confirm`과 `tr05.finalize`는 둘 다 '확정'이지만 동작이 다르다). 뜻이 같으면 공통 키를 재사용한다.
- 키는 한 번 배포하면 이름을 바꾸지 않는다. 문장만 고친다. 폐기할 때는 카탈로그에서 지우고 이 문서 표에서 삭제한다.

| 네임스페이스 | 용도 | 대상 기본값 |
|---|---|---|
| `common.*` | 두 앱 공통 버튼·상태·고지, 모르는 messageKey 대체 문장(`common.<code>`) | shared(`common.comingSoon`, `common.unparsed`는 trainer) |
| `sync.*`, `soap.status.*`, `posture.status.*`, `record.*` | 저장 상태·기록 상태 | trainer |
| `sourceGrade.*`, `reliability.*`, `mdc.*`, `change.*`, `reason.*`, `series.*`, `condition.*`, `chart.*` | 트레이너 표시 어휘(§3) | trainer(`chart.lineHelp`는 shared) |
| `mb.*` | 회원 표시 어휘(출처·변화 문장·지표명) | member |
| `metric.*`, `unit.*`, `side.*`, `timeOfDay.*` | 지표명(트레이너)·단위·측면 | trainer / shared |
| `region.*`, `joint.*`, `motion.*`, `muscleGroup.*`, `landmark.*`, `bodyMap.*` | 부록 A.3·A.5~A.7 코드 라벨 | trainer |
| `consent.*` | 동의 유형·상태·동의 필요 게이트 | shared / trainer |
| `consentDraft.*` | 동의 문서 초안(법률 검토 대기, 앱 번들 제외) | consentDraft |
| `auth.*`, `member.*`, `flag.*`, `idempotency.*`, `invite.*`, `summary.*`, `rights.*`, `account.*` | 서버 messageKey와 **같은 키**(§4.6) | 사용 앱에 따름 |
| `login.*`, `tr01.*`~`tr15.*` | 트레이너 화면 | trainer(TR-14 동의 카드 부분은 shared) |
| `mb01.*`~`mb06.*` | 회원 화면 | member |
| `ad01.*`~`ad07.*`, `audit.*`, `flag.<key>` | 관리자 화면·감사 action 라벨·플래그 라벨 | admin |
| `copy.warning.*` | 금지어 인라인 경고 | trainer |
| `notify.*` | 알림 템플릿 | notification |
| `store.*` | 스토어·설명서 | marketing |
| `a11y.*`, `mb.a11y.*` | VoiceOver 템플릿 | trainer / member |

### 4.2 대상(audience)과 린트 규칙 세트

| audience | 누가 읽나 | 린트 세트(§7.1) | 저장 위치(§4.4) |
|---|---|---|---|
| `trainer` | 트레이너 | common | Localizable.xcstrings |
| `member` | 회원 | common + member + 회원 약어 | Flutter `*_copy.dart` |
| `shared` | 두 앱 모두, 또는 트레이너 앱에서 회원이 읽는 화면(TR-14 동의 카드) | common + member + 회원 약어(더 엄격한 쪽) | 두 앱 카탈로그 모두 |
| `admin` | 관리자·운영자 | common | admin_web |
| `notification` | 회원(푸시·인앱) | common + member + 회원 약어 | 알림 도입 시 결정 |
| `marketing` | 외부(스토어·웹·영업·IR) | common + member + 회원 약어, G-10 수동 검수 | 수동 반영 |
| `consentDraft` | 회원(동의 문서 본문) | common + member + 회원 약어 | AD-03 draft 입력 |

- 트레이너 앱 안에서 회원이 직접 보는 화면(TR-14 동의 카드, TR-06의 회원 미리보기 영역)은 `shared`나 `member` 키만 쓴다. 미리보기 영역은 회원 앱 렌더러(MB-02·MB-04와 같은 문구 키)를 그대로 쓴다(F-SOAP-05.3).

### 4.3 플레이스홀더

- 덱의 표기는 `{name}`이다. 이름은 lowerCamel이며 각 항목의 `args`에 순서대로 적혀 있다.
- 값은 **호출하는 쪽에서 이미 형식화한 문자열**로 넘긴다(§2.6 표기 규칙). 숫자 형식화를 번역 문자열에 맡기지 않는다. 예외는 개수(`{count}`)뿐이다.

| 플랫폼 | 변환 규칙 | 예 |
|---|---|---|
| Swift `Localizable.xcstrings`(source language `ko`) | `{count}`·`{n}`·`{selected}`·`{total}` → `%lld`, 나머지 → `%@`. 인자가 둘 이상이면 위치 지정(`%1$@ %2$@`) | 카탈로그 값 `동기화 대기 %lld건`, 호출 `String(format: String(localized: "sync.pendingCount"), count)` |
| Dart `*_copy.dart` | 인자가 있으면 명명 인자 함수 | `static String sharedAt({required String date}) => '$date 공유';` |
| TypeScript `admin_web/lib/copy/ko.ts` | 템플릿 함수 | `validationMissing: (field: string) => \`${field} 항목이 비어 있어 게시할 수 없습니다.\`` |

`trainer_app/App/Localizable.xcstrings` 한 항목의 모양(DF-017이 파일을 만들고, 화면 스토리가 키를 더한다):

```json
{
  "sourceLanguage": "ko",
  "version": "1.0",
  "strings": {
    "tr05.finalize.excludedRows": {
      "comment": "V1-12 · AC-SOAP-02.4 · args: count",
      "extractionState": "manual",
      "localizations": { "ko": { "stringUnit": { "state": "translated", "value": "미완성 행 %lld개는 제외돼요" } } }
    }
  }
}
```

- `comment`에는 `V1-12 · <PRD ID> · args: ...`를 적는다. copy-lint는 `localizations.ko.stringUnit.value`만 검사한다(§7.8).
- 트레이너 앱은 v1에서 한국어만 둔다. 영어 등 다른 언어 항목을 추가하지 않는다(범위 밖).

### 4.4 플랫폼별 배치

| 대상 | 파일 | 규칙 |
|---|---|---|
| 트레이너 앱 | `trainer_app/App/Localizable.xcstrings` | 모든 사용자 노출 문자열. Swift 코드의 한국어 리터럴은 테스트·로그 외 0건을 목표로 한다(copy-lint가 리터럴도 검사). 모듈(`Feature*`)은 `String(localized:bundle: .main)`으로 앱 번들 카탈로그를 읽는다 |
| 회원 앱 공통 | `lib/copy/common_copy.dart`(`class CommonCopy`) | `common.*`, `mb.*`, `consent.*`, `unit.*`, `side.*`, 회원이 받는 messageKey |
| 회원 앱 화면 | `lib/screens/<feature>/<feature>_copy.dart` | P2 카드의 파일 이름을 따른다: `lib/screens/invite/invite_copy.dart`(MB-05), `lib/screens/trainer_records/trainer_records_copy.dart`(MB-03·04), `lib/screens/consent/consent_copy.dart`(MB-06), `lib/screens/body_report/body_report_copy.dart`(MB-01·02) |
| 관리자 웹 | `admin_web/lib/copy/ko.ts` | `ad*`, `audit.*`, `flag.<key>`, `auth.notAdmin` |
| 동결 앱(Runner 트레이너) | `ios/Runner/AppDelegate.swift` 안 리터럴 | 새 문자열을 만들지 않는다. DF-028이 바꾸는 줄만 §7.12 대체어로 고친다 |

- **ASM-12-11** 회원 앱은 v1에서 ARB·`intl` 메시지 생성을 도입하지 않는다(dfet:pubspec.yaml:33의 `flutter_localizations`, :43의 `intl`은 있지만 lib/l10n이 없다). P2 카드가 정한 화면별 `*_copy.dart` 상수 방식을 쓰고, 키 이름은 상수 옆 주석(`// mb05.submit`)으로 남긴다.
- **ASM-12-20** 관리자 웹 문구 파일은 `admin_web/lib/copy/ko.ts` 하나로 둔다(기존 파일 없음). 기존 화면 문자열은 옮기지 않고 새 화면(AD-02~AD-07 변경분)부터 쓴다.

### 4.5 접근성 식별자

- 탭할 수 있는 요소의 `accessibilityIdentifier`는 **문구 키와 같은 문자열**을 쓴다(예 `tr04.recordComplete`, `tr07.shutter`). XCUITest와 스냅샷 테스트는 식별자로 요소를 찾는다.
- 문구 키가 없는 요소(이미지, 컨테이너)는 `<trNN>.<영역>.<요소>`로 식별자만 만든다(예 `tr04.canvas`). 이 식별자는 카탈로그에 넣지 않는다.
- 회원 앱은 `Key('mb05.submit')`처럼 위젯 Key에 같은 문자열을 쓴다.

### 4.6 서버 messageKey와의 연결

- 서버는 한국어 문장을 보내지 않고 `details.messageKey`만 보낸다(V1-06 §3.5). 클라이언트는 **같은 이름의 문구 키**로 문장을 찾는다. 모르는 키면 `common.<code>`(camelCase, 예 `common.failedPrecondition`) 문장을 쓴다.
- 아래 messageKey는 V1-06이 '개발 결함'(사용자가 고칠 수 없음)으로 분류했다. 카탈로그에 별도 문장을 두지 않고 `common.devDefect`로 보이며, 오류 로그(식별자 없이 key만)를 남긴다: `consent.duplicateType`, `consent.signatureNotAllowed`, `consent.documentMismatch`, `consent.reconfirmMismatch`, `rights.typeMismatch`, `summary.shapeInvalid`, `change.metricNotInRecord`.
- `consent.notYetConfirmed`는 오류가 아니라 대기다. SyncEngine은 `awaitingConsent`로 처리하고 배지는 `sync.awaitingConsent`를 쓴다(V1-06 §3.6).
- `summary.prohibitedTerms`는 `details.violations[{field, term, start, end, ruleSet}]`를 함께 받는다. TR-06은 해당 범위를 밑줄로 표시하고 `copy.warning.replaceWith` + 규칙의 `alternatives`를 보인다(§7.10).

### 4.7 새 문구 추가 절차

1. 화면 스토리 PR에서 문자열이 필요하면 **copy_ko.json에 키를 먼저 추가**한다(대상·단계·근거·화면 필수). 같은 PR에서 이 문서 §4.9의 해당 표에 행을 더한다.
2. 플랫폼 카탈로그(§4.4)에 같은 키·같은 문장으로 옮겨 적는다.
3. `node tool/lint/prohibited-terms.mjs`가 덱과 카탈로그를 모두 검사한다. 회원 대상 문장은 회원 세트까지 통과해야 한다.
4. 회원 노출 문구(`member`, `shared`, `notification`, `marketing`, `consentDraft`)를 바꾸는 PR은 `regulatory` 라벨을 달고 소유자가 diff를 직접 읽고 병합한다([V1-01](01_AGILE_WORKING_AGREEMENT.md)).
5. 덱과 카탈로그의 불일치(키는 있는데 문장이 다름, 카탈로그에만 있는 키)는 copy-lint `--check-deck`이 경고로 보고한다(§7.9, ASM-12-22).

### 4.8 동의 문서 초안(법률 검토 대기)

- 앱은 동의 본문을 번들에 넣지 않는다. TR-14와 MB-06은 `consentDocumentVersions`의 published 문서(목적, 항목, 보유기간, 제공받는 자, 거부권·불이익)를 그대로 보인다(F-PRIV-01.2). 앱 카탈로그에는 제목 라벨(`tr14.consent.purpose` 등)만 있다.
- `consentDraft.<type>.<field>` 26개는 소유자가 AD-03에서 첫 draft를 만들 때 붙여 넣을 **초안**이다. 필드 이름은 V1-05의 `consentDocumentVersions` 필드와 같다(`title`, `purpose`, `items`, `recipient`, `retention`, `refusalNotice`).
- 모든 `retention` 문장은 `[법률 검토 대기]`로 시작한다. `{retentionMonths}`는 Q-24(보유기간 N) 결정값, `{centerName}`은 §6.7.0 센터명이다. G-04 의견을 받기 전에는 게시하지 않는다(G-04 미통과 = 동의 게이트 미통과).
- `items`는 V1-05에서 `arr<str>`다. 초안은 쉼표로 구분한 한 문장으로 두었고, AD-03 입력 때 쉼표 기준으로 나눈다.
- **ASM-12-16** 초안 문장은 PRD F-PRIV-01 표(대상 항목·거부 시 제한)와 §9.7 보존 표를 쉬운 말로 옮긴 것이다. 최종 문장은 법률 자문(DF-908)이 정한다.

### 4.9 문구 키 전체 목록

아래 표는 [data/copy_ko.json](data/copy_ko.json)과 같은 내용이다(생성기에서 함께 만듦). 대상 열의 값은 §4.2, 단계는 해당 문구가 처음 필요한 단계다. 화면 스토리 에이전트는 자기 화면 표와 §3의 공통 어휘만 보면 된다.

#### 공통(두 앱 공유)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `common.retry` | 다시 시도 | shared | P0 | §8.4, §9.6 |  |
| `common.cancel` | 취소 | shared | P0 |  |  |
| `common.confirm` | 확인 | shared | P0 |  |  |
| `common.close` | 닫기 | shared | P0 |  |  |
| `common.next` | 다음 | shared | P0 |  |  |
| `common.back` | 이전 | shared | P0 |  |  |
| `common.saveAction` | 저장하기 | shared | P0 | §6.0.3 | 동작 버튼 전용. 상태 표시로 '저장됨' 단독 문구 금지 |
| `common.loadFailed` | 불러오기 실패 | shared | P0 | §8.4, §9.6, F-VIZ-05.6 | 쿼리·권한 오류. 빈 상태 문구와 함께 쓰지 않음(AC-VIZ-05.4) |
| `common.loadFailed.detail` | 불러오지 못했어요. 연결을 확인하고 다시 시도해 주세요. | shared | P0 | §9.6 |  |
| `common.onlineRequired` | 온라인 필요 | shared | P1b | §7, F-SOAP-05.6 | 판정 표시·공유·해제는 온라인 전용 |
| `common.offlineStale` | 오프라인 · 최신이 아닐 수 있어요 | shared | P2 | §8.4 |  |
| `common.comingSoon` | 추후 추가 예정 | trainer | P0 | §6.0.3, §8.4 | 트레이너 앱 전용. 회원 앱은 진입점을 숨긴다(§8.4). v2 기능에는 쓰지 않음 |
| `common.unmeasured` | 미측정 | shared | P1a | §6.0.3, F-BC-03.1 | 0으로 표시하지 않음 |
| `common.notEntered` | 미입력 | shared | P1a | F-SOAP-01.2, F-SOAP-01.3 | NRS 미선택 등. 0과 구분 |
| `common.noNorm` | 규준 없음 | shared | P1b | §7.7, C-04 |  |
| `common.unparsed` | 해석 불가 | trainer | P0 | F-SOAP-06.2 | 알 수 없는 metricCode·레거시 표기 원문 보존 표시 |
| `common.devDefect` | 처리하지 못했어요. 문제가 계속되면 관리자에게 알려 주세요. | shared | P0 | V1-06 §3.6 | '개발 결함'으로 분류된 messageKey의 사용자 문장 |
| `common.disclaimer.short` | 운동 지도와 건강관리 기록용이며 진단이나 치료를 위한 정보가 아닙니다. | shared | P0 | §3.1 | §3.1 원문 그대로. allowEntries AE-01로 허용(부정문 고지) |
| `common.disclaimer.member` | 이 기록은 운동 지도를 돕는 참고 자료예요. 불편이 계속되면 의료진과 상담하세요. | member | P2 | §3.1 | 회원 리포트·요약 하단 |

#### 오류 messageKey(서버 details.messageKey와 같은 키)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `common.invalidArgument` | 입력 형식이 올바르지 않아요. | shared | P0 | V1-06 §3.6 |  |
| `common.failedPrecondition` | 지금은 처리할 수 없는 상태예요. | shared | P0 | V1-06 §3.5 | 모르는 messageKey 대체 문장 |
| `common.unauthenticated` | 다시 로그인해 주세요. | shared | P0 | V1-06 §3.5 |  |
| `common.permissionDenied` | 권한이 없어 처리할 수 없어요. | shared | P0 | V1-06 §3.5 |  |
| `common.notFound` | 대상을 찾을 수 없어요. | shared | P0 | V1-06 §3.5 |  |
| `common.alreadyExists` | 이미 처리된 요청이에요. | shared | P0 | V1-06 §3.5 |  |
| `common.aborted` | 다른 작업과 겹쳤어요. 잠시 뒤 다시 시도해 주세요. | shared | P0 | V1-06 §3.6 |  |
| `common.rateLimited` | 요청이 많아요. 잠시 뒤 다시 시도해 주세요. | shared | P0 | V1-06 §3.6 |  |
| `common.internal` | 일시적인 오류가 생겼어요. 잠시 뒤 다시 시도해 주세요. | shared | P0 | V1-06 §3.6 |  |
| `common.unavailable` | 서버에 연결할 수 없어요. 잠시 뒤 다시 시도해 주세요. | shared | P0 | V1-06 §3.6 |  |
| `common.deadlineExceeded` | 응답이 늦어요. 잠시 뒤 다시 시도해 주세요. | shared | P0 | V1-06 §3.6 |  |
| `auth.required` | 로그인이 필요해요. | shared | P0 | V1-06 §3.6 |  |
| `auth.notTrainer` | 트레이너 권한이 없는 계정이에요. 트레이너 계정으로 로그인하세요. | trainer | P0 | NFR-02 | claim 없으면 즉시 signOut 후 표시 |
| `auth.notAdmin` | 관리자 권한이 필요합니다. | admin | P0 | §10.7 |  |
| `auth.staffAccountNotAllowed` | 트레이너·관리자 계정은 이 기능을 쓸 수 없어요. 회원 계정으로 로그인해 주세요. | member | P2 | F-LINK-02.8 |  |
| `auth.sessionLocked` | 계정 권한이 바뀌어 다시 로그인해야 해요. | trainer | P0 | NFR-02 | claim 회수 잠금(DF-012) |
| `member.notAssigned` | 담당 회원이 아니어서 처리할 수 없어요. | trainer | P0 | F-LINK-03.1 |  |
| `member.pendingNotOwned` | 내가 등록한 대기 회원만 처리할 수 있어요. | trainer | P1a | F-LINK-01.2 |  |
| `member.notFound` | 회원 정보를 찾을 수 없어요. | shared | P0 |  |  |
| `flag.disabled` | 지금은 사용할 수 없는 기능이에요. | shared | P0 | §6.0.2, §8.4 | V1-06은 회원 앱에 '추후 추가 예정'을 매핑했지만 §8.4는 회원 앱에서 그 문구를 쓰지 않는다. 이 문장으로 통일(ASM-12-09) |
| `idempotency.keyReused` | 요청이 중복됐어요. 다시 시도해 주세요. | shared | P0 | V1-06 §3.6 |  |
| `consent.signatureInvalid` | 서명을 다시 받아 주세요. | trainer | P1a | F-PRIV-03.2 |  |
| `consent.documentNotPublished` | 동의 문서가 갱신됐어요. 최신 문서로 다시 진행해 주세요. | shared | P1a | F-PRIV-01.2 |  |
| `consent.requiredWithdrawNotSupported` | 필수 동의 철회는 탈퇴(대기 회원은 등록 취소)로 진행해요. | shared | P1a | F-PRIV-02.3 |  |
| `consent.requiredFirst` | ① 필수 동의를 먼저 받아야 해요. | shared | P1a | F-LINK-01.1 |  |
| `consent.capturedAtOutOfRange` | 7일이 지난 현장 동의는 기기에서 지웠어요. 다시 받아 주세요. | trainer | P1a | AS-32 |  |
| `consent.healthDataRequired` | 건강정보 동의(②)가 필요해요. | shared | P1a | F-SOAP-01.10, AC-PRIV-01.1 |  |
| `consent.notYetConfirmed` | 동의 확인 대기 | trainer | P1a | F-PRIV-03.7 | SyncEngine은 syncFailed가 아니라 awaitingConsent로 처리(V1-06 §3.6) |
| `account.staffSelfDeleteNotSupported` | 직원 계정은 앱에서 탈퇴할 수 없어요. 관리자에게 문의해 주세요. | shared | P1a | V1-06 §6.7 |  |
| `account.deleteFailed` | 삭제 중 문제가 생겨 다시 시도하고 있어요. | shared | P1a | F-PRIV-04.4 |  |
| `rights.notFound` | 요청을 찾을 수 없어요. | shared | P1a | F-PRIV-07 |  |
| `rights.alreadyRejected` | 이미 처리 불가로 종료된 요청이에요. | shared | P1a | F-PRIV-07 |  |
| `invite.invalidOrExpired` | 유효하지 않거나 만료된 코드예요. | member | P2 | F-LINK-02.7 | 사유는 이 문장 하나로만(없음·만료·폐기·타인 사용) |
| `invite.tooManyAttempts` | 입력 횟수를 넘었어요. 1시간 뒤 다시 시도해 주세요. | member | P2 | F-LINK-02.7 |  |
| `invite.conflict` | 이미 다른 트레이너와 연결돼 있어요. 센터에 문의해 주세요. | member | P2 | F-LINK-02.6 |  |
| `invite.profileMissing` | 프로필을 먼저 설정해 주세요. | member | P2 | V1-06 §6.12 |  |
| `invite.issueRateLimited` | 발급 횟수를 넘었어요. 1시간 뒤 다시 시도해 주세요. | trainer | P2 | V1-06 §6.11 |  |
| `summary.prohibitedTerms` | 쓸 수 없는 표현이 있어요. 표시된 부분을 바꿔 주세요. | trainer | P2 | F-PRIV-06.2, AC-SOAP-05.5 | details.violations로 위치 강조 |
| `summary.memberNotLinked` | 앱에 연결된 회원에게만 공유할 수 있어요. | trainer | P2 | F-SOAP-05.2 |  |
| `summary.sourceNotFinal` | 확정된 기록만 공유할 수 있어요. | trainer | P2 | F-SOAP-05.2, M3 |  |
| `summary.highlightExcluded` | 회원에게 보여 줄 수 없는 수치가 들어 있어요. 해당 수치를 빼 주세요. | trainer | P2 | F-SOAP-05.5, F-VIZ-06.4 |  |
| `summary.highlightNotFound` | 고른 수치를 찾을 수 없어요. 다시 불러와 주세요. | trainer | P2 | V1-06 §6.13 |  |
| `summary.photoNotAllowed` | 사진 동의(③)가 없거나 사진 넣기가 꺼져 있어요. | trainer | P2 | AC-SOAP-05.11 |  |
| `summary.notFound` | 요약을 찾을 수 없어요. | shared | P2 |  |  |
| `summary.notShared` | 공유가 해제된 요약이에요. | member | P2 | F-LINK-05.3 |  |
| `change.recordNotFound` | 비교할 기록을 찾을 수 없어요. | trainer | P3 | V1-06 §6.19 |  |

#### 저장 상태(syncState)·기록 상태

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `sync.localSaved` | 기기에 저장됨 | trainer | P0 | §6.0.3 | SwiftData 저장 성공 뒤에만 |
| `sync.syncing` | 동기화 중 | trainer | P0 | §6.0.3 |  |
| `sync.synced` | 동기화됨 | trainer | P0 | §6.0.3, NFR-06 | 서버 커밋 확인 + 업로드 대조 뒤에만(AC-C-05.1) |
| `sync.syncFailed` | 동기화 실패 | trainer | P0 | §6.0.3, C-05 | 사유(sync.reason.*)와 재시도를 함께 |
| `sync.awaitingConsent` | 동의 확인 대기 | trainer | P1a | §6.0.3, F-PRIV-03.7 |  |
| `sync.pendingCount` | 동기화 대기 {count}건 | trainer | P0 | §8.4 |  |
| `sync.localSavedWithPending` | 기기에 저장됨 · 동기화 대기 {count}건 | trainer | P1a | §8.4, AC-IA-03 |  |
| `sync.failedRetry` | 동기화 실패 · 다시 시도 | trainer | P0 | C-05 | 재시도 버튼 포함 배지 |
| `sync.localKept` | 원본은 이 기기에 남아 있어요. | trainer | P0 | F-SOAP-01.5, ADR-002 | syncFailed 상세 시트 |
| `sync.reason.ruleDenied` | 권한이나 동의 조건이 맞지 않아 서버가 저장을 받지 않았어요. | trainer | P0 | C-05 |  |
| `sync.reason.network` | 네트워크에 연결되면 자동으로 다시 보내요. | trainer | P0 | NFR-05 |  |
| `sync.reason.uploadMismatch` | 파일 확인값이 맞지 않아 다시 올려요. | trainer | P1a | ADR-002 |  |
| `sync.reason.retryLimit` | 여러 번 시도했지만 보내지 못했어요. | trainer | P0 | ADR-002 |  |
| `soap.status.draft` | 작성 중 | trainer | P1a | §6.4.2 |  |
| `soap.status.finalized` | 확정됨 | trainer | P1a | §6.4.2 |  |
| `soap.status.pendingFinalize` | 확정 대기 | trainer | P1a | F-SOAP-04.2 | syncState와 함께 표시 |
| `posture.status.pendingConfirmSync` | 확정 대기 · 동기화 중 | trainer | P1b | AC-ASM-04.5 |  |
| `record.voided` | 무효 처리됨 | trainer | P1a | F-VIZ-05.4 |  |

#### 출처 등급·신뢰 등급·MDC 라벨

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `sourceGrade.tape` | 줄자 실측 | trainer | P1a | §7.1 |  |
| `sourceGrade.device` | 기기 측정 · {deviceModel} | trainer | P1a | §7.1 |  |
| `sourceGrade.photoManual` | 사진 측정(확정) | trainer | P1b | §7.1 |  |
| `sourceGrade.photoAuto` | 사진 자동 추정 · 스크리닝 | trainer | P1b | §7.1, §6.0.3 | 점선 테두리와 함께 |
| `sourceGrade.photoAuto.chip` | 스크리닝 | trainer | P1b | §6.5.0 |  |
| `sourceGrade.observedSection` | 관측 단면 · 실측 대조 전 · 베타/참고 | trainer | P2 | §6.3, §7.1 | 모든 표시 위치에 필수(AC-LIDAR-03.2) |
| `sourceGrade.modelEstimate` | 모델 추정 | trainer | P0 | §7.1 | v1 표시 안 함. 해석 불가 방지용 키만 |
| `sourceGrade.aiAppearance` | AI 외형 · 실측 아님 | trainer | P0 | §7.1 | v1 표시 안 함 |
| `sourceGrade.selfReport` | 본인 보고 | trainer | P1a | §7.1 |  |
| `sourceGrade.trainerObserved` | 트레이너 관찰 | trainer | P1a | §7.1 |  |
| `sourceGrade.derived` | 계산값 | trainer | P1a | §7.1 |  |
| `mb.sourceGrade.tape` | 줄자로 잰 값 | member | P2 | §7.1 |  |
| `mb.sourceGrade.device` | 체성분계 측정 | member | P2 | §7.1 |  |
| `mb.sourceGrade.photoManual` | 사진으로 확인한 값 | member | P2 | §7.1 |  |
| `mb.sourceGrade.selfReport` | 직접 알려 준 값 | member | P2 | §7.1 |  |
| `mb.sourceGrade.trainerObserved` | 트레이너 확인 | member | P2 | §7.1 |  |
| `mb.sourceGrade.derived` | 계산한 값 | member | P2 | §7.1 |  |
| `reliability.reference` | 참고 | trainer | P1b | §6.5.0, §7.2 |  |
| `reliability.beta` | 베타 | trainer | P2 | §7.2 |  |
| `mb.reliability.reference` | 참고용 | member | P2 | §6.5.0 |  |
| `mdc.literature` | MDC ±{value}{unit} · 문헌값, 자체 재검사 전 | trainer | P3 | §6.5.0, AC-VIZ-03.4 | 문구 없으면 밴드도 그리지 않음 |
| `mdc.inHouse` | MDC ±{value}{unit} · 자체 재검사 | trainer | P3 | §6.5.0 |  |
| `mdc.none` | MDC 미확보 | trainer | P3 | §6.5.0 |  |
| `mdc.noneNoJudgement` | MDC 미확보 · 변화 판정 불가 | trainer | P3 | F-VIZ-03.6 |  |
| `mdc.referenceBand` | 참고 밴드 · 판정하지 않음 | trainer | P3 | F-VIZ-03.6 |  |
| `mdc.nrsBand` | MDC ±{value}점 · 문헌값, 자체 재검사 전 · 참고 밴드 · 판정하지 않음 | trainer | P3 | F-VIZ-04.4 | 값은 정책에서 읽음(하드코딩 금지) |
| `mb.mdc.band` | 측정 오차 범위 | member | P3 | §6.5.0, B.8 | inHouse일 때만 |
| `mb.mdc.bandInfo` | 이 범위 안의 차이는 같은 방법으로 다시 재도 생길 수 있는 차이예요. | member | P3 | F-VIZ-06.6 |  |

#### 변화 상태·판정 불가 사유(트레이너)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `change.meaningfulImprovement` | 의미 있는 개선 | trainer | P3 | §6.5.0, B.4 | 글리프(목표 방향 화살표)와 함께. 색만으로 구분 금지 |
| `change.withinError` | 유지(오차 범위 내) | trainer | P3 | §7.7 | '변화 없음' 금지 |
| `change.meaningfulDecline` | 의미 있는 악화 | trainer | P3 | §6.5.0 |  |
| `change.indeterminate` | 판정 불가 | trainer | P1b | §6.0.3 | 단독 사용 금지. 항상 사유와 함께(AC-C-03.2) |
| `change.indeterminate.withReason` | 판정 불가 · {reason} | trainer | P1b | §6.0.3, C-03 | {reason}=reason.* |
| `change.pendingPolicy` | 산정 준비 중 | trainer | P1b | §6.0.3, §7.6, AC-C-03.1 | dfet:lib/design_system/d_fet_evidence.dart:83과 같은 문구 |
| `change.draft` | 확정 전 | trainer | P1b | F-VIZ-01.3 |  |
| `change.referenceNoJudgement` | 참고 지표 · 판정하지 않음 | trainer | P1b | F-VIZ-01.3 |  |
| `change.sideSwitched` | 측면 바뀜 | trainer | P3 | §7.5 |  |
| `reason.conditionMismatch` | 조건 불일치 | trainer | P1b | §7.4, B.4 |  |
| `reason.deviceChanged` | 기기 변경 | trainer | P1b | B.4 |  |
| `reason.protocolChanged` | 프로토콜 변경 | trainer | P1b | B.4 |  |
| `reason.noMdc` | MDC 미확보 | trainer | P1b | B.4 |  |
| `reason.noComparison` | 비교할 측정 없음 | trainer | P1b | B.4, F-VIZ-03.10 |  |
| `reason.referenceMetric` | 참고 지표 | trainer | P1b | B.4 |  |
| `reason.betaMetric` | 베타 지표 | trainer | P2 | B.4 |  |
| `reason.deviceChanged.detail` | 기기가 바뀌어 이전 기록과 비교할 수 없습니다 | trainer | P1a | F-BC-03.4 | PRD 원문 |
| `reason.protocolChanged.detail` | 촬영·측정 프로토콜 버전이 달라 비교할 수 없습니다 | trainer | P1b | §7.4 |  |
| `reason.conditionMismatch.detail` | 측정 조건({condition})이 달라 비교할 수 없습니다 | trainer | P1b | §7.4 |  |
| `reason.noMdc.detail` | 측정 오차 기준(MDC)이 없어 변화를 판정하지 않습니다 | trainer | P1b | §7.3 |  |
| `reason.noComparison.detail` | 비교할 측정이 없습니다 | trainer | P1b | F-VIZ-03.10 |  |
| `reason.referenceMetric.detail` | 참고 지표라 값과 추이만 보여 줍니다 | trainer | P1b | §7.2 |  |
| `reason.betaMetric.detail` | 베타 값이라 같은 부위 나란히 보기만 제공합니다 | trainer | P2 | §6.3 |  |
| `chart.singlePoint` | 비교할 측정이 없습니다 · 판정 불가 | trainer | P1b | F-VIZ-03.10 |  |
| `chart.lineHelp` | 점 사이 직선은 보기 위한 연결이며 그 사이 값을 뜻하지 않아요. | shared | P1a | F-VIZ-03.4 |  |
| `series.break.device` | 기기 변경: {from} → {to} | trainer | P1a | F-VIZ-03.3 |  |
| `series.break.protocol` | 프로토콜 변경 | trainer | P1b | F-VIZ-03.3 |  |
| `series.break.condition` | 조건 불일치: {condition} | trainer | P1a | F-VIZ-03.3 |  |
| `series.break.timeline` | 추이 끊김 · {reason} | trainer | P1b | F-VIZ-05.1 |  |
| `condition.fasting` | 공복 여부 | trainer | P1a | §7.4 |  |
| `condition.timeOfDayBand` | 측정 시간대 | trainer | P1a | §7.4 |  |
| `condition.view` | 촬영 방향 | trainer | P1b | §7.4 |  |
| `condition.clothing` | 복장 | trainer | P1b | §7.4 |  |
| `condition.station` | 촬영 스테이션 | trainer | P1b | §7.4 |  |
| `condition.side` | 측면 | trainer | P1a | §7.4 |  |

#### 회원 문장 세트(부록 B.8 정본)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `mb.change.meaningfulImprovement` | 측정 오차보다 큰 변화가 정한 목표 방향으로 나타났어요 | member | P3 | B.8, §7.6 | inHouse·policyVersion 있을 때만 |
| `mb.change.withinError` | 측정 오차 범위 안이에요 | member | P3 | B.8 |  |
| `mb.change.meaningfulDecline` | 측정 오차보다 큰 변화가 목표와 반대 방향으로 나타났어요 | member | P3 | B.8 |  |
| `mb.change.indeterminate` | 이번에는 비교할 수 없어요({reason}) | member | P2 | B.8, F-VIZ-06.3 | 조건 사유에만. noMdc·referenceMetric·pendingPolicy는 배지 없음 |
| `mb.reason.deviceChanged` | 측정 기기가 바뀌었어요 | member | P2 | B.8 |  |
| `mb.reason.conditionMismatch.photo` | 촬영 조건이 달라요 | member | P2 | B.8 | 자세(사진) 지표의 conditionMismatch·protocolChanged |
| `mb.reason.conditionMismatch.measure` | 측정 조건이 달라요 | member | P2 | B.8 보완 제안 | 신체조성·둘레의 conditionMismatch·protocolChanged. ASM-12-06, 소유자 승인 전에는 photo 문장을 쓰지 않고 이 키를 비활성(배지 없음) |
| `mb.reason.noComparison` | 비교할 이전 기록이 없어요 | member | P2 | B.8 |  |
| `mb.change.pendingPolicyFooter` | 변화 비교 기준을 준비하고 있어요 | member | P2 | B.8, §6.0.3, AC-SOAP-05.9 |  |
| `mb.change.valuesOnlyFooter` | 변화 비교는 기준이 준비된 수치에만 보여 드려요 | member | P3 | F-VIZ-06.3 | 문헌 MDC만 있는 지표가 섞인 리포트. ASM-12-07 |

#### 지표 이름·단위·측면

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `metric.craniovertebralAngle.name` | 두개척추각(CVA) | trainer | P1b | 부록 A.1, B.8 |  |
| `mb.metric.craniovertebralAngle.name` | 머리·목 정렬 각도 | member | P2 | 부록 B.8 |  |
| `metric.headTiltFrontal.name` | 머리 기울기(정면, 참고) | trainer | P1b | 부록 A.1, B.8 |  |
| `mb.metric.headTiltFrontal.name` | 머리 기울기 | member | P2 | 부록 B.8 |  |
| `metric.shoulderTiltAngle.name` | 어깨 높이차(견봉선 기울기각) | trainer | P1b | 부록 A.1, B.8 |  |
| `mb.metric.shoulderTiltAngle.name` | 어깨 높이 차이 | member | P2 | 부록 B.8 |  |
| `metric.pelvicTiltFrontal.name` | 골반 기울기(정면, 참고) | trainer | P1b | 부록 A.1, B.8 |  |
| `mb.metric.pelvicTiltFrontal.name` | 골반 좌우 높이 차이 | member | P2 | 부록 B.8 |  |
| `metric.weightKg.name` | 체중 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.weightKg.name` | 체중 | member | P2 | 부록 B.8 |  |
| `metric.bodyFatPercent.name` | 체지방률 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.bodyFatPercent.name` | 체지방률 | member | P2 | 부록 B.8 |  |
| `metric.skeletalMuscleMassKg.name` | 골격근량 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.skeletalMuscleMassKg.name` | 골격근량 | member | P2 | 부록 B.8 |  |
| `metric.bodyFatMassKg.name` | 체지방량 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.bodyFatMassKg.name` | 체지방량 | member | P2 | 부록 B.8 |  |
| `metric.bmi.name` | 체질량지수(BMI) | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.bmi.name` | 체질량지수(BMI) | member | P2 | 부록 B.8 |  |
| `metric.visceralFatLevel.name` | 내장지방 레벨 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.visceralFatLevel.name` | 내장지방 레벨 | member | P2 | 부록 B.8 |  |
| `metric.totalBodyWaterL.name` | 체수분 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.totalBodyWaterL.name` | 체수분 | member | P2 | 부록 B.8 |  |
| `metric.waistCircumference.name` | 허리둘레 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.waistCircumference.name` | 허리둘레 | member | P2 | 부록 B.8 |  |
| `metric.hipCircumference.name` | 엉덩이둘레 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.hipCircumference.name` | 엉덩이둘레 | member | P2 | 부록 B.8 |  |
| `metric.thighCircumference.name` | 허벅지 둘레 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.thighCircumference.name` | 허벅지 둘레 | member | P2 | 부록 B.8 |  |
| `metric.upperArmCircumference.name` | 상완 둘레 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.upperArmCircumference.name` | 위팔 둘레 | member | P2 | 부록 B.8 |  |
| `metric.calfCircumference.name` | 종아리 둘레 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.calfCircumference.name` | 종아리 둘레 | member | P2 | 부록 B.8 |  |
| `metric.chestCircumference.name` | 가슴둘레 | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.chestCircumference.name` | 가슴둘레 | member | P2 | 부록 B.8 |  |
| `metric.painNrs.name` | 통증 점수(NRS 0–10) | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.painNrs.name` | 통증 점수(0–10) | member | P2 | 부록 B.8 | painNrs는 회원 요약·리포트 기본 제외(§7.6) |
| `metric.romDeg.name` | 관절가동범위(AROM) | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.romDeg.name` | 관절이 움직이는 범위(스스로 움직인 범위) | member | P2 | 부록 B.8 |  |
| `metric.mmtGrade.name` | 근력 등급(MMT 0–5) | trainer | P1a | 부록 A.1, B.8 |  |
| `mb.metric.mmtGrade.name` | 근력 등급(0–5) | member | P2 | 부록 B.8 |  |
| `metric.craniovertebralAngle.subtitle` | 머리 전방 자세 관찰 | trainer | P1b | F-ASM-03.7, 부록 A.1 | '거북목' 대체 |
| `metric.shoulderTiltAngle.subtitle` | 어깨 높이 차이 관찰 | trainer | P1b | 부록 C.1 |  |
| `metric.pelvicTiltFrontal.subtitle` | 골반 좌우 높이 차이 관찰 | trainer | P1b | F-ASM-03.7 | '골반 불균형' 대체 |
| `metric.notComputed` | 미산출 | trainer | P1b | F-ASM-04.2 | 0이 아니라 지표 부재 |
| `metric.rom.active` | AROM(능동) | trainer | P1a | F-SOAP-02.4, 부록 A.5 | 기본값 |
| `metric.rom.passive` | PROM(수동) | trainer | P1a | Q-23 | Q-23 결론 전 숨김(선택 불가) |
| `unit.deg` | ° | shared | P1b | 부록 A.1 | 값에 붙여 씀(2.9°) |
| `unit.kg` | kg | shared | P1a | 부록 A.1 |  |
| `unit.percent` | % | shared | P1a | 부록 A.1 |  |
| `unit.cm` | cm | shared | P1a | 부록 A.1 |  |
| `unit.kgPerM2` | kg/m² | shared | P1a | 부록 A.1 |  |
| `unit.liter` | L | shared | P1a | 부록 A.1 |  |
| `unit.level` | 레벨 | shared | P1a | 부록 A.1 | 기기 고유 척도 |
| `unit.point` | 점 | shared | P1a | 부록 A.1 | NRS |
| `unit.grade` | 등급 | shared | P1a | 부록 A.1 | MMT |
| `side.none` | — | shared | P1a | B.4 |  |
| `side.left` | 왼쪽 | shared | P1a | B.4 |  |
| `side.right` | 오른쪽 | shared | P1a | B.4 |  |
| `side.bilateral` | 양측 | shared | P1a | B.4 |  |
| `side.higher.left` | 왼쪽이 높음 | shared | P1b | F-ASM-03.3 | shoulderTilt·pelvicTilt(side=높은 쪽) |
| `side.higher.right` | 오른쪽이 높음 | shared | P1b | F-ASM-03.3 |  |
| `side.lower.left` | 왼쪽이 낮음 | shared | P1b | F-ASM-03.3 | headTilt(side=낮은 쪽) |
| `side.lower.right` | 오른쪽이 낮음 | shared | P1b | F-ASM-03.3 |  |
| `side.level` | 좌우 높이 같음 | shared | P1b | F-ASM-03.4 | 높이 차 1픽셀 미만(side=none, 값 0) |
| `timeOfDay.morning` | 오전(11시 전) | trainer | P1a | F-BC-01.2 | 경계는 제안값 |
| `timeOfDay.midday` | 낮(11~17시) | trainer | P1a | F-BC-01.2 |  |
| `timeOfDay.evening` | 저녁(17시 이후) | trainer | P1a | F-BC-01.2 |  |

#### 부위·관절·운동 방향·근육군·랜드마크 라벨

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `region.head` | 머리 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.neck` | 목 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.shoulderLeft` | 왼쪽 어깨 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.shoulderRight` | 오른쪽 어깨 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.upperBack` | 등 위쪽 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.lowerBack` | 허리 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.chest` | 가슴 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.abdomen` | 배 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.elbowLeft` | 왼쪽 팔꿈치 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.elbowRight` | 오른쪽 팔꿈치 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.wristHandLeft` | 왼쪽 손목·손 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.wristHandRight` | 오른쪽 손목·손 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.hipLeft` | 왼쪽 엉덩이 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.hipRight` | 오른쪽 엉덩이 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.thighLeft` | 왼쪽 허벅지 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.thighRight` | 오른쪽 허벅지 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.kneeLeft` | 왼쪽 무릎 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.kneeRight` | 오른쪽 무릎 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.calfLeft` | 왼쪽 종아리 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.calfRight` | 오른쪽 종아리 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.ankleFootLeft` | 왼쪽 발목·발 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `region.ankleFootRight` | 오른쪽 발목·발 | trainer | P1a | 부록 A.7(초안) | DF-916 확정 전 초안. 부위만, 증상 금지 |
| `joint.cervicalSpine` | 목(경추) | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.thoracicSpine` | 등(흉추) | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.lumbarSpine` | 허리(요추) | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.shoulder` | 어깨 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.elbow` | 팔꿈치 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.wrist` | 손목 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.hip` | 엉덩관절 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.knee` | 무릎 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `joint.ankle` | 발목 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.flexion` | 굽힘 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.extension` | 폄 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.abduction` | 벌림 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.adduction` | 모음 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.horizontalAbduction` | 수평 벌림 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.horizontalAdduction` | 수평 모음 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.internalRotation` | 안쪽 돌림 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.externalRotation` | 바깥쪽 돌림 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.lateralFlexion` | 옆으로 굽힘 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.rotation` | 돌림 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.dorsiflexion` | 발등굽힘 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.plantarflexion` | 발바닥굽힘 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.inversion` | 안쪽 번짐 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `motion.eversion` | 바깥쪽 번짐 | trainer | P1a | 부록 A.5(초안) | DF-916 확정 전 초안 |
| `muscleGroup.neckFlexors` | 목 굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.neckExtensors` | 목 폄근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.shoulderFlexors` | 어깨 굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.shoulderAbductors` | 어깨 벌림근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.shoulderInternalRotators` | 어깨 안쪽 돌림근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.shoulderExternalRotators` | 어깨 바깥쪽 돌림근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.elbowFlexors` | 팔꿈치 굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.elbowExtensors` | 팔꿈치 폄근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.trunkFlexors` | 몸통 굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.trunkExtensors` | 몸통 폄근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.hipFlexors` | 엉덩관절 굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.hipExtensors` | 엉덩관절 폄근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.hipAbductors` | 엉덩관절 벌림근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.hipAdductors` | 엉덩관절 모음근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.kneeExtensors` | 무릎 폄근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.kneeFlexors` | 무릎 굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.ankleDorsiflexors` | 발목 발등굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `muscleGroup.anklePlantarflexors` | 발목 발바닥굽힘근 | trainer | P1a | 부록 A.6(초안) | DF-916 확정 전 초안 |
| `landmark.tragusLeft` | 왼쪽 이주 | trainer | P1b | 부록 A.3 |  |
| `landmark.tragusRight` | 오른쪽 이주 | trainer | P1b | 부록 A.3 |  |
| `landmark.c7` | C7(제7경추 가시돌기) | trainer | P1b | 부록 A.3 |  |
| `landmark.earLeft` | 왼쪽 귀 | trainer | P1b | 부록 A.3 |  |
| `landmark.earRight` | 오른쪽 귀 | trainer | P1b | 부록 A.3 |  |
| `landmark.acromionLeft` | 왼쪽 견봉 | trainer | P1b | 부록 A.3 |  |
| `landmark.acromionRight` | 오른쪽 견봉 | trainer | P1b | 부록 A.3 |  |
| `landmark.asisLeft` | 왼쪽 ASIS(위앞엉덩뼈가시) | trainer | P1b | 부록 A.3 |  |
| `landmark.asisRight` | 오른쪽 ASIS(위앞엉덩뼈가시) | trainer | P1b | 부록 A.3 |  |
| `bodyMap.title` | 통증 부위(도식) | trainer | P1a | F-VIZ-04.1 | '근육'·'해부학' 표현 금지(AC-VIZ-04.1) |

#### 동의 공통 라벨

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `consent.type.required` | ① 서비스 이용 필수 동의 | shared | P1a | F-PRIV-01 |  |
| `consent.type.healthData` | ② 건강정보 수집·이용 | shared | P1a | F-PRIV-01 |  |
| `consent.type.bodyImaging` | ③ 신체 사진·영상·3D 정보 | shared | P1a | F-PRIV-01 |  |
| `consent.type.sharing` | ④ 후임 담당 트레이너 인계 | shared | P1a | F-PRIV-01, F-PRIV-01.5 |  |
| `consent.type.research` | ⑤ 가명처리 연구 참여 | shared | P1a | F-PRIV-01 |  |
| `consent.state.granted` | 동의함 | shared | P1a | F-PRIV-02 |  |
| `consent.state.withdrawn` | 철회함 | shared | P1a | F-PRIV-02 |  |
| `consent.state.notAsked` | 받지 않음 | shared | P1a | F-PRIV-01.1 |  |
| `consent.state.later` | 나중에 | shared | P1a | F-PRIV-01.1 | ④⑤ 기본 |
| `consent.state.awaiting` | 동의 확인 대기 | trainer | P1a | F-PRIV-03.7 |  |
| `consent.state.revisedPending` | 재동의 필요 | shared | P1a | F-PRIV-01.3 |  |
| `consent.needed.healthData` | 동의 ② 필요 · 현장 동의 열기 | trainer | P1a | §8.4, F-SOAP-01.10 | 탭하면 TR-14 |
| `consent.needed.bodyImaging` | 동의 ③ 필요 · 현장 동의 열기 | trainer | P1b | §8.4 |  |
| `consent.needed.healthAndImaging` | 동의 ②③ 필요 · 현장 동의 열기 | trainer | P1b | F-ASM-01.5, AC-ASM-01.1 |  |
| `consent.needed.research` | 동의 ⑤ 또는 연구참여 동의서 필요 | trainer | P1b | F-ASM-05, AC-ASM-05.1 |  |
| `consent.awaiting.photoDisabled` | 동의가 서버에서 확인된 뒤 촬영할 수 있어요 | trainer | P1b | F-PRIV-03.7, F-ASM-01.8 |  |
| `consent.photoNoConsent` | 사진 동의 없음 | trainer | P1b | F-VIZ-02.7 | 좌표 도식도 숨김 |
| `consent.rejected.retake` | 동의 다시 받기 | trainer | P1a | F-PRIV-03 |  |

#### 동의 문서 초안(법률 검토 대기, AD-03 시드 전용)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `consentDraft.required.title` | ① 서비스 이용 필수 동의 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 title |
| `consentDraft.required.purpose` | 회원 확인, 담당 트레이너 연결, 서비스 이용 기록 관리 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 purpose |
| `consentDraft.required.items` | 표시명, 성별, 출생연도, 만 14세 이상 확인, 담당 트레이너, 이용 기록 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 items |
| `consentDraft.required.retention` | [법률 검토 대기] 탈퇴 또는 등록 취소 후 5영업일 안에 파기합니다. 동의 증빙은 별도 보존 기간(Q-07)에 따릅니다. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 retention |
| `consentDraft.required.refusalNotice` | 동의하지 않을 수 있어요. 동의하지 않으면 서비스를 이용할 수 없고 대기 회원 등록이 취소돼요. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 refusalNotice |
| `consentDraft.healthData.title` | ② 건강정보 수집·이용(선택) | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 title |
| `consentDraft.healthData.purpose` | 운동 지도와 일상 건강관리를 위한 세션 기록과 측정 기록 관리 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 purpose |
| `consentDraft.healthData.items` | 체성분 결과(체중, 체지방률, 골격근량 등), 키, 통증 점수와 불편 부위, 트레이너 세션 기록, 자세 각도, 둘레, 체성분 결과지 사진 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 items |
| `consentDraft.healthData.retention` | [법률 검토 대기] 마지막 세션 또는 담당 종료 후 {retentionMonths}개월 보관 후 파기합니다. 철회하면 5영업일 안에 파기합니다. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 retention |
| `consentDraft.healthData.refusalNotice` | 동의하지 않을 수 있어요. 동의하지 않으면 트레이너가 건강 기록을 작성하거나 볼 수 없어요. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 refusalNotice |
| `consentDraft.bodyImaging.title` | ③ 신체 사진·영상·3D 정보(선택) | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 title |
| `consentDraft.bodyImaging.purpose` | 자세 사진 관찰과 전후 비교 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 purpose |
| `consentDraft.bodyImaging.items` | 정면·측면 신체 사진, 사진 위 기준점 좌표, 3D 스캔에서 만든 썸네일·단면 윤곽·파일 확인값 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 items |
| `consentDraft.bodyImaging.retention` | [법률 검토 대기] 마지막 세션 또는 담당 종료 후 {retentionMonths}개월 보관 후 파기합니다. 철회하면 사진과 좌표를 5영업일 안에 파기하고 각도 값은 ②에 따라 보관합니다. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 retention |
| `consentDraft.bodyImaging.refusalNotice` | 동의하지 않을 수 있어요. 동의하지 않으면 체형 촬영을 할 수 없어요. 사진 없이 세션 기록은 계속할 수 있어요. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 refusalNotice |
| `consentDraft.sharing.title` | ④ 후임 담당 트레이너 인계(선택) | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 title |
| `consentDraft.sharing.purpose` | 담당 트레이너가 바뀌어도 운동 지도를 이어 가기 위해 확정된 기록을 넘깁니다 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 purpose |
| `consentDraft.sharing.items` | 확정된 세션 기록 원문, 체형평가, 신체조성, 둘레(사진은 ③ 동의 범위 안에서만) | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 items |
| `consentDraft.sharing.recipient` | 같은 센터({centerName}) 소속 후임 담당 트레이너 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 recipient |
| `consentDraft.sharing.retention` | [법률 검토 대기] 인계받은 트레이너가 담당하는 기간 동안 보관합니다. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 retention |
| `consentDraft.sharing.refusalNotice` | 동의하지 않을 수 있어요. 동의하지 않으면 담당이 바뀔 때 이전 기록을 넘기지 않고 새 담당은 빈 기록에서 시작해요. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 refusalNotice |
| `consentDraft.research.title` | ⑤ 가명처리 연구 참여(선택) | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 title |
| `consentDraft.research.purpose` | 가명처리한 자료로 측정 신뢰도 연구(기관생명윤리위원회 승인 연구)에 참여 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 purpose |
| `consentDraft.research.items` | 가명처리한 자세 각도와 기준점 좌표, 둘레 대조값, 연구참여 동의서 동의 기록 | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 items |
| `consentDraft.research.retention` | [법률 검토 대기] 연구 계획서에 정한 기간 동안 보관합니다. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 retention |
| `consentDraft.research.refusalNotice` | 동의하지 않을 수 있어요. 동의하지 않아도 서비스 이용에 불이익이 없어요. | consentDraft | P1a | F-PRIV-01, F-PRIV-01.2, F-PRIV-01.5, G-04, Q-24 | 법률 검토(G-04) 전 초안. 앱 번들에 넣지 않는다. consentDocumentVersions 필드 refusalNotice |

#### TR-01 오늘(세션 보드)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr01.title` | 오늘 | trainer | P1a | TR-01 |  |
| `tr01.addMember` | 오늘 목록에 회원 추가 | trainer | P1a | AC-IA-05 |  |
| `tr01.empty` | 오늘 볼 회원을 추가하세요 | trainer | P1a | §8.4 | 빈 상태 다음 행동 버튼 1개 |
| `tr01.carriedOver` | 어제 목록에서 이어짐 | trainer | P1a | AC-IA-05 |  |
| `tr01.reviewPending.title` | Review 대기 | trainer | P1a | §6.4.1 |  |
| `tr01.reviewPending.count` | 확정 전 기록 {count}건 | trainer | P1a | F-SOAP-04 |  |
| `tr01.sessionCount.prompt` | 오늘 진행한 세션 수를 알려 주세요 | trainer | P1a | M-02 | 하루 한 번 |
| `tr01.sessionCount.submit` | 보고 | trainer | P1a | M-02 |  |
| `tr01.sessionCount.done` | 오늘 세션 수를 보고했어요 | trainer | P1a | M-02 |  |
| `tr01.reassessDue` | 재평가 예정 | trainer | P1a | Q-11 | 주기는 트레이너 설정(Q-11 기본값) |
| `tr01.consentExpiredPurged` | 7일 안에 확인되지 않은 현장 동의 {count}건과 관련 기록을 기기에서 지웠어요 | trainer | P1a | AS-32 |  |

#### TR-02 회원 목록

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr02.title` | 회원 | trainer | P0 | TR-02 |  |
| `tr02.search` | 회원 검색 | trainer | P1a | TR-02 |  |
| `tr02.empty` | 아직 담당 회원이 없어요 | trainer | P0 | §8.4 |  |
| `tr02.addPending` | 대기 회원 추가 | trainer | P1a | F-LINK-01 | TR-14로 이동 |
| `tr02.badge.pending` | 대기 | trainer | P1a | F-LINK-01 |  |
| `tr02.consent.ok` | 동의 ①②③ | trainer | P1a | TR-02 |  |
| `tr02.consent.needed` | 동의 필요 | trainer | P1a | TR-02 |  |
| `tr02.menu.cancelPending` | 등록 취소 | trainer | P1a | F-LINK-01.5 |  |
| `tr02.cancelPending.confirm` | 대기 회원 등록을 취소할까요? 연결된 기록은 5영업일 안에 파기돼요. | trainer | P1a | F-LINK-01.5 |  |

#### TR-03 회원 상세·통합 타임라인

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr03.header.trainer` | 담당 | trainer | P1a | TR-03 |  |
| `tr03.header.consent` | 동의 상태 | trainer | P1a | TR-03 |  |
| `tr03.startSession` | 세션 시작 | trainer | P1a | §6.4.1 |  |
| `tr03.empty` | 아직 기록이 없어요 | trainer | P1a | §8.4 |  |
| `tr03.filter.soap` | SOAP | trainer | P1a | F-VIZ-05.2 |  |
| `tr03.filter.posture` | 체형평가 | trainer | P1b | F-VIZ-05.2 |  |
| `tr03.filter.bodyComposition` | 신체조성 | trainer | P1a | F-VIZ-05.2 |  |
| `tr03.filter.circumference` | 둘레 | trainer | P1a | F-VIZ-05.2 |  |
| `tr03.filter.lidar` | LiDAR 스캔(베타) | trainer | P2 | F-VIZ-05.1 | lidarBeta=false면 항목 없음 |
| `tr03.filter.showVoided` | 무효 기록 보기 | trainer | P1a | F-VIZ-05.4 |  |
| `tr03.loadMore` | 더 보기 | trainer | P1a | F-VIZ-05.6 |  |
| `tr03.event.addendumCount` | 추가 기록 {count}건 | trainer | P1a | F-SOAP-04.5 |  |
| `tr03.posture.baseline` | 기준선 | trainer | P1b | F-ASM-04.4 |  |
| `tr03.posture.olderVersions` | 이전 버전 {count}개 | trainer | P1b | F-VIZ-05.4 |  |
| `tr03.circumference.summary` | 둘레 {count}부위 | trainer | P1a | F-VIZ-05.1 |  |
| `tr03.promoted` | 앱 연결됨 | trainer | P2 | F-VIZ-05.5 |  |
| `tr03.summaryShared` | 회원에게 공유함 | trainer | P2 | F-VIZ-05.1 |  |
| `tr03.summaryRevoked` | 공유 해제함 | trainer | P2 | F-VIZ-05.1 |  |
| `tr03.painHeatmap.title` | 통증 부위(도식) · 기간 | trainer | P2 | F-VIZ-04.3 |  |
| `tr03.painHeatmap.legend` | 선택된 세션 수({selected}/{total}) | trainer | P2 | F-VIZ-04.3 |  |

#### TR-04 세션 Live

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr04.start.prompt` | 오늘 작성 중인 기록이 있어요 | trainer | P1a | F-SOAP-01.8 |  |
| `tr04.start.continue` | 이어쓰기 | trainer | P1a | F-SOAP-01.8 |  |
| `tr04.start.new` | 새 세션 | trainer | P1a | F-SOAP-01.8 |  |
| `tr04.quickNote.placeholder` | 한 줄 메모 | trainer | P1a | F-SOAP-01.1 |  |
| `tr04.canvas` | 필기 영역 | trainer | P1a | F-SOAP-01.1 | VoiceOver 라벨 |
| `tr04.pain.nrs` | 통증 점수 | trainer | P1a | F-SOAP-01.3 |  |
| `tr04.pain.regions` | 통증 부위 | trainer | P1a | F-SOAP-01.3 |  |
| `tr04.chip.pain` | 통증 | trainer | P1a | F-SOAP-01.4 |  |
| `tr04.chip.rom` | ROM | trainer | P1a | F-SOAP-01.4 |  |
| `tr04.chip.mmt` | MMT | trainer | P1a | F-SOAP-01.4 |  |
| `tr04.chip.exercise` | 운동 | trainer | P1a | F-SOAP-01.4 |  |
| `tr04.chip.reserved` | Review에서 입력할 자리 {count}개 | trainer | P1a | F-SOAP-01.4 | 값 없는 예약 행은 측정값처럼 보이지 않게 |
| `tr04.indicator.lastNrs` | 최근 통증 점수 | trainer | P1a | F-SOAP-01.11 |  |
| `tr04.indicator.lastRegions` | 최근 통증 부위 | trainer | P1a | F-SOAP-01.11 |  |
| `tr04.indicator.nextPlan` | 다음 세션 계획 | trainer | P1a | F-SOAP-01.11 |  |
| `tr04.indicator.lastBodyComp` | 최근 신체조성 기록 | trainer | P1a | F-SOAP-01.11 |  |
| `tr04.indicator.lastPosture` | 최근 체형평가 | trainer | P1b | F-SOAP-01.11 |  |
| `tr04.indicator.none` | 기록 없음 | trainer | P1a | F-SOAP-01.11 |  |
| `tr04.previousNote` | 지난 기록 | trainer | P1a | §6.4.1 | 최대 3줄 |
| `tr04.recordComplete` | 기록 완료 | trainer | P1a | F-SOAP-01.2, M-01 | 접근성 식별자 tr04.recordComplete |
| `tr04.recordComplete.done` | 기록 완료됨 | trainer | P1a | F-SOAP-01.2 | syncState 배지와 함께 |
| `tr04.endSession` | 세션 종료 | trainer | P1a | §6.4.1, M-02 |  |
| `tr04.endSession.reviewNow` | 지금 Review | trainer | P1a | §6.4.1 | M1: 자동 전환·모달 없음 |
| `tr04.endSession.later` | 나중에 | trainer | P1a | §6.4.1 |  |

#### TR-05 Review

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr05.title` | Review | trainer | P1a | TR-05 |  |
| `tr05.inkPreview` | 필기 원본(변경되지 않음) | trainer | P1a | F-SOAP-02.1 |  |
| `tr05.quickNote` | 한 줄 메모 | trainer | P1a | F-SOAP-02.2 |  |
| `tr05.quickNote.copyToS` | 오늘 불편·요청에 넣기 | trainer | P1a | F-SOAP-02.2 |  |
| `tr05.s.title` | S · 오늘 불편·요청 | trainer | P1a | F-SOAP-02.3, §3.4-6 | '주호소' 대신 |
| `tr05.s.chiefComplaint` | 오늘 불편·요청 | trainer | P1a | F-SOAP-02.3 |  |
| `tr05.o.title` | 오늘 확인한 수치(O) | trainer | P1a | F-SOAP-02.4 |  |
| `tr05.o.add` | 행 추가 | trainer | P1a | F-SOAP-02.4 |  |
| `tr05.o.joint` | 관절 | trainer | P1a | F-SOAP-02.4 |  |
| `tr05.o.motion` | 운동 방향 | trainer | P1a | F-SOAP-02.4 |  |
| `tr05.o.muscleGroup` | 근육군 | trainer | P1a | F-SOAP-02.4 |  |
| `tr05.o.side` | 측면 | trainer | P1a | F-SOAP-02.4 |  |
| `tr05.o.incomplete` | 미완성 | trainer | P1a | AC-SOAP-02.4 |  |
| `tr05.o.nonNumeric` | 숫자가 아닌 내용은 관찰로 옮겨 주세요 | trainer | P1a | F-SOAP-02.5, AC-SOAP-02.3 |  |
| `tr05.o.moveToObservations` | 관찰로 옮기기 | trainer | P1a | F-SOAP-02.5 |  |
| `tr05.o.previousValue` | 지난 값 {value}{unit} | trainer | P1a | F-SOAP-07.2 |  |
| `tr05.o.autoLoad.title` | 측정 기록 불러오기 | trainer | P1b | F-SOAP-03 |  |
| `tr05.o.autoLoad.sameDay` | 같은 날 기록 | trainer | P1b | F-SOAP-03.2 | 기본 선택 |
| `tr05.o.autoLoad.earlier` | 이전 기록(종류별 최근 1건) | trainer | P1b | F-SOAP-03.2, AS-23 | 기본 선택 안 함 |
| `tr05.o.noCandidates` | 불러올 기록 없음 | trainer | P1b | F-SOAP-03.8 |  |
| `tr05.o.snapshotBadge` | 스냅샷 · {date} | trainer | P1b | F-SOAP-03.3 |  |
| `tr05.o.sourceChanged` | 원본 변경됨 | trainer | P1b | F-SOAP-03.6 |  |
| `tr05.o.openSource` | 원본 보기 | trainer | P1b | F-SOAP-03.6 |  |
| `tr05.o.reload` | 스냅샷 다시 불러오기 | trainer | P1b | F-SOAP-03.7 | draft에서만 |
| `tr05.a.title` | A · 운동 관점 평가 | trainer | P1a | §3.4-1, F-SOAP-02.7 |  |
| `tr05.a.summary` | 평가 요약 | trainer | P1a | F-SOAP-02.7 |  |
| `tr05.a.observations` | 관찰 | trainer | P1a | F-SOAP-02.7 |  |
| `tr05.assessment.recommended` | 권장 | trainer | P1a | F-SOAP-02.7 | 비어 있으면 배지 |
| `tr05.p.title` | P · 계획 | trainer | P1a | F-SOAP-02.8 |  |
| `tr05.p.nextSession` | 다음 세션 | trainer | P1a | F-SOAP-02.8 |  |
| `tr05.p.homeExercise` | 집에서 할 운동 | trainer | P1a | F-SOAP-02.8 |  |
| `tr05.p.requiredForFinalize` | 확정 필수 | trainer | P1a | §6.4.4 |  |
| `tr05.memberNote` | 회원에게 남길 한 줄 | trainer | P1a | F-SOAP-02.10 |  |
| `tr05.memberNote.counter` | {count}/200 | trainer | P1a | F-SOAP-02.10 |  |
| `tr05.checklist.title` | 확정 전 확인 | trainer | P1a | §6.4.4 |  |
| `tr05.checklist.member` | 회원 | trainer | P1a | §6.4.4 |  |
| `tr05.checklist.date` | 세션 날짜 | trainer | P1a | §6.4.4 |  |
| `tr05.checklist.todayNote` | 오늘 기록 한 줄 | trainer | P1a | §6.4.4 |  |
| `tr05.checklist.nextPlan` | 다음 계획 | trainer | P1a | §6.4.4 |  |
| `tr05.checklist.assessment` | 운동 관점 평가(권장) | trainer | P1a | §6.4.4 |  |
| `tr05.finalize` | 확정 | trainer | P1a | F-SOAP-04.1 |  |
| `tr05.finalize.irreversible` | 확정하면 원문을 고칠 수 없어요. 이후 수정은 추가 기록으로 남아요. | trainer | P1a | F-SOAP-04.1, F-SOAP-04.4 |  |
| `tr05.finalize.excludedRows` | 미완성 행 {count}개는 제외돼요 | trainer | P1a | AC-SOAP-02.4 |  |
| `tr05.finalize.warningsRemain` | 경고가 남은 표현이 있어요. 그대로 확정할까요? | trainer | P1a | §6.4.4-7 |  |
| `tr05.finalize.offlineQueued` | 확정 대기 · 온라인이 되면 확정돼요 | trainer | P1a | F-SOAP-04.2 |  |
| `tr05.finalize.rejected` | 서버가 확정을 받지 않았어요. 잠금을 풀었으니 확인 후 다시 확정해 주세요. | trainer | P1a | F-SOAP-04.2 |  |
| `tr05.finalizeAndPreview` | 확정 후 공유 미리보기 | trainer | P2 | F-SOAP-04.9 | 공유는 TR-06 명시 버튼으로만 |
| `tr05.continueFromPrevious` | 이전 노트 이어쓰기 | trainer | P1a | F-SOAP-07.2 |  |
| `tr05.quickPhrases` | 빠른 문구 | trainer | P1a | F-SOAP-07.1 |  |
| `tr05.quickPhrase.s.1` | 지난 세션 이후 새 불편 없음 | trainer | P1a | F-SOAP-07.1 | 기본 빠른 문구(S). 기록 텍스트에 삽입 |
| `tr05.quickPhrase.s.2` | 운동 다음 날 뻐근함 있었음 | trainer | P1a | F-SOAP-07.1 |  |
| `tr05.quickPhrase.s.3` | 오늘 컨디션 평소와 비슷함 | trainer | P1a | F-SOAP-07.1 |  |
| `tr05.quickPhrase.a.1` | 동작 수행 안정적 | trainer | P1a | F-SOAP-07.1 | 기본 빠른 문구(A). 관찰 표현만 |
| `tr05.quickPhrase.a.2` | 움직임 범위 제한 관찰 | trainer | P1a | F-SOAP-07.1 |  |
| `tr05.quickPhrase.a.3` | 좌우 차이 관찰 | trainer | P1a | F-SOAP-07.1 |  |
| `tr05.quickPhrase.p.1` | 다음 세션 같은 프로그램 유지 | trainer | P1a | F-SOAP-07.1 | 기본 빠른 문구(P). 트레이너 확정 |
| `tr05.quickPhrase.p.2` | 다음 세션 강도 한 단계 조정 | trainer | P1a | F-SOAP-07.1 |  |
| `tr05.quickPhrase.p.3` | 홈 운동 동작 복습 | trainer | P1a | F-SOAP-07.1 |  |
| `tr05.addendum.title` | 추가 기록 | trainer | P1a | F-SOAP-04.4 |  |
| `tr05.addendum.reason` | 사유(필수) | trainer | P1a | F-SOAP-04.4 |  |
| `tr05.addendum.reason.trainerCorrection` | 트레이너 정정 | trainer | P1a | F-SOAP-04.4 | AddendumReason.trainerCorrection |
| `tr05.addendum.reason.subjectRectificationRequest` | 정보주체 정정 요구 | trainer | P1a | F-PRIV-07.3 | PRD 원문 |
| `tr05.addendum.reasonRequired` | 사유를 입력해 주세요 | trainer | P1a | AC-SOAP-04.2 |  |
| `tr05.addendum.changedFields` | 바뀐 항목 | trainer | P1a | F-SOAP-04.4 |  |
| `tr05.deleteDraft` | 작성 중 기록 삭제 | trainer | P1a | F-SOAP-04.6 | draft에만 노출 |
| `tr05.deleteDraft.confirm` | 이 기록과 필기를 삭제할까요? 되돌릴 수 없어요. | trainer | P1a | F-SOAP-04.6 |  |
| `tr05.legacy.readOnly` | 이전 형식 기록 · 읽기 전용 | trainer | P1a | §9.3 레거시 읽기 |  |
| `tr05.legacy.unparsedMetric` | 해석 불가 지표 · 원문 보존 | trainer | P0 | F-SOAP-06.2 |  |

#### 금지어 인라인 경고(TR-05·TR-06·맞춤 문구)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `copy.warning.prohibited` | 이 표현은 쓸 수 없어요 | trainer | P1a | F-SOAP-02.7, AC-SOAP-02.8 |  |
| `copy.warning.replaceWith` | 대신 쓸 표현 | trainer | P1a | 부록 C.1 | alternatives[] 표시 |
| `copy.warning.causal` | 인과로 읽힐 수 있어요. '함께 관찰됨', '연관 가능성'으로 바꿔 보세요 | trainer | P1a | 부록 C.2 | 경고만(비차단) |
| `copy.warning.abbreviation` | 회원에게는 약어를 풀어 써 주세요: {term} | trainer | P2 | F-SOAP-07.3 | 회원 요약에서는 공유 차단 |

#### TR-06 Share 미리보기(P2)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr06.title.soapNote` | 회원 요약 미리보기 | trainer | P2 | F-SOAP-05.3 |  |
| `tr06.title.bodyReport` | 체형·신체조성 리포트 미리보기 | trainer | P2 | F-SOAP-05.15 |  |
| `tr06.lockedPanel` | 내부 기록 · 회원에게 보이지 않아요 | trainer | P2 | §6.4.1 |  |
| `tr06.preview` | 회원 화면 미리보기 | trainer | P2 | TR-06 | MB-04·MB-02 렌더러 그대로 |
| `tr06.share` | 공유 | trainer | P2 | F-SOAP-05.7 |  |
| `tr06.share.confirm` | 회원에게 공유할까요? 공유하면 회원 앱에 바로 보여요. | trainer | P2 | F-SOAP-05.7 | 확인 1회 |
| `tr06.revoke` | 공유 해제 | trainer | P2 | F-SOAP-05.8 |  |
| `tr06.revoke.confirm` | 공유를 해제할까요? 회원 앱에서 바로 사라져요. | trainer | P2 | F-SOAP-05.8 |  |
| `tr06.reshare` | 수정해서 다시 공유(기존 요약은 해제돼요) | trainer | P2 | F-SOAP-05.9 |  |
| `tr06.disabled.draft` | 확정된 기록만 공유할 수 있어요 | trainer | P2 | AC-SOAP-05.3 |  |
| `tr06.disabled.pendingMember` | 앱에 연결된 회원만 공유할 수 있어요 | trainer | P2 | AC-SOAP-05.3 |  |
| `tr06.disabled.prohibited` | 쓸 수 없는 표현이 있어 공유할 수 없어요 | trainer | P2 | F-SOAP-05.6 |  |
| `tr06.addendumExists` | 원 기록에 추가 기록 있음 | trainer | P2 | F-SOAP-05.10 |  |
| `tr06.suggestedMetrics` | 추천 지표 {count}개 | trainer | P2 | F-SOAP-05.15 |  |
| `tr06.metricsRange` | 지표는 3~5개를 고르세요 | trainer | P2 | F-VIZ-06.2 |  |
| `tr06.photoToggle` | 전후 사진 넣기(얼굴 가림) | trainer | P2 | F-SOAP-05.15, F-ASM-01.10 |  |
| `tr06.photoToggle.noConsent` | 동의 ③이 없어 사진을 넣을 수 없어요 | trainer | P2 | AC-SOAP-05.11 |  |
| `tr06.shared` | 공유됨 · {date} | trainer | P2 | F-SOAP-05.7 |  |
| `tr06.revoked` | 해제됨 · {date} | trainer | P2 | F-SOAP-05.8 |  |

#### TR-07 체형 촬영(P1b)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr07.title` | 체형 촬영 | trainer | P1b | TR-07 |  |
| `tr07.gate.consentMissing` | 동의 ②③ 필요 · 현장 동의 열기 | trainer | P1b | F-ASM-01.5 | consent.needed.healthAndImaging와 같은 문장 |
| `tr07.station.select` | 촬영 스테이션 | trainer | P1b | F-ASM-01.2 |  |
| `tr07.station.none` | 촬영 스테이션을 먼저 등록하세요 | trainer | P1b | F-ASM-01.2 |  |
| `tr07.checklist.title` | 촬영 전 확인 | trainer | P1b | F-ASM-01.3 |  |
| `tr07.checklist.clothing` | 윤곽과 기준점이 보이는 복장 | trainer | P1b | F-ASM-01.3 |  |
| `tr07.checklist.barefoot` | 맨발 | trainer | P1b | F-ASM-01.3 |  |
| `tr07.checklist.markersPlaced` | 이주와 귀가 보이고 C7·ASIS에 마커를 붙였어요 | trainer | P1b | F-ASM-01.3 |  |
| `tr07.checklist.verbalConsent` | 분리된 공간이고 촬영 직전 회원에게 다시 확인했어요 | trainer | P1b | F-ASM-01.3 |  |
| `tr07.instruction.stand` | 편하게 서 주세요 | trainer | P1b | F-ASM-01.3 | 표준 자세 지시. 교정 지시 금지 |
| `tr07.level` | 좌우 {roll}° · 앞뒤 {pitch}° | trainer | P1b | F-ASM-01.4 |  |
| `tr07.level.outOfRange` | 기기를 수평으로 맞춰 주세요 | trainer | P1b | F-ASM-01.4, AC-ASM-01.2 |  |
| `tr07.person.none` | 사람이 보이지 않아요 | trainer | P1b | F-ASM-01.4 |  |
| `tr07.person.multiple` | 한 사람만 화면에 있어야 해요 | trainer | P1b | F-ASM-01.4 |  |
| `tr07.lighting.low` | 조명이 어두워요 | trainer | P1b | F-ASM-01.4 |  |
| `tr07.view.front` | 정면 | trainer | P1b | F-ASM-01.1 |  |
| `tr07.view.sagittalLeft` | 왼쪽 측면 | trainer | P1b | F-ASM-01.1 |  |
| `tr07.view.sagittalRight` | 오른쪽 측면 | trainer | P1b | F-ASM-01.1 |  |
| `tr07.view.sideFromBaseline` | 기준선과 같은 측면으로 찍어요 | trainer | P1b | F-ASM-01.1 |  |
| `tr07.shutter` | 촬영 | trainer | P1b | F-ASM-01 | 접근성 식별자 tr07.shutter |
| `tr07.retake` | 다시 찍기 | trainer | P1b | F-ASM-01.6 |  |

#### TR-08 랜드마크 보정(P1b)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr08.title` | 랜드마크 보정 | trainer | P1b | TR-08 |  |
| `tr08.origin.autoSuggested` | 자동 제안 | trainer | P1b | F-VIZ-02.2 | 속이 빈 점선 원 |
| `tr08.origin.autoConfirmed` | 확정 | trainer | P1b | F-VIZ-02.2 | 속이 찬 원 |
| `tr08.origin.manualConfirmed` | 수동 확정 | trainer | P1b | F-VIZ-02.2 | 속이 찬 원 + 핀 |
| `tr08.required` | 지정 필요 | trainer | P1b | F-VIZ-02.2, AC-VIZ-02.2 |  |
| `tr08.setHere` | 이 위치로 지정 | trainer | P1b | F-ASM-02.3 |  |
| `tr08.nudge.up` | 위로 1픽셀 | trainer | P1b | F-VIZ-02.8 |  |
| `tr08.nudge.down` | 아래로 1픽셀 | trainer | P1b | F-VIZ-02.8 |  |
| `tr08.nudge.left` | 왼쪽으로 1픽셀 | trainer | P1b | F-VIZ-02.8 |  |
| `tr08.nudge.right` | 오른쪽으로 1픽셀 | trainer | P1b | F-VIZ-02.8 |  |
| `tr08.undo` | 되돌리기 | trainer | P1b | F-ASM-02.4 |  |
| `tr08.engine` | 제안 엔진 {name} {version} | trainer | P1b | F-ASM-02.1 |  |
| `tr08.noSuggestion` | 자동 제안이 없어요. 랜드마크를 직접 지정하세요 | trainer | P1b | F-ASM-02.6 |  |
| `tr08.confirm` | 확정 | trainer | P1b | F-ASM-04.2 |  |
| `tr08.confirm.disabled` | 필수 랜드마크를 모두 지정해야 확정할 수 있어요 | trainer | P1b | AC-ASM-02.1 |  |

#### TR-09 체형 결과(P1b)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr09.title` | 체형 결과 | trainer | P1b | TR-09 |  |
| `tr09.col.metric` | 지표 | trainer | P1b | F-VIZ-01.2 |  |
| `tr09.col.value` | 값 | trainer | P1b | F-VIZ-01.2 |  |
| `tr09.col.side` | 측면 | trainer | P1b | F-VIZ-01.2 |  |
| `tr09.col.source` | 출처 | trainer | P1b | F-VIZ-01.2 |  |
| `tr09.col.tier` | 신뢰 등급 | trainer | P1b | F-VIZ-01.2 |  |
| `tr09.col.mdc` | MDC | trainer | P3 | F-VIZ-01.2 |  |
| `tr09.col.delta` | 비교 기준 대비 | trainer | P1b | F-VIZ-01.2 |  |
| `tr09.col.status` | 변화 상태 | trainer | P1b | F-VIZ-01.2 |  |
| `tr09.baseline` | 기준선 | trainer | P1b | F-ASM-04.4 |  |
| `tr09.setBaseline` | 기준선으로 지정 | trainer | P1b | F-ASM-04.4 |  |
| `tr09.newVersion` | 수정(새 버전) | trainer | P1b | F-ASM-04.3 |  |
| `tr09.pelvicToggle` | 골반 기울기 계산(참고, 마커 필요) | trainer | P1b | F-ASM-03.1 | 기본 꺼짐 |
| `tr09.deletePhoto` | 사진 한 장 삭제(회원 요청) | trainer | P1b | F-ASM-01.9 |  |
| `tr09.deletePhoto.confirm` | 사진을 지우면 사진 없는 새 버전이 만들어지고 지표 값은 그대로예요. | trainer | P1b | F-ASM-01.9 |  |
| `tr09.retest.tag` | 재검사 묶음에 추가 | trainer | P1b | F-ASM-05.1 |  |
| `tr09.retest.noDisadvantage` | 참여하지 않아도 불이익이 없어요 | trainer | P1b | F-ASM-05 |  |
| `tr09.makeReport` | 회원 리포트 만들기 | trainer | P2 | F-SOAP-05.15 |  |

#### TR-10 비교(P1b)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr10.title` | 비교 | trainer | P1b | TR-10 |  |
| `tr10.sideBySide` | 나란히 보기 | trainer | P1b | F-VIZ-02.4 |  |
| `tr10.overlay` | 겹쳐 보기 | trainer | P1b | F-VIZ-02.5 |  |
| `tr10.opacity` | 불투명도 | trainer | P1b | F-VIZ-02.5 |  |
| `tr10.alignmentNote` | 정렬은 보기용 | trainer | P1b | F-VIZ-02.5 |  |
| `tr10.trend` | 추이 | trainer | P1b | F-VIZ-03 |  |
| `tr10.compareTo` | 비교 기준 | trainer | P1b | §7.5 |  |
| `tr10.compareTo.baseline` | 기준선 | trainer | P1b | §7.5 |  |
| `tr10.compareTo.previous` | 직전 기록 | trainer | P1b | §7.5 |  |
| `tr10.compareTo.selected` | 선택 시점 | trainer | P1b | §7.5 |  |
| `tr10.retestGroup` | 재검사 묶음 | trainer | P1b | F-ASM-05 |  |
| `tr10.conditionBanner` | 판정 불가 · {reason} | trainer | P1b | F-VIZ-02.6 | Δ 숨김 |

#### TR-11 신체조성 입력(P1a)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr11.title` | 신체조성 입력 | trainer | P1a | TR-11 |  |
| `tr11.consentNeeded` | 건강정보 동의 필요 | trainer | P1a | AC-PRIV-01.1 | 저장 버튼 비활성 |
| `tr11.deviceModel` | 기기 모델 | trainer | P1a | F-BC-01.2 |  |
| `tr11.measuredAt` | 측정 일시 | trainer | P1a | F-BC-01.2 |  |
| `tr11.fasting` | 공복 여부 | trainer | P1a | F-BC-01.2 |  |
| `tr11.fasting.yes` | 공복 | trainer | P1a | F-BC-01.2 |  |
| `tr11.fasting.no` | 공복 아님 | trainer | P1a | F-BC-01.2 |  |
| `tr11.fasting.unknown` | 모름 | trainer | P1a | F-BC-01.2 | 보조 메뉴에만 |
| `tr11.fasting.required` | 공복 여부를 골라 주세요 | trainer | P1a | F-BC-01.2 |  |
| `tr11.timeOfDayBand` | 시간대 | trainer | P1a | F-BC-01.2 | 자동 |
| `tr11.height` | 키(트레이너 측정) | trainer | P1a | F-BC-01.3 | ② 이후 |
| `tr11.bmi.needsHeight` | 키를 입력하면 BMI가 계산돼요 | trainer | P1a | F-BC-01.3 |  |
| `tr11.atLeastOne` | 측정값을 하나 이상 입력하세요 | trainer | P1a | F-BC-01.1 |  |
| `tr11.range.generic` | {min}~{max}{unit} 사이로 입력하세요 | trainer | P1a | F-BC-03.2 | 범위는 metric-catalog range |
| `tr11.cross.fatMassOverWeight` | 체지방량이 체중보다 커요. 결과지를 다시 확인하세요 | trainer | P1a | F-BC-03.3 | 경고, 저장 허용 |
| `tr11.cross.muscleOverWeight` | 골격근량이 체중 이상이에요. 결과지를 다시 확인하세요 | trainer | P1a | F-BC-03.3 |  |
| `tr11.cross.fatPercentMismatch` | 체지방률과 체지방량·체중 비율이 크게 달라요. 결과지를 다시 확인하세요 | trainer | P1a | F-BC-03.3 |  |
| `tr11.saveAnyway` | 확인했어요, 저장하기 | trainer | P1a | F-BC-03.3 |  |
| `tr11.reportPhoto` | 결과지 사진 | trainer | P1a | F-BC-02.1 |  |
| `tr11.reportPhoto.compare` | 결과지와 입력값을 나란히 확인하세요 | trainer | P1a | F-BC-02.1 |  |
| `tr11.correct` | 정정 | trainer | P1a | F-BC-03.5 |  |
| `tr11.correct.reason` | 정정 사유 | trainer | P1a | F-BC-03.5 |  |
| `tr11.miniTrend` | 최근 추이 | trainer | P1a | TR-11 |  |

#### TR-12 둘레 입력(P1a)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr12.title` | 둘레 입력 | trainer | P1a | TR-12 |  |
| `tr12.addSite` | 부위 추가 | trainer | P1a | F-ASM-06.1 |  |
| `tr12.trial` | {n}회 | trainer | P1a | F-ASM-06.4 |  |
| `tr12.trial3Opened` | 두 값 차이가 1cm 이상이라 3회째를 재요 | trainer | P1a | F-ASM-06.4 |  |
| `tr12.average` | 평균 {value}cm | trainer | P1a | F-ASM-06.4 | 개별 값과 함께 |
| `tr12.sideRequired` | 왼쪽·오른쪽을 골라 주세요 | trainer | P1a | AC-ASM-06.1 |  |
| `tr12.landmarkNote` | 기준점 메모 | trainer | P1a | F-ASM-06.2 |  |
| `tr12.landmarkNote.required` | 이 부위는 기준점 메모가 필요해요 | trainer | P1a | AC-ASM-06.4 |  |
| `tr12.conditionsNote` | 측정 조건 메모(선택) | trainer | P1a | F-ASM-06.5 |  |
| `tr12.protocol.waistMidpoint` | 갈비뼈 아래 끝과 장골능 사이 중간, 숨을 내쉰 뒤 | trainer | P1a | F-ASM-06.2 | 가장 가는 곳·배꼽으로 대체 금지 |
| `tr12.protocol.hipMaximum` | 엉덩이의 가장 굵은 곳 | trainer | P1a | F-ASM-06.2 |  |
| `tr12.referenceTape` | 줄자 대조값(베타 연구용) | trainer | P2 | F-LIDAR-03.1 | 회원 비표시 |

#### TR-13 LiDAR 베타(P2)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr13.title` | LiDAR 관측 단면(베타) | trainer | P2 | TR-13 | '측정값' 금지 구역(PT-C23) |
| `tr13.import` | 결과 패키지 가져오기 | trainer | P2 | F-LIDAR-01 |  |
| `tr13.reject.synthetic` | 합성 데이터라 가져올 수 없어요 | trainer | P2 | AC-LIDAR-01.3 |  |
| `tr13.reject.unconfirmed` | 확정되지 않은 단면이 있어 가져올 수 없어요 | trainer | P2 | F-LIDAR-01.4 |  |
| `tr13.reject.noTakenAt` | 촬영 시각이 없어 가져올 수 없어요 | trainer | P2 | F-LIDAR-01.3 |  |
| `tr13.reject.unsupported` | 지원하지 않는 형식이나 알고리즘이에요 | trainer | P2 | §10.4.3 |  |
| `tr13.reject.pendingMember` | 앱에 연결된 회원만 가져올 수 있어요 | trainer | P2 | F-LINK-01.7 |  |
| `tr13.linkMember.needed` | 회원 연결 필요 | trainer | P2 | F-LIDAR-01.2 |  |
| `tr13.linkMember.confirm` | 이 스캔을 {name} 님 기록으로 연결할까요? | trainer | P2 | F-LINK-04 | 자동 추정 매칭 금지 |
| `tr13.mesh.deviceOnly` | 3D 원본은 촬영 기기에만 있습니다 | trainer | P2 | F-LIDAR-02.2 | PRD 원문 |
| `tr13.sideBySide` | 같은 부위 나란히 보기 | trainer | P2 | §6.3 |  |
| `tr13.openContour` | 닫히지 않은 윤곽 | trainer | P2 | §10.4.1 | 주황 표시 |

#### TR-14 현장 동의·대기 회원·초대 코드

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `tr14.register.title` | 회원 등록 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.register.displayName` | 표시명 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.register.sex` | 성별 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.register.sex.female` | 여성 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.register.sex.male` | 남성 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.register.sex.unspecified` | 밝히지 않음 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.register.birthYear` | 출생연도 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.register.age14Confirm` | 만 14세 이상임을 확인했습니다 | trainer | P1a | F-LINK-01.8 |  |
| `tr14.register.under14Blocked` | 만 14세 미만은 등록할 수 없어요. 법정대리인 동의 절차는 지원하지 않습니다. | trainer | P1a | F-LINK-01.8, AS-22 |  |
| `tr14.register.next` | 다음: 동의 받기 | trainer | P1a | F-LINK-01.1 |  |
| `tr14.consent.title` | 동의 받기 | trainer | P1a | F-PRIV-03 |  |
| `tr14.consent.handToMember` | 이 화면은 회원님이 직접 읽고 선택합니다 | shared | P1a | F-PRIV-03.1 | 회원에게 보이는 화면 |
| `tr14.consent.version` | 문서 버전 {version} | shared | P1a | F-PRIV-01.2 |  |
| `tr14.consent.purpose` | 목적 | shared | P1a | F-PRIV-01.2 |  |
| `tr14.consent.items` | 수집 항목 | shared | P1a | F-PRIV-01.2 |  |
| `tr14.consent.retention` | 보유기간 | shared | P1a | F-PRIV-01.2 |  |
| `tr14.consent.recipient` | 제공받는 자 | shared | P1a | F-PRIV-01.5 | ④만 |
| `tr14.consent.refusal` | 거부할 권리와 거부 시 불이익 | shared | P1a | F-PRIV-01.2 |  |
| `tr14.consent.grant` | 동의 | shared | P1a | F-PRIV-01.1 | 기본 체크 없음 |
| `tr14.consent.refuse` | 동의하지 않음 | shared | P1a | F-PRIV-01.1 |  |
| `tr14.consent.later` | 나중에 결정 | shared | P1a | F-PRIV-01.1 | ④⑤ |
| `tr14.consent.signature` | 서명 | shared | P1a | F-PRIV-03.2 |  |
| `tr14.consent.signatureClear` | 다시 쓰기 | shared | P1a | F-PRIV-03.2 |  |
| `tr14.consent.submit` | 선택한 내용으로 제출 | shared | P1a | F-PRIV-03.2 |  |
| `tr14.consent.returnToTrainer` | 트레이너에게 돌려주세요 | shared | P1a | F-PRIV-03.1 |  |
| `tr14.consent.documentMissing` | 게시된 동의 문서가 없어 진행할 수 없어요. 관리자에게 문의하세요. | trainer | P1a | F-PRIV-01.2 |  |
| `tr14.consent.revised` | 개정된 동의 문서가 있어요. 회원에게 다시 확인받아 주세요. | trainer | P1a | F-PRIV-01.3 |  |
| `tr14.consent.requiredRefusedPending` | 필수 동의를 받지 않아 회원 등록을 취소했어요 | trainer | P1a | F-LINK-01.5 |  |
| `tr14.consent.offlineCaptured` | 오프라인이라 동의를 이 기기에 보관했어요. 연결되면 가장 먼저 보내요. | trainer | P1a | F-PRIV-03.7 |  |
| `tr14.withdraw.title` | 동의 철회 | shared | P1a | F-PRIV-03.3 |  |
| `tr14.withdraw.submit` | 철회 기록하기 | shared | P1a | F-PRIV-03.3 |  |
| `tr14.withdraw.healthData.effect` | 철회하면 트레이너가 기존 건강 기록을 더 볼 수 없고 새 기록도 저장되지 않아요. 기록은 5영업일 안에 파기돼요. | shared | P1a | F-PRIV-02.3 | G-04 검토 문구로 교체 가능 |
| `tr14.withdraw.bodyImaging.effect` | 철회하면 사진 촬영과 업로드가 멈추고 사진과 사진 위 좌표는 5영업일 안에 파기돼요. 각도 값은 남아요. | shared | P1a | F-PRIV-02.3 |  |
| `tr14.withdraw.sharing.effect` | 담당이 바뀌어도 기록을 넘기지 않아요. 이미 넘긴 기록은 그대로예요. | shared | P1a | F-PRIV-02.3 |  |
| `tr14.withdraw.research.effect` | 이후 연구 자료에서 빠져요. 서비스 이용에는 영향이 없어요. | shared | P1a | F-PRIV-02.3 |  |
| `tr14.invite.issue` | 초대 코드 발급 | trainer | P2 | F-LINK-02.1 |  |
| `tr14.invite.code` | 초대 코드 | trainer | P2 | F-LINK-02.1 |  |
| `tr14.invite.shownOnce` | 이 코드는 지금 한 번만 보여요 | trainer | P2 | F-LINK-02.1 |  |
| `tr14.invite.expires` | {date}까지 유효 | trainer | P2 | F-LINK-02.2 |  |
| `tr14.invite.reissue` | 다시 발급(이전 코드는 쓸 수 없게 돼요) | trainer | P2 | F-LINK-02.3 |  |

#### TR-15 설정·로그인

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `login.title` | D-FET Trainer 로그인 | trainer | P0 | NFR-02 |  |
| `login.email` | 이메일 | trainer | P0 | NFR-02 |  |
| `login.password` | 비밀번호 | trainer | P0 | NFR-02 |  |
| `login.submit` | 로그인 | trainer | P0 | NFR-02 |  |
| `tr15.title` | 설정 | trainer | P0 | TR-15 |  |
| `tr15.account` | 계정 | trainer | P0 | TR-15 |  |
| `tr15.signOut` | 로그아웃 | trainer | P0 | NFR-08 |  |
| `tr15.signOut.unsyncedWarning` | 아직 서버에 올라가지 않은 기록이 {count}건 있어요. 로그아웃하면 이 기기에서 지워져요. | trainer | P0 | NFR-08 |  |
| `tr15.signOut.confirm` | 그래도 로그아웃 | trainer | P0 | NFR-08 |  |
| `tr15.queue.title` | 업로드 대기열 | trainer | P0 | TR-15 |  |
| `tr15.queue.retryAll` | 모두 다시 시도 | trainer | P0 | TR-15 |  |
| `tr15.queue.empty` | 보낼 기록이 없어요 | trainer | P0 | TR-15 |  |
| `tr15.station.title` | 촬영 스테이션 | trainer | P1b | F-ASM-01.2 |  |
| `tr15.quickPhrases` | 빠른 문구 | trainer | P1a | F-SOAP-07.1 |  |
| `tr15.version` | 앱 버전 {version} | trainer | P0 | TR-15 |  |
| `tr15.debug.flagOverride` | [DEBUG] 기능 플래그 로컬 설정 | trainer | P0 | ADR-010 | DEBUG 빌드에만 |

#### MB-01~MB-06 회원 앱(P2)

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `mb01.segment` | 체형·신체조성 | member | P2 | F-VIZ-06.7 | 리포트 탭 세그먼트 |
| `mb01.empty` | 아직 트레이너가 공유한 리포트가 없어요 | member | P2 | §8.4 | PRD 원문 |
| `mb01.latest` | 최근 리포트 | member | P2 | F-VIZ-06.2 |  |
| `mb01.previous` | 이전 리포트 | member | P2 | MB-01 |  |
| `mb01.consentHidden` | 동의 설정에 따라 일부 내용이 숨겨졌어요 · 동의 관리 | member | P2 | §8.4 | 탭하면 MB-06 |
| `mb01.loadFailed` | 불러오기 실패, 다시 시도 | member | P2 | V1-06 §10 |  |
| `mb02.trend` | 기록 추이 | member | P2 | F-VIZ-06.6 |  |
| `mb02.beforeAfter` | 전후 사진 | member | P2 | F-VIZ-06.5 |  |
| `mb02.faceMasked` | 얼굴을 가린 사진이에요 | member | P2 | F-ASM-01.10 |  |
| `mb02.trainerNote` | 트레이너가 남긴 말 | member | P2 | F-VIZ-06.2 |  |
| `mb02.comparedTo` | {date} 기록과 비교 | member | P2 | F-VIZ-06.2 |  |
| `mb02.ribbon.source` | 출처 {source} | member | P2 | F-VIZ-06.2 |  |
| `mb02.ribbon.policy` | 비교 기준 버전 {version} | member | P3 | F-VIZ-06.2 |  |
| `mb02.ribbon.policyNone` | 비교 기준 준비 중 | member | P2 | F-VIZ-06.2, §6.5.8 | 기존 '정책 미승인' 대신 회원 표현 |
| `mb03.row` | 트레이너 기록 | member | P2 | AC-IA-04, B.8 | 'SOAP 노트' 행 대체 |
| `mb03.title` | 트레이너 기록 | member | P2 | MB-03 |  |
| `mb03.filter.all` | 전체 | member | P2 | MB-03 |  |
| `mb03.filter.soapNote` | 세션 기록 요약 | member | P2 | B.8 |  |
| `mb03.filter.bodyReport` | 체형·신체조성 리포트 | member | P2 | B.5 |  |
| `mb03.empty` | 아직 트레이너가 공유한 기록이 없어요 | member | P2 | §8.4 |  |
| `mb03.sharedAt` | {date} 공유 | member | P2 | MB-03 |  |
| `mb03.trainer` | {name} 트레이너 | member | P2 | MB-03 |  |
| `mb04.title` | 세션 기록 요약 | member | P2 | B.8 |  |
| `mb04.section.subjective` | 말씀하신 불편과 오늘 상태 | member | P2 | B.8 |  |
| `mb04.section.objective` | 오늘 확인한 수치 | member | P2 | B.8 |  |
| `mb04.section.nextPlan` | 다음 계획 | member | P2 | B.8 |  |
| `mb04.section.homeExercise` | 집에서 할 운동 | member | P2 | B.8 |  |
| `mb04.revoked` | 트레이너가 공유를 해제했어요 | member | P2 | AC-VIZ-06.2 | PRD 원문 |
| `mb05.title` | 트레이너 연결 | member | P2 | MB-05 |  |
| `mb05.entryCard` | 트레이너에게 받은 초대 코드가 있나요? | member | P2 | MB-05 |  |
| `mb05.age14` | 만 14세 이상입니다 | member | P2 | F-LINK-01.8 | 체크 필수 |
| `mb05.under14` | 만 14세 미만은 연결할 수 없어요. 법정대리인 동의 절차는 지원하지 않아요. | member | P2 | F-LINK-01.8 |  |
| `mb05.code.placeholder` | 초대 코드 8자리 | member | P2 | F-LINK-02.2 |  |
| `mb05.submit` | 연결하기 | member | P2 | MB-05 |  |
| `mb05.success` | 트레이너와 연결됐어요. 동의 내용을 확인해 주세요. | member | P2 | MB-05 | 성공 시 MB-06 |
| `mb06.title` | 동의·내 정보 요청 | member | P2 | MB-06 |  |
| `mb06.consent.section` | 동의 항목 | member | P2 | MB-06 |  |
| `mb06.grant` | 동의하기 | member | P2 | F-PRIV-01.1 |  |
| `mb06.withdraw` | 철회하기 | member | P2 | F-PRIV-02 |  |
| `mb06.withdraw.confirm` | 철회할까요? 아래 내용을 확인해 주세요. | member | P2 | F-PRIV-02.3 | tr14.withdraw.*.effect 문장 함께 |
| `mb06.withdraw.required` | 필수 동의를 철회하려면 탈퇴를 진행해 주세요. | member | P2 | F-PRIV-02.3 |  |
| `mb06.history` | 동의 이력 | member | P2 | F-PRIV-02 |  |
| `mb06.history.channel.trainerDeviceInPerson` | 트레이너 기기에서 현장 동의 | member | P2 | F-PRIV-03 |  |
| `mb06.history.channel.memberApp` | 회원 앱 | member | P2 | F-PRIV-02 |  |
| `mb06.history.recordedBy` | 기록한 트레이너 {name} | member | P2 | F-PRIV-03.8 |  |
| `mb06.revised` | 동의 문서가 바뀌었어요. 다시 확인해 주세요. | member | P2 | F-PRIV-01.3 |  |
| `mb06.reconfirm.title` | 현장에서 한 동의를 확인해 주세요 | member | P2 | F-PRIV-03.8 |  |
| `mb06.reconfirm.body` | {date}에 {name} 트레이너의 기기에서 아래 항목에 동의했어요. {dueDate}까지 확인해 주세요. | member | P2 | F-PRIV-03.8 | 30일(제안값) |
| `mb06.reconfirm.ok` | 내용이 맞아요 | member | P2 | F-PRIV-03.8 |  |
| `mb06.reconfirm.change` | 바꿀래요 | member | P2 | F-PRIV-03.8 |  |
| `mb06.rights.title` | 내 정보 요청 | member | P2 | F-PRIV-07.1 |  |
| `mb06.rights.type.access` | 열람 | member | P2 | F-PRIV-07 |  |
| `mb06.rights.type.rectification` | 정정 | member | P2 | F-PRIV-07 |  |
| `mb06.rights.type.erasure` | 삭제 | member | P2 | F-PRIV-07 |  |
| `mb06.rights.type.suspension` | 처리정지 | member | P2 | F-PRIV-07 |  |
| `mb06.rights.submit` | 요청하기 | member | P2 | F-PRIV-07.1 |  |
| `mb06.rights.submitted` | 요청을 접수했어요. {date}까지 처리해 드려요. | member | P2 | F-PRIV-07.2 | 기한 10일은 법률 검토 대상 |
| `mb06.rights.status.received` | 접수됨 | shared | P1a | §9.2 rightsRequests |  |
| `mb06.rights.status.inProgress` | 처리 중 | shared | P1a | §9.2 |  |
| `mb06.rights.status.completed` | 완료 | shared | P1a | §9.2 |  |
| `mb06.rights.status.rejected` | 처리 불가 | shared | P1a | §9.2 |  |

#### AD-01~AD-07 관리자 웹

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `ad01.handover.withSharing` | 동의 ④가 있어 확정 기록을 새 담당에게 넘깁니다. | admin | P0 | F-LINK-05.4 |  |
| `ad01.handover.withoutSharing` | 동의 ④가 없어 새 담당은 빈 기록에서 시작합니다. | admin | P0 | F-LINK-05.4 |  |
| `ad02.title` | 대기 회원·초대 현황 | admin | P2 | AD-02 |  |
| `ad02.status.pending` | 대기 | admin | P2 | B.5 |  |
| `ad02.status.promoted` | 승격됨 | admin | P2 | B.5 |  |
| `ad02.status.cancelled` | 취소됨 | admin | P2 | B.5 |  |
| `ad02.status.expired` | 만료됨 | admin | P2 | B.5 |  |
| `ad02.code.active` | 사용 가능 | admin | P2 | F-LINK-02 | 원문 표시 없음 |
| `ad02.code.redeemed` | 사용됨 | admin | P2 | F-LINK-02 |  |
| `ad02.code.revoked` | 폐기됨 | admin | P2 | F-LINK-02.3 |  |
| `ad03.title` | 동의 문서 버전 | admin | P1a | AD-03 |  |
| `ad03.status.draft` | 초안 | admin | P1a | AD-03 |  |
| `ad03.status.published` | 게시됨 | admin | P1a | AD-03 |  |
| `ad03.status.retired` | 종료됨 | admin | P1a | AD-03 |  |
| `ad03.publish` | 게시 | admin | P1a | AD-03 |  |
| `ad03.field.purpose` | 목적 | admin | P1a | F-PRIV-01.2 |  |
| `ad03.field.items` | 항목 | admin | P1a | F-PRIV-01.2 |  |
| `ad03.field.retention` | 보유기간(구체적 기간) | admin | P1a | F-PRIV-01.2, Q-24 |  |
| `ad03.field.recipient` | 제공받는 자(④ 필수) | admin | P1a | F-PRIV-01.5 |  |
| `ad03.field.refusalNotice` | 거부권과 거부 시 불이익 | admin | P1a | F-PRIV-01.2 |  |
| `ad03.field.privacyPolicyVersion` | 처리방침 버전 | admin | P1a | F-PRIV-01.2, G-09 |  |
| `ad03.validation.missing` | {field} 항목이 비어 있어 게시할 수 없습니다. | admin | P1a | AC-PRIV-01.3 |  |
| `ad03.validation.recipient` | ④ 문서는 제공받는 자(같은 센터 후임 담당 트레이너)를 적어야 게시할 수 있습니다. | admin | P1a | AC-PRIV-01.4 |  |
| `ad03.immutable` | 게시된 버전은 고칠 수 없습니다. 새 버전을 만드세요. | admin | P1a | AD-03 |  |
| `ad04.title` | 변화 판정 정책(bodyChange) | admin | P3 | AD-04 | 관리자 화면은 공통 세트만(트레이너 용어 허용) |
| `ad04.approve` | 승인 | admin | P3 | AD-04 |  |
| `ad04.locked` | 승인된 정책은 고칠 수 없습니다. | admin | P3 | §7.6 |  |
| `ad04.activate` | 활성화 | admin | P3 | AD-04 |  |
| `ad04.rollback` | 이전 버전 다시 활성화 | admin | P3 | §7.6, §12.4 |  |
| `ad04.source.literature` | 문헌값, 자체 재검사 전 | admin | P3 | §6.5.0 |  |
| `ad04.source.inHouse` | 자체 재검사 | admin | P3 | §6.5.0 |  |
| `ad04.inHouseReportRequired` | 자체 재검사 정책은 연구 보고서 링크가 필요합니다. | admin | P3 | AD-04 |  |
| `ad05.title` | 지표 카탈로그 | admin | P1b | AD-05 |  |
| `ad05.noActiveMdc` | 활성 MDC 없음 | admin | P1b | AD-05 |  |
| `ad06.title` | 감사 로그·권리 요청 | admin | P2 | AD-06 |  |
| `ad06.rights.due` | 기한 {date} | admin | P1a | F-PRIV-07.4 |  |
| `ad06.rights.overdue` | 기한 초과 | admin | P1a | F-PRIV-07.4 |  |
| `ad06.monthlyReview` | 월간 검토 기록 | admin | P2 | F-PRIV-05.4 |  |
| `audit.healthRecordRead` | 건강 기록 열람 | admin | P1a | §9.7 |  |
| `audit.soapFinalized` | SOAP 확정 | admin | P1a | §9.7 |  |
| `audit.consentChanged` | 동의 변경 | admin | P1a | §9.7 |  |
| `audit.dataDeleted` | 데이터 파기 | admin | P1a | §9.7 |  |
| `audit.rightsRequestHandled` | 권리 요청 처리 | admin | P1a | §9.7 |  |
| `audit.summaryShared` | 요약 공유 | admin | P2 | §9.7 |  |
| `audit.summaryRevoked` | 요약 공유 해제 | admin | P2 | §9.7 |  |
| `audit.memberPromoted` | 대기 회원 승격 | admin | P2 | §9.7 |  |
| `audit.postureReverted` | 체형평가 확정 되돌림 | admin | P2 | §9.7 |  |
| `ad07.title` | 기능 플래그 | admin | P0 | AD-07 |  |
| `ad07.defaultOff` | 기본값: 꺼짐 | admin | P0 | §6.0.2 |  |
| `ad07.history` | 변경 이력 | admin | P0 | AD-07 |  |
| `ad07.confirm` | {flag} 값을 {state}(으)로 바꿀까요? | admin | P0 | AD-07 |  |
| `flag.soapV2` | SOAP 기록(v2) | admin | P0 | §6.0.2 |  |
| `flag.bodyComposition` | 측정 입력(신체조성·줄자 둘레) | admin | P0 | §6.0.2 |  |
| `flag.bodyAssessment` | 체형평가 | admin | P0 | §6.0.2 |  |
| `flag.memberShare` | 회원 공유·초대 코드 | admin | P0 | §6.0.2 |  |
| `flag.lidarBeta` | LiDAR 관측 단면(베타) | admin | P0 | §6.0.2 |  |

#### 알림·스토어·접근성 템플릿

| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |
|---|---|---|---|---|---|
| `notify.summaryShared` | 트레이너가 새 기록을 공유했어요 | notification | P2 | F-SOAP-05.12 | PRD 원문. 수치·지표명·부위 금지 |
| `notify.consentReconfirm` | 현장에서 한 동의를 확인해 주세요 | notification | P2 | F-PRIV-03.8 |  |
| `notify.consentRevised` | 동의 문서가 바뀌었어요. 다시 확인해 주세요. | notification | P2 | F-PRIV-01.3 |  |
| `store.purpose` | D-FET Coach는 트레이너가 회원의 일상적 건강관리와 운동 지도를 위해 세션 기록, 자세 사진 관찰, 신체조성 결과를 정리하고 시각화하는 기록 도구입니다. 질병의 진단·치료·경감·예방·재활을 목적으로 하지 않으며 의료기관의 진료를 대체하지 않습니다. 표시되는 수치에는 측정 조건에 따른 오차가 있습니다. | marketing | P0 | §3.1 | §3.1 원문. allowEntries AE-02. 변경 시 G-10 |
| `a11y.metric` | {metricName} {value}{unit}, {side}, 출처 {source}, {date}, 변화 {status} | trainer | P1a | §8.6 A-03, AC-C-01.3 | {status}=change.* 또는 '산정 준비 중' |
| `a11y.metric.withReason` | {metricName} {value}{unit}, {side}, 출처 {source}, {date}, 변화 {status}, 사유 {reason} | trainer | P1b | §8.6 A-03 |  |
| `a11y.beta` | 실측 대조 전 베타 참고값 | trainer | P2 | §8.6 A-03 |  |
| `mb.a11y.metric` | {metricName} {value}{unit}, {date}, 출처 {source} | member | P2 | §8.6 A-03 | 회원 변화 문장은 자격 있는 지표만 뒤에 덧붙임 |

---

## 5 분석 이벤트 카탈로그

### 5.1 원칙

| # | 원칙 | 근거 |
|---|---|---|
| A1 | 레지스트리([data/analytics_events.json](data/analytics_events.json) → `contracts/analytics-events.v1.json`)에 있는 이벤트·속성만 보낸다. 트레이너 앱은 생성된 `TrainerEvent` enum으로만 `track`한다 | §5.5, ADR-015 |
| A2 | 건강 수치, 판정 결과(changeStatus·reasonCode), 동의 유형, 이름·이메일·연락처, 자유 메모, 사진·필기·Storage 경로, 통증 부위, 회원·트레이너 uid, 초대 코드 원문을 보내지 않는다 | §5.5, NFR-10 |
| A3 | 시간은 `elapsed_band`로만 보낸다 | §5.5 |
| A4 | `session_id`는 회원과 연결되지 않는 UUIDv4이며 기기에 저장하지 않는다 | §5.5, M-02 |
| A5 | 회원 단위로 묶어야 하는 지표(M-03, M-05, M-06, M-07, M-09, M-10)는 이벤트가 아니라 서버 주간 집계(`opsMetrics`)로 계산한다 | §5.3 |
| A6 | 동의 변경은 이벤트로 보내지 않는다(`auditLogs.consentChanged`만) | §5.5 |
| A7 | G-09(처리방침·국외이전 공개) 전에는 네트워크로 보내지 않는다(DebugSink) | AS-19, G-09, ADR-015 |
| A8 | 이벤트명·속성 키·enum 값은 금지어 린트(공통 세트 + 식별자 규칙)를 통과한다 | §5.5, F-PRIV-06.3 |

### 5.2 명명·타입 규칙

- 이벤트명: `^[a-z][a-z0-9_]{2,39}$`, `<대상>_<동작 과거형>`(예 `soap_review_finalized`). `firebase_`·`google_`·`ga_` 접두 금지.
- 속성 키: `^[a-z][a-z0-9_]{1,39}$`. 이벤트당 10개 이하(Firebase 한도 25보다 좁게 잡음).
- 속성 타입은 다섯 가지뿐이다.

| 타입 | 값 | 예 |
|---|---|---|
| `enum` | 레지스트리의 `values` 중 하나 | `input_method = "text"` |
| `band` | `bands.<이름>.labels` 중 하나 | `elapsed_band = "7-10s"` |
| `bool` | true / false(Firebase에는 `1`/`0` 정수로 보냄) | `offline = true` |
| `int` | `min`~`max` 안의 개수 | `views_count = 2` |
| `pattern` | 정규식에 맞는 문자열. `session_id`, `engine_version` 두 개뿐 | `engine_version = "appleVision2D-17.4"` |

- 자유 문자열 타입은 없다. 새 속성이 필요하면 레지스트리 PR(`privacy-impact` 라벨)에서 타입을 위 다섯 중 하나로 정한다.

### 5.3 구간(band) 정의

`elapsed_band`(초, 구간은 [하한, 상한))

| 라벨 | 0-3s | 3-5s | 5-7s | 7-10s | 10-15s | 15-20s | 20-30s | 30-60s | 60-120s | 120-180s | 180-300s | 300-600s | 600s+ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 대표값(초) | 1.5 | 4 | 6 | 8.5 | 12.5 | 17.5 | 25 | 45 | 90 | 150 | 240 | 450 | 900 |

- 경계 10·30·60·120·180초는 M-01(10초), M-01 습관 붕괴 기준(30초), M-11(60초), M-04a(2분), M-04b·M-08(3분)과 맞췄다. 목표 판정이 구간 경계에서 갈린다.
- **ASM-12-04** 평균은 구간 대표값의 가중 평균으로 추정한다. 10초 미만 구간의 폭이 최대 3초라 평균 추정 오차는 ±1.5초 이내다. 600s+ 대표값 900초는 계산용 상한 가정이다.

개수 구간

| 이름 | 라벨 | 무엇의 개수 |
|---|---|---|
| `auto_ref_count_band` | 0, 1-2, 3-5, 6+ | 확정 시점 `objective.refs` 개수(P1b 카드와 같음) |
| `retake_count_band` | 0, 1, 2, 3+ | 한 촬영 흐름의 재촬영 합계 |
| `manual_adjust_count_band` | 0, 1-3, 4-6, 7+ | 보정 시작~확정 사이 랜드마크 이동·지정 조작 수 |
| `count_band` | 0, 1-3, 4-6, 7-9, 10-12, 13+ | 트레이너가 보고한 하루 세션 수(대표값 0, 2, 5, 8, 11, 14) |
| `rows_count_band` | 1, 2-3, 4-6, 7+ | 한 번 저장한 둘레 행 수 |

`band`를 계산하는 함수는 한 곳에만 둔다: 트레이너 `TrainerAnalytics.Bands`(생성된 경계 배열 사용), 회원 `lib/contracts/generated/analytics_bands.dart`. 경계 값에 정확히 걸리면 위 구간으로 간다(10.0초 → `10-15s`).

### 5.4 금지 속성

- 금지 키 목록(`forbiddenPropertyKeys`): `uid`, `user_id`, `member_uid`, `member_id`, `pending_member_id`, `trainer_id`, `trainer_uid`, `note_id`, `record_id`, `summary_id`, `assessment_id`, `scan_id`, `email`, `phone`, `name`, `display_name`, `birth_year`, `sex`, `invite_code`, `code`, `value`, `weight`, `weight_kg`, `height`, `body_fat`, `bmi`, `nrs`, `pain`, `pain_nrs`, `pain_regions`, `region`, `region_code`, `angle`, `cva`, `metric_code`, `metric_value`, `delta`, `mdc`, `side`, `change_status`, `reason_code`, `policy_version`, `judgement`, `consent_type`, `consent`, `consent_types`, `note`, `memo`, `quick_note`, `text`, `reason`, `reason_text`, `comment`, `message`, `body`, `title`, `chief_complaint`, `path`, `ink_path`, `photo_path`, `storage_path`, `url`, `file`, `file_name`, `device_serial`, `idfa`, `idfv`.
- 금지 패턴(`forbiddenKeyPatterns`): 키가 `(^|_)(uid|email|phone|name|path|url|memo|text|value|nrs|pain|region|consent|code)$`로 끝나면 금지. `(^|_)id$`는 `session_id`만 예외. `(status|reason)$`로 끝나면 금지(`reason_category`는 접미가 달라 허용).
- 값 규칙: 숫자 속성은 레지스트리에 `min`·`max`가 있는 개수만 허용한다. enum 값에 metricCode·regionCode·consentType·changeStatus·reasonCode 어휘를 쓰지 않는다.
- 크래시·콘솔 로그에도 같은 금지 항목을 적용한다(NFR-10). `os.Logger`는 이벤트명·enum 값만 `.public`, 나머지는 `.private(mask: .hash)`다(ADR-015).

### 5.5 이벤트 요약

| 이벤트 | 앱 | 단계 | 속성 | 지표 | 스토리 |
|---|---|---|---|---|---|
| `trainer_live_saved` | 트레이너 | P1a | session_id, input_method, elapsed_band, offline, end_relation | M-01, M-01b, M-02, M-G5 | DF-126, DF-116 |
| `trainer_session_ended` | 트레이너 | P1a | session_id, source, saved_before_end | M-02 | DF-126, DF-116 |
| `daily_session_count_reported` | 트레이너 | P1a | count_band | M-02 보조 | DF-125 |
| `soap_review_finalized` | 트레이너 | P1a | elapsed_band, auto_ref_count_band, queued | M-11, M-G5 | DF-122, DF-217 |
| `soap_addendum_created` | 트레이너 | P1a | reason_category | 보조 | DF-123 |
| `bodycomp_record_saved` | 트레이너 | P1a | source, has_report_photo, elapsed_band | 보조, M-G5 | DF-127, DF-128 |
| `circumference_saved`(제안) | 트레이너 | P1a | rows_count_band, elapsed_band | M-G5 | DF-129 |
| `onboarding_consent_completed` | 트레이너 | P1a | elapsed_band, channel | M-08 | DF-110 |
| `save_failure_shown` | 트레이너 | P0 골격 / P1a | entity_type, retry_result | M-G3 | DF-015, DF-018, DF-107 |
| `posture_capture_started` | 트레이너 | P1b | session_id | M-04a | DF-204 |
| `posture_capture_done` | 트레이너 | P1b | session_id, views_count, retake_count_band, elapsed_band | M-04a, M-G5 | DF-204 |
| `posture_landmarks_confirmed` | 트레이너 | P1b | manual_adjust_count_band, engine_version, elapsed_band | M-04b, M-G5 | DF-208, DF-209 |
| `change_status_rendered` | 두 앱 | P1b / P2 | surface | 노출 빈도 | DF-210, DF-215, DF-316 |
| `member_summary_shared` | 트레이너 | P2 | source_type, elapsed_band | 보조, M-G5 | DF-311, DF-313 |
| `member_summary_revoked` | 트레이너 | P2 | source_type | 보조 | DF-310, DF-311 |
| `invite_code_redeemed` | 회원 | P2 | result | 보조 | DF-306 |

PRD §5.5 초안 대비 바뀐 점은 네 가지이고 모두 지표 계산을 위해서다: `trainer_live_saved.end_relation`, `trainer_session_ended.saved_before_end`(M-02, ASM-12-02), `bodycomp_record_saved.elapsed_band`·`member_summary_shared.elapsed_band`와 새 이벤트 `circumference_saved`(M-G5, ASM-12-08), `trainer_live_saved.input_method`의 `none` 값(ASM-12-05).

### 5.6 이벤트 상세

#### `trainer_live_saved`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | Live 세션(session_id)에서 '기록 완료'(tr04.recordComplete)를 처음 탭하고 해당 draft의 localSaved가 확인된 직후 1회. 같은 session_id의 두 번째 이후 탭은 보내지 않는다 |
| 지표 | M-01, M-01b, M-02, M-G5 |
| 스토리 | DF-126, DF-116 |
| PRD | §5.5, F-SOAP-01.12, AC-SOAP-01.10 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `session_id` | pattern | `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` | 예 | TR-04 진입(또는 촬영 흐름 시작) 때 새로 만든 UUIDv4. 회원·노트 ID와 연결하지 않고 저장하지 않는다(메모리 보관, 앱 종료 시 폐기) |
| `input_method` | enum | text \| ink \| nrs \| mixed \| none | 예 | text=한 줄 입력만, ink=필기만, nrs=NRS만, mixed=둘 이상, none=빈 기록(ASM-12-05) |
| `elapsed_band` | band | `elapsed_band` | 예 | TR-04 화면 표시(onAppear) → localSaved 확인 |
| `offline` | bool | true \| false | 예 | 탭 시점 네트워크 불가 여부 |
| `end_relation` | enum | notEnded \| within30s \| after30s | 예 | 세션 종료 이벤트 대비 시점. notEnded=종료 전 저장(ASM-12-02) |

#### `trainer_session_ended`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | Live 세션이 끝난 첫 시점 1회: '세션 종료' 탭(endTap), TR-04 화면을 벗어남(leftLive), 다른 회원 Live 시작(nextMember) 중 먼저 일어난 것. 앱 백그라운드 전환은 종료로 보지 않는다(ASM-12-02) |
| 지표 | M-02 |
| 스토리 | DF-126, DF-116 |
| PRD | §5.3 M-02, §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `session_id` | pattern | `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` | 예 | TR-04 진입(또는 촬영 흐름 시작) 때 새로 만든 UUIDv4. 회원·노트 ID와 연결하지 않고 저장하지 않는다(메모리 보관, 앱 종료 시 폐기) |
| `source` | enum | endTap \| leftLive \| nextMember | 예 |  |
| `saved_before_end` | bool | true \| false | 예 | 종료 시점까지 trainer_live_saved를 보냈는지 |

#### `daily_session_count_reported`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | TR-01 '보고'(tr01.sessionCount.submit) 탭. 기기 현지 날짜당 1회(다시 보고하면 마지막 값만 전송하고 이전 전송은 취소할 수 없으므로 UI에서 하루 1회로 막는다) |
| 지표 | M-02(보조 분모), M-G5(보조) |
| 스토리 | DF-125 |
| PRD | §5.3 M-02, TR-01 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `count_band` | band | `count_band` | 예 |  |

#### `soap_review_finalized`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | Review '확정' 성공(온라인 즉시 확정 또는 오프라인 '확정 대기' 로컬 잠금) 직후 1회. 서버 거부로 잠금이 풀렸다가 다시 확정하면 다시 1회 |
| 지표 | M-11, M-G5 |
| 스토리 | DF-122, DF-217 |
| PRD | §5.5, §6.4.4 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `elapsed_band` | band | `elapsed_band` | 예 | 그 노트의 Review 첫 진입 → 확정 탭(P1a 카드 ASM-P1a-40과 같음) |
| `auto_ref_count_band` | band | `auto_ref_count_band` | 예 | P1a는 항상 '0' |
| `queued` | bool | true \| false | 예 | 오프라인 확정 대기 여부 |

#### `soap_addendum_created`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | addendum 로컬 저장 성공 직후 |
| 지표 | 보조 |
| 스토리 | DF-123 |
| PRD | §5.5, F-SOAP-04.4 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `reason_category` | enum | trainerCorrection \| subjectRectificationRequest | 예 | V1-06 AddendumReason. 사유 원문은 보내지 않는다 |

#### `posture_capture_started`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1b |
| 보내는 시점 | TR-07 게이트(동의 ②③, 스테이션, 체크리스트 제외) 통과 후 카메라 미리보기가 처음 표시될 때 |
| 지표 | M-04a |
| 스토리 | DF-204 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `session_id` | pattern | `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` | 예 | 촬영 흐름마다 새 UUIDv4 |

#### `posture_capture_done`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1b |
| 보내는 시점 | 정면과 측면 사진이 모두 로컬 저장된 순간 1회 |
| 지표 | M-04a, M-G5 |
| 스토리 | DF-204 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `session_id` | pattern | `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` | 예 | TR-04 진입(또는 촬영 흐름 시작) 때 새로 만든 UUIDv4. 회원·노트 ID와 연결하지 않고 저장하지 않는다(메모리 보관, 앱 종료 시 폐기) |
| `views_count` | int | 2~3 | 예 |  |
| `retake_count_band` | band | `retake_count_band` | 예 |  |
| `elapsed_band` | band | `elapsed_band` | 예 | posture_capture_started 시점 → 두 장 저장 |

#### `posture_landmarks_confirmed`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1b |
| 보내는 시점 | 체형평가 confirmed가 로컬에 저장된 직후 1회 |
| 지표 | M-04b, M-G5 |
| 스토리 | DF-208, DF-209 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `manual_adjust_count_band` | band | `manual_adjust_count_band` | 예 |  |
| `engine_version` | pattern | `^appleVision2D-[0-9]{2}(\.[0-9]{1,2}){0,2}$` | 예 | landmarkEngine.name-OS 버전(예 appleVision2D-17.4). 개인 식별 정보 아님 |
| `elapsed_band` | band | `elapsed_band` | 예 | TR-08 보정 시작 → confirmed 저장 |

#### `bodycomp_record_saved`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | 신체조성 기록(정정 새 기록 포함) localSaved 직후 1회 |
| 지표 | 보조, M-G5 |
| 스토리 | DF-127, DF-128 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `source` | enum | manualEntry | 예 | v1 고정. V2에서 inbodyApi는 서버 수집이라 이 이벤트를 쓰지 않는다 |
| `has_report_photo` | bool | true \| false | 예 |  |
| `elapsed_band` | band | `elapsed_band` | 아니요 | TR-11 시트 표시 → 저장. M-G5용 추가 속성(ASM-12-08) |

#### `circumference_saved` (제안)

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | TR-12 저장 성공(localSaved) 직후 1회 |
| 지표 | M-G5 |
| 스토리 | DF-129 |
| PRD | §5.4 M-G5 |
| 제안 사유 | §5.5 초안에는 없다. M-G5가 TR-12 시간을 요구해 추가(ASM-12-08) |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `rows_count_band` | band | `rows_count_band` | 예 |  |
| `elapsed_band` | band | `elapsed_band` | 예 | TR-12 시트 표시 → 저장 |

#### `change_status_rendered`

| 항목 | 값 |
|---|---|
| 앱·단계 | both · P1b |
| 보내는 시점 | 변화 상태 칸(배지·'산정 준비 중'·판정 불가)을 가진 화면이 나타날 때 화면당 1회. 판정 결과·지표는 보내지 않는다 |
| 지표 | 노출 빈도 |
| 스토리 | DF-210, DF-215, DF-316 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `surface` | enum | trainer \| member | 예 |  |

#### `member_summary_shared`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P2 |
| 보내는 시점 | createMemberSummary 성공 응답 뒤 1회(V1-06 §11.1) |
| 지표 | 보조, M-G5 |
| 스토리 | DF-311, DF-313 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `source_type` | enum | soapNote \| bodyReport | 예 |  |
| `elapsed_band` | band | `elapsed_band` | 아니요 | TR-06 표시 → 공유 성공(ASM-12-08) |

#### `member_summary_revoked`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P2 |
| 보내는 시점 | revokeMemberSummary 성공 응답 뒤 1회 |
| 지표 | 보조 |
| 스토리 | DF-310, DF-311 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `source_type` | enum | soapNote \| bodyReport | 예 |  |

#### `onboarding_consent_completed`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P1a |
| 보내는 시점 | TR-14에서 ①②③ 서명 캡처가 끝나 recordConsent 성공 또는 오프라인 로컬 캡처 저장 직후 1회. 동의 유형·선택 결과는 보내지 않는다 |
| 지표 | M-08 |
| 스토리 | DF-110 |
| PRD | §5.5, M-08 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `elapsed_band` | band | `elapsed_band` | 예 | 대기 회원: 등록 화면 표시 → 서명 캡처. 가입 회원: TR-14 동의 단계 표시 → 서명 캡처 |
| `channel` | enum | trainerDeviceInPerson \| memberApp | 예 | v1 트레이너 앱은 trainerDeviceInPerson만. memberApp은 P2 MB-06 예약 |

#### `invite_code_redeemed`

| 항목 | 값 |
|---|---|
| 앱·단계 | member · P2 |
| 보내는 시점 | redeemInviteCode 응답 뒤 1회 |
| 지표 | 보조(M-10은 서버 집계) |
| 스토리 | DF-306 |
| PRD | §5.5 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `result` | enum | success \| expired \| reused \| invalid | 예 | 서버가 실패 사유를 invite.invalidOrExpired 하나로 묶으므로 회원 앱은 success·invalid만 보낸다. expired·reused는 예약(V1-06 §11.1) |

#### `save_failure_shown`

| 항목 | 값 |
|---|---|
| 앱·단계 | trainer · P0 |
| 보내는 시점 | 항목이 syncFailed로 바뀌어 배지가 처음 화면에 그려질 때 retry_result=notYet으로 1회. 사용자가 재시도한 뒤 결과가 나오면 succeeded 또는 failedAgain으로 1회 더 |
| 지표 | M-G3 |
| 스토리 | DF-015, DF-018, DF-107 |
| PRD | §5.5, M-G3, C-05 |

| 속성 | 타입 | 값 | 필수 | 설명 |
|---|---|---|---|---|
| `entity_type` | enum | soapNote \| inkRevision \| addendum \| consentCapture \| pendingMember \| bodyComposition \| reportPhoto \| circumference \| postureAssessment \| posturePhoto \| bodyScan | 예 |  |
| `retry_result` | enum | notYet \| succeeded \| failedAgain | 예 |  |

### 5.7 Live 세션 추적 규칙(M-01·M-02)

`FeatureSOAP` 안의 `LiveSessionTracker`(메모리 전용, `@MainActor final class`)가 다음 상태를 가진다. 값은 기기에 저장하지 않는다. 앱이 강제 종료되면 추적도 사라지고 이벤트는 보내지 않는다(누락은 과소 집계로 남고 보간하지 않는다).

```swift
/// TR-04 · V1-12 §5.7
struct LiveSessionTrace {
    let sessionId: UUID            // TR-04 onAppear마다 새로 만든다. noteId·memberKey와 연결하지 않는다
    let shownAt: ContinuousClock.Instant
    var savedAt: ContinuousClock.Instant?   // 첫 '기록 완료' → localSaved 확인 시점
    var endedAt: ContinuousClock.Instant?
    var inputKinds: Set<InputKind> = []    // .text, .ink, .nrs (이번 세션에서 실제로 입력된 것)
}
```

| 사건 | 처리 | 보내는 이벤트 |
|---|---|---|
| TR-04 표시 | 새 `sessionId`, `shownAt` 기록 | 없음 |
| 한 줄 입력·필기 획·NRS 선택 | `inputKinds`에 추가 | 없음 |
| 첫 '기록 완료' 탭 → `localSaved` 확인 | `savedAt` 기록. `end_relation` = `endedAt == nil` ? `notEnded` : (`savedAt − endedAt ≤ 30초` ? `within30s` : `after30s`) | `trainer_live_saved{session_id, input_method, elapsed_band(shownAt→savedAt), offline, end_relation}` |
| 두 번째 이후 '기록 완료' | 무시 | 없음 |
| 세션 종료(먼저 일어난 하나): '세션 종료' 탭, TR-04 화면 닫힘, 다른 회원 Live 시작 | `endedAt` 기록 | `trainer_session_ended{session_id, source, saved_before_end = (savedAt != nil)}` |
| 앱 백그라운드 전환, 화면 잠금 | 종료로 보지 않는다 | 없음 |

- `input_method`: `inputKinds`가 비었으면 `none`, 하나면 그 값(`text`·`ink`·`nrs`), 둘 이상이면 `mixed`.
- **ASM-12-02** PRD §5.3 M-02는 '세션 종료 후 30초 안에 기록 완료가 있는 세션 비율'이다. 종료 **전**에 이미 기록 완료가 있었던 세션도 충족으로 본다(v0 KPI '세션 후 30초 내 기록'의 취지). 이 해석과 '백그라운드는 종료 아님'은 Q-DEV-12-01에서 소유자가 확인한다.
- 이어쓰기(F-SOAP-01.8)로 같은 노트를 다시 열어도 새 `sessionId`다(세션 = 화면 체류 단위).

### 5.8 전송기 구현 계약

트레이너 앱(`TrainerAnalytics` 타깃, DF-126). 생성기(`tool/contracts/generate.mjs`, DF-004·DF-033)가 레지스트리에서 아래 코드를 만든다.

```swift
// TrainerContracts/Generated/AnalyticsEvents.swift (생성물, 손으로 고치지 않음)
public enum ElapsedBand: String, Sendable { case s0_3 = "0-3s", s3_5 = "3-5s", /* … */ s600Plus = "600s+" }
public enum LiveInputMethod: String, Sendable { case text, ink, nrs, mixed, none }
public enum LiveEndRelation: String, Sendable { case notEnded, within30s, after30s }

public enum TrainerEvent: Sendable {
    case trainerLiveSaved(sessionId: UUID, inputMethod: LiveInputMethod, elapsed: ElapsedBand, offline: Bool, endRelation: LiveEndRelation)
    case trainerSessionEnded(sessionId: UUID, source: SessionEndSource, savedBeforeEnd: Bool)
    case soapReviewFinalized(elapsed: ElapsedBand, autoRefCount: AutoRefCountBand, queued: Bool)
    // … 레지스트리의 trainer·both 이벤트 전부
    public var name: String { get }                      // "trainer_live_saved"
    public var parameters: [String: AnalyticsValue] { get }   // 레지스트리 키만. 값은 String·Int·Bool
}
```

```swift
// TrainerAnalytics
public protocol AnalyticsSink: Sendable { func send(name: String, parameters: [String: AnalyticsValue]) }
public struct DebugSink: AnalyticsSink { /* os.Logger(subsystem: "kr.co.dfet.trainer", category: "analytics") */ }
public final class AnalyticsClient {
    public init(sink: AnalyticsSink)
    public func track(_ event: TrainerEvent)            // 검증 실패(레지스트리 밖 키)는 DEBUG에서 assertionFailure, 릴리스에서 버림
    public static func elapsedBand(from: ContinuousClock.Instant, to: ContinuousClock.Instant) -> ElapsedBand
}
```

- `FirebaseAnalyticsSink`는 `FirebaseData` 타깃에 둔다(Feature에 Firebase import 0건, NFR-03). App 타깃이 G-09 이후 `AnalyticsClient(sink: FirebaseAnalyticsSink())`로 조립한다.
- 회원 앱(P2): `lib/services/analytics_client.dart`에 `abstract class AnalyticsSink`, `DebugAnalyticsSink`(`debugPrint`, `kReleaseMode`에서 무동작), 생성된 `lib/contracts/generated/analytics_events.dart`의 `MemberEvent`를 둔다. 실제 SDK 연결(firebase_analytics 추가)은 Q-DEV-12-02 결정 뒤다. 결정 전에는 `invite_code_redeemed`와 `change_status_rendered(member)`가 수집되지 않는다.

### 5.9 SDK 설정과 G-09 전환

| 항목 | 설정 | 근거 |
|---|---|---|
| 전송 시작 | G-09 증빙(DF-909)이 기록된 뒤 App 조립 코드에서 `FirebaseAnalyticsSink`로 교체하는 PR을 병합(릴리스 노트 명시) | AS-19, ADR-015 |
| `FIREBASE_ANALYTICS_COLLECTION_ENABLED`(Info.plist) | `false`. 앱 시작 시 코드에서 `Analytics.setAnalyticsCollectionEnabled(true)`(G-09 뒤 빌드만) | ASM-12-10 |
| `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS` | `false` | NFR-11 |
| `GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED` | `false` | NFR-10 |
| `FirebaseAutomaticScreenReportingEnabled` | `false`(화면 이름 자동 수집 끔. 레지스트리 밖 이벤트 방지) | A1 |
| AdSupport·AppTrackingTransparency | 링크하지 않음 | NFR-11 |
| `setUserID`, `setUserProperty` | 호출 금지(static-guards grep 0건 규칙에 추가, ASM-12-10) | A2 |
| GA4 속성 설정(콘솔, 소유자) | 데이터 보존 2개월, Google 신호 끔, BigQuery 내보내기 끔, 맞춤 측정기준 등록(§6.4) | A5 |

- **ASM-12-10** 위 SDK 설정값은 개인정보 최소화를 위한 제안이다. G-09 처리방침 문구(국외이전 항목)와 함께 소유자가 확정한다.

### 5.10 테스트

| ID | 종류 | 파일(신규) | 확인 |
|---|---|---|---|
| TC-12-AN-01 | 단위(macOS `swift test`) | `TrainerCore/Tests/TrainerAnalyticsTests/RegistryConformanceTests.swift` | 모든 `TrainerEvent` case의 `parameters` 키가 레지스트리 속성과 정확히 같고 금지 키·금지 패턴이 0건 |
| TC-12-AN-02 | 단위 | 같은 폴더 `ElapsedBandTests.swift` | 경계값(2.999→0-3s, 3.0→3-5s, 9.999→7-10s, 10.0→10-15s, 30.0→30-60s, 600.0→600s+) |
| TC-12-AN-03 | 단위 | `LiveSessionTrackerTests.swift`(FeatureSOAPTests) | §5.7 표의 여섯 사건 순서 조합: 저장 후 종료, 종료 후 20초 저장(within30s), 종료 후 45초 저장(after30s), 저장 없이 종료(saved_before_end=false), 두 번 저장(이벤트 1회), 백그라운드(종료 없음) |
| TC-12-AN-04 | 단위 | `DebugSinkCaptureTests.swift` | DebugSink 로그 문자열에 UUID 외 식별자·숫자 건강 값이 없음(정규식 검사) |
| TC-12-AN-05 | contracts CI | `tool/contracts/test/analytics-registry.test.mjs` | 레지스트리 스키마, 이벤트명·키 정규식, 금지 키·패턴, 식별자 금지어(§7.6), 속성 수 ≤ 10 |
| TC-12-AN-06 | static-guards | `tool/lint/static-guards.sh` | `setUserID`·`setUserProperty`·`Analytics.logEvent(` 직접 호출이 `FirebaseAnalyticsSink.swift` 밖에 0건 |
| TC-12-AN-07 | flutter test(P2) | `test/services/analytics_client_test.dart` | `MemberEvent` 키 = 레지스트리, 릴리스 모드 DebugSink 무동작 |

---

## 6 성공·가드레일 지표 계산 매핑

### 6.1 지표별 계산

| 지표 | 목표(PRD) | 데이터 출처 | 계산 | 단계·스토리 |
|---|---|---|---|---|
| M-01 Live 기록 시간(텍스트) | 평균 10초 미만(확정) | `trainer_live_saved` where `input_method = text` | 평균 = Σ(대표값 × 건수) / 건수(§5.3). 함께 보고: 30초 초과 비율 = (`30-60s` 이상 구간 건수) / 건수. 판정 보조로 **상한 평균**(각 구간 상한값 사용, 600s+는 900)도 적는다 | P1a · DF-126, DF-140(실기기 대조) |
| M-01b 필기 포함 | 보고만 | `trainer_live_saved` where `input_method ∈ {ink, mixed}` | M-01과 같은 식. `nrs`·`none`은 따로 건수만 보고 | P1a · DF-126 |
| M-02 세션 후 30초 내 기록 | 가설 80% 이상 | `trainer_session_ended`, `trainer_live_saved` | (session_ended 중 `saved_before_end=true` 건수 + live_saved 중 `end_relation=within30s` 건수) / session_ended 건수. 보조 분모: `daily_session_count_reported` 대표값 합(기록되지 않은 세션 추정) | P1a · DF-126, DF-125 |
| M-03 당일 Review 확정률 | 가설 70% 이상 | `opsMetrics/{isoWeek}.m03` | V1-06 §6.10 식(sessionDate 당일 24:00 KST까지 finalized) | P1a · DF-137 |
| M-04a 체형 촬영 소요 | 가설 2분 이하(중앙값) | `posture_capture_done.elapsed_band` | 중앙값이 속한 구간을 보고. 목표 충족 = 중앙 구간의 상한 ≤ 120초 | P1b · DF-204, DF-223 |
| M-04b 랜드마크 확정 소요 | 가설 3분 이하(중앙값) | `posture_landmarks_confirmed.elapsed_band` | 같은 방식, 상한 ≤ 180초 | P1b · DF-208, DF-209, DF-223 |
| M-05 재평가 판정 가능 비율 | 가설 80% 이상 | `opsMetrics.m05` | V1-06 §6.10(정책·문헌 사유 제외, 조건 사유별 건수) | P1b · DF-224 |
| M-06 공유 요약 열람률 | 가설 베타 50%, 출시 60% | `opsMetrics.m06` ← `memberSummaries.firstViewedAt` | `firstViewedAt − sharedAt ≤ 7일` 비율. `markSummaryViewed` 승인(V1-06 ASM-06-04, Q-DEV-04) 전에는 `null` | P2 · DF-315·DF-137 확장 |
| M-07 주간 케어 루프 완료율 | 가설 P2 50%, P3 60% | `opsMetrics.m07` | V1-06 §6.10. ③(공유 후 열람)은 M-06과 같은 필드에 의존 | P2 · DF-137 확장 |
| M-08 현장 온보딩 시간 | 가설 3분 이하(중앙값) | `onboarding_consent_completed.elapsed_band` where `channel = trainerDeviceInPerson` | 중앙 구간 상한 ≤ 180초 | P1a · DF-110 |
| M-09 공유율 | 가설 50% 이상 | `opsMetrics.m09` | V1-06 §6.10 | P2 · DF-137 확장 |
| M-10 초대 코드 사용률 | 가설 70% 이상 | `opsMetrics.m10` | V1-06 §6.10(`redeemedAt` 7일 안) | P2 · DF-137 확장 |
| M-11 Review 소요 시간 | 가설 60초 이하(중앙값) | `soap_review_finalized.elapsed_band` | 중앙 구간 상한 ≤ 60초. `queued=true`도 포함 | P1a · DF-122 |
| M-G1 금지어 노출 | 0건 | ① copy-lint(block) 결과 ② 서버 거부 로그 ③ G-10 검수 ④ 월간 요약 표본 검토 | 노출 = main에 병합된 위반(①이 필수 체크라 원칙상 0) + ③·④에서 발견된 외부 노출 건수. ② `dfet.summary.prohibitedTermsRejected`(구조화 로그, 건수만)는 **막아낸** 건수라 노출에 넣지 않고 선행 지표로 보고 | P0~ · DF-010, DF-040, DF-309, DF-921 |
| M-G2 동의 없는 민감정보 저장 | 0건 | ① 규칙 테스트 R-14·R-15·R-01 등(CI) ② 월간 대조 점검 | ②: 원 기록 컬렉션의 `createdAt`마다 그 시점 `consentRecords`로 재구성한 ②(사진은 ③) 상태가 granted였는지 대조한 위반 건수. 읽기 전용 스크립트 제안 `functions/scripts/ops/consentConsistencyReport.js`(수량만 출력, 소유자 실행) | P1a~ · ASM-12-15, Q-DEV-12-03 |
| M-G3 알리지 않은 저장 실패 | 0건 | ① `trainer-app-emulator-it` 오류 주입 ② 실기기 V1-T09 ③ `save_failure_shown` | ①: 주입한 실패마다 `syncFailed` 배지 표시 + `save_failure_shown(notYet)` 1건 = 100%(아니면 실패 건수). ②: 비행기 모드·규칙 거부 시나리오 수동 확인. ③은 현장 발생 건수와 재시도 결과 분포 보고용 | P0~P1a · DF-015, DF-107, DF-140 |
| M-G4 규칙 테스트 통과율 | 100% | `functions-and-rules` CI | 통과 케이스 / 전체 R-01~R-31·S-01~S-08 | P0~ · DF-022, DF-035, DF-023 |
| M-G5 트레이너 일 기록 총시간 | 중앙값 15분/일 이하(가설) | 흐름별 elapsed_band 이벤트 + GA4 일별 활성 사용자(트레이너 기기) | 날짜 d마다 T(d) = Σ_흐름 Σ_이벤트 대표값 / 활성 트레이너 기기 수(d). 흐름 = Live(`trainer_live_saved`), Review(`soap_review_finalized`), TR-07(`posture_capture_done`), TR-08(`posture_landmarks_confirmed`), TR-11(`bodycomp_record_saved`), TR-12(`circumference_saved`), TR-06(`member_summary_shared`). 보고값 = 기간 중 T(d)의 중앙값 | P1b 종료 검토 · ASM-12-08 |
| v0 보조: 일일 활성 트레이너, 트레이너당 일 기록 수 | 보고 | GA4 활성 사용자, `trainer_live_saved` 일별 건수 | 기록 수 / 활성 트레이너 기기 | P1a~ |

- 트레이너 수가 1~3명인 P1a~P1b에는 표본이 작다. 단계 종료 검토(V1-T06)에는 **건수 n을 반드시 함께 적고**, n < 30이면 '참고값'으로 표시한다.
- 트레이너 식별은 GA4 앱 인스턴스(기기) 단위다. uid를 쓰지 않으므로 한 트레이너가 기기 두 대를 쓰면 두 명으로 센다.

### 6.2 중앙값 구간 계산 절차

1. GA4 탐색 분석에서 이벤트를 `elapsed_band` 맞춤 측정기준으로 나눠 구간별 건수를 뽑는다(기간, 앱 버전 필터).
2. 구간을 경계 순서로 정렬해 누적 건수가 전체의 50%를 처음 넘는 구간을 중앙 구간으로 한다.
3. 보고 형식: `중앙 구간 7-10s (n=42, 상한 10초)`. 목표 비교는 상한값으로 한다(보수적).
4. G-09 전(DebugSink)에는 DF-140·DF-223 실기기 기록(V1-T09)의 스톱워치·Instruments 값으로 대신한다.

### 6.3 보고 주기

| 주기 | 내용 | 기록 위치 |
|---|---|---|
| 매주 금요일 리뷰 | M-01, M-02, M-11(P1a~), M-04a/b(P1b~), opsMetrics 최신 주 | 스프린트 리뷰(V1-T05) 지표 스냅샷 |
| 월 1회 | M-G1 ④ 요약 표본 검토, M-G2 ② 대조 점검, 감사 로그 검토(F-PRIV-05.4) | AD-06 월간 검토 기록(P2~), P1a는 내보내기 스크립트 결과 |
| 단계 종료 | 전체 표 + n + 판정(목표 충족/미달/표본 부족) | V1-T06, DF-926~DF-938 |

### 6.4 GA4 콘솔 설정(소유자, G-09 뒤)

- 이벤트 범위 맞춤 측정기준으로 등록(21개, 한도 50): `auto_ref_count_band`, `channel`, `count_band`, `elapsed_band`, `end_relation`, `engine_version`, `entity_type`, `has_report_photo`, `input_method`, `manual_adjust_count_band`, `offline`, `queued`, `reason_category`, `result`, `retake_count_band`, `retry_result`, `rows_count_band`, `saved_before_end`, `source`, `source_type`, `surface`. `views_count`는 맞춤 측정항목(정수)으로 등록한다.
- `session_id`는 등록하지 않는다(고유값이 많아 재식별 단서가 되고 콘솔 집계에 필요 없다). M-02는 §6.1처럼 클라이언트 파생 속성으로 계산한다.

---

## 7 금지어 린트 설계

### 7.1 규칙 세트와 적용 대상(부록 C.3)

| 세트 | 내용 | 적용 대상 | severity | 도입 |
|---|---|---|---|---|
| `common` | 부록 C.1 전체 + §7.7·F-ASM-03.7 진단성 라벨(C1-01~C1-23, C1-11b) | 모든 사용자 노출 문자열, 문구 덱 전체, 이벤트명·audit action | block(C1-23은 LiDAR 한정) | P0(DF-010 보고 → DF-040 차단) |
| `member` | '개선', '악화', '판정', '의미 있는'(C3-M-01~04) | 회원 앱 문자열, `member`·`shared`·`notification`·`marketing`·`consentDraft` 덱 항목, 회원 요약 본문·템플릿, 알림 | block | P0(앱), P2(요약), P3(G-10) |
| `memberAbbreviation` | 라틴 대문자 2개 이상 토큰 중 허용 목록(BMI, D-FET) 밖 | `member` 세트와 같은 대상 | block | P0(앱), P2(요약) |
| `trainer` | 추가 규칙 없음. 회원 세트 용어·changeStatus 라벨 허용 | 트레이너 앱 문자열, Runner 내장 트레이너, Flutter 폴백 트레이너 | — | P0 |
| `identifier` | 영문 금지 어간(`diagnos`, `therap`, `treat`, `rehab`, `cure`, `prescri`, `patient`, `disease`, `clinic`, `medical`, `abnormal`, `posture_score`, `body_score`) | 분석 이벤트명·속성 키·enum 값, `auditLogs.action`, audit `metadataKeys` | block | P0(DF-033) |
| `causalPatterns` | 부록 C.2 인과·효과 단정·누락 채움 패턴(C2-01~C2-04) | `common`이 적용되는 모든 곳 | **warn**(보고만) | P0 |

- **ASM-12-03** 부록 C.1은 '원인은, ~때문에'를 전체 금지로 두지만, F-PRIV-06.2는 요약 서버 검사에서 '인과 표현 패턴은 경고만'으로 정했다. '때문에·로 인해'는 일상 문장(예 '네트워크 문제로 인해')에서 오탐이 많아 린트도 **경고**로 둔다. 정확한 구 '원인은'만 C1-12로 **차단**한다. 인과 문장은 G-10 수동 검수와 TR-06 미리보기 경고(`copy.warning.causal`)로 잡는다.
- **ASM-12-17** `ios/Runner/AppDelegate.swift`는 회원 앱 번들 안에 있지만 화면은 트레이너용이라 `trainer` 세트를 적용한다(회원 세트를 적용하면 '의미 있는' 등 트레이너 라벨 때문에 오탐이 난다). Runner의 나머지 파일은 `member` 세트다.

### 7.2 규칙 표(`ruleSets.common`, `ruleSets.member`)

용어는 [data/forbidden_terms.json](data/forbidden_terms.json)이 정본이다. 대체 표현은 TR-05·TR-06 인라인 경고의 `copy.warning.replaceWith` 아래에 그대로 보인다.

| ID | 부록 C 행 | 용어(terms/regex) | 대체 표현 | 일치 옵션 | 한정 |
|---|---|---|---|---|---|
| C1-01 | 진단, 진단명, 진단/이슈 | 진단명, 진단/이슈, 진단 | 운동 관점 평가, 관찰, 관찰 요약 | — | — |
| C1-02 | 정밀 진단, 진단 보조 | 정밀 진단, 진단 보조 | 근거 수준 그대로 서술 | — | — |
| C1-03 | 치료, 치료계획 | 치료계획, 치료 | 운동 지도, 관리, 운동 계획 | — | — |
| C1-04 | 치료됨, 완치 | 치료됨, 완치 | 이번 기록에서 ~가 관찰됐어요, 정한 목표 수치에 도달했어요 | — | — |
| C1-05 | 교정(체형교정·자세교정) | 체형 교정, 자세 교정, 교정 | 자세 정렬 관찰, 자세 균형 운동, 정렬 변화 기록 | — | — |
| C1-06 | 재활, 재활 보조, 재활 트레이닝, 회복 | 재활 보조, 재활 트레이닝, 재활, 회복 | 운동 지도, 컨디션 관리 운동 | — | — |
| C1-07 | 재활훈련 | 재활훈련 | 운동 프로그램 | — | — |
| C1-08 | 처방, 운동 처방 | 운동 처방, 처방 | 운동 계획, 추천 운동(트레이너 확정) | — | — |
| C1-09 | 환자, ○○ 환자용, 수술 후 관리, 디스크·측만 대상 | 환자, 수술 후 관리 | 회원 | — | — |
| C1-10 | 진료, 진료용 | 진료용, 진료 | 세션, 상담 | — | — |
| C1-11 | 질환명(거북목증후군, 척추측만증, 디스크), KCD 코드 | 거북목증후군, 거북목, 척추측만증, 측만, 디스크, KCD | 머리 전방 자세 관찰, 어깨 높이 차이 관찰, 불편 부위 | — | — |
| C1-11b | §7.7·F-ASM-03.7 진단성 라벨 | 골반 틀어짐, 골반 불균형 | 골반 좌우 높이 차이 관찰 | — | — |
| C1-12 | 원인은, ~때문에(인과 단정) | 원인은 | 함께 관찰됨, 연관 가능성 | — | — |
| C1-13 | 거북목 개선, 자세 개선, 체형 개선, 불균형 해소 | 거북목 개선, 자세 개선, 체형 개선, 불균형 해소 | 머리·목 정렬 각도(CVA) 기록, 운동 기록과 변화 관찰 | — | — |
| C1-14 | 통증 완화, 통증 감소, 통증 개선 | 통증 완화, 통증 감소, 통증 개선 | 통증 점수 기록, 말씀하신 불편 기록 | — | — |
| C1-15 | 예방 | 예방 | 건강관리, 운동 기록 | — | — |
| C1-16 | 도수(도수치료, 도수교정, 도수근력검사) | 도수치료, 도수교정, 도수근력검사, 도수 | 근력 등급(MMT 0–5) | wordStart, except 빈도수·온도수·정도수 | — |
| C1-17 | 신체교정운동 | 신체교정운동, 신체 교정 운동 | 자세 균형 운동, 가동성 운동 | — | — |
| C1-18 | 근골격 기능 등급 | 근골격 기능 등급 | 지표별 값과 변화 관찰 | — | — |
| C1-19 | 체형 점수, 체형 등급, 자세 종합 점수 | 체형 점수, 체형 등급, 자세 종합 점수 | 지표별 값·출처·변화 관찰 | — | — |
| C1-20 | 반드시 개선, 효과가 입증됨, 임상적으로 검증, 과학적으로 입증 | 반드시 개선, 효과가 입증, 임상적으로 검증, 과학적으로 입증 | 측정 오차보다 큰 변화가 관찰됐어요, 근거 수준 그대로 서술 | — | — |
| C1-21 | 의료기관 수준, 정확도 N%, 3D 정밀 체형분석 | 의료기관 수준, 3D 정밀 체형분석, /정확도\s*:?\s*\d+(\.\d+)?\s*%/ | 문헌값은 출처와 '자체 재검사 전'을 함께 적기 | — | — |
| C1-22 | 정상, 비정상(규준 없는 지표) | 비정상, 정상 범위, 정상 | 규준 없음, 값만 표시 | wordStart, except 정상적·비정상적 | — |
| C1-23 | 측정값(LiDAR 베타 값 한정) | 측정값, 측정 값 | 관측 단면 · 실측 대조 전 · 베타/참고 | — | 키 tr13., lidar. / 경로 FeatureLidarBeta |
| C3-M-01 | 회원 노출: '개선' | 개선 | 부록 B.8 문장(mb.change.*) | — | — |
| C3-M-02 | 회원 노출: '악화' | 악화 | 부록 B.8 문장(mb.change.*) | — | — |
| C3-M-03 | 회원 노출: '판정' | 판정 | '비교', '측정 오차 범위' 등 부록 B.8 표현 | — | — |
| C3-M-04 | 회원 노출: '의미 있는' + 방향 표현 | 의미 있는, 의미있게, 의미 있게 | 측정 오차보다 큰 변화 | — | — |

- 모든 행의 `scopes`는 부록 C.1 적용 범위(ui, summary, notification, marketing, event, input)를 그대로 옮겼다. C1-23만 ui·summary·export이며 `onlyIn`(키 접두 `tr13.`·`lidar.`, 경로 `FeatureLidarBeta/**`, `BodyPath*/**`)으로 한정한다. 다른 화면의 '측정값'은 허용한다(PT-V13·PT-V14).
- '회복'(C1-06)은 부록 C.1 그대로 전체 적용한다. 회원 앱 영양·수면 코칭 문장('글리코겐 회복', '회복의 핵심')도 걸린다(§7.12). **ASM-12-13** 예외를 두지 않고 DF-041에서 '컨디션 관리'·'휴식' 등으로 바꾼다.
- 각 행의 `clinicalModeNote`는 부록 C.1 '임상 모드(v2)' 열이다. v1 린트는 읽지 않는다(§3.7 확장 지점).

### 7.3 정규화와 일치 규칙

세 구현(Node 린트 `tool/lint/prohibited-terms.mjs`, Swift `TrainerContracts/Generated/ProhibitedTerms.swift` + `TrainerDomain/CopyGuard.swift`, Functions `functions/src/summaries/prohibitedTerms.js`)은 아래 규칙을 똑같이 구현하고 같은 테스트 벡터(§7.11)를 통과해야 한다. 계산 절차의 의사코드·복잡도 논의는 [V1-09](09_ALGORITHMS_SPEC.md)가 같은 규칙을 참조한다. 두 문서가 다르면 데이터 형식은 이 문서, 알고리즘 설명은 V1-09를 따르고 차이는 문서 변경 절차로 고친다.

1. **정규화**: NFC → 제로폭 문자(U+200B, U+200C, U+200D, U+FEFF) 삭제 → U+3000·U+00A0을 공백으로 → 연속 공백을 하나로. 라틴 문자는 대소문자를 구분하지 않는다.
2. **용어 → 정규식**: 용어를 공백으로 나눈 조각을 `[\s·\-_/]*`로 잇는다. 그래서 '체형 교정'은 '체형교정', '체형·교정', '체형 - 교정'과 모두 일치한다. 공백 없는 용어는 그대로 부분 문자열로 찾는다(조사 '을·는'이 붙어도 잡힌다).
3. **wordStart 경계**(C1-16 도수, C1-22 정상): 일치 바로 앞 글자가 한글·영숫자면 버린다(`(?<![가-힣A-Za-z0-9])`). '빈도수', '일정상'을 제외한다.
4. **except**: 규칙의 except 문자열(예 '정상적', '빈도수') 안에 완전히 들어가는 일치는 버린다.
5. **정확 일치 허용**: 정규화한 **문자열 전체**가 active allowEntries의 `exactString`과 같으면 그 문자열의 규칙 일치를 모두 버린다(AE-01, AE-02). 부분 일치는 허용하지 않는다.
6. **줄 허용**: allowEntries에 `lineRegex`가 있으면 그 경로의 그 줄에서 나온 해당 규칙 일치만 버린다(AE-03).
7. **결과**: `{file, line, col, key?, ruleSet, ruleId, term, alternatives, severity}`. 같은 위치의 겹친 일치(예 '거북목 개선'의 C1-11·C1-13)는 둘 다 보고한다.

```js
// tool/lint/lib/match.mjs (DF-010, Node 22 내장 모듈만)
export function normalize(s) {
  return s.normalize('NFC').replace(/[​-‍﻿]/g, '')
          .replace(/[　 ]/g, ' ').replace(/\s+/g, ' ');
}
export function termRegex(term, boundary) {
  const body = term.split(' ').map(escapeRe).join('[\\s·\\-_/]*');
  return new RegExp((boundary === 'wordStart' ? '(?<![가-힣A-Za-z0-9])' : '') + body, 'giu');
}
export function matchRule(rule, text, { key } = {}) {
  if (rule.onlyIn && !(key && rule.onlyIn.keyPrefixes.some(p => key.startsWith(p)))) return [];
  const excepts = (rule.match.except ?? []).flatMap(ex => [...text.matchAll(new RegExp(escapeRe(ex), 'g'))]
                   .map(m => [m.index, m.index + ex.length]));
  const hits = [];
  for (const t of rule.terms ?? []) for (const m of text.matchAll(termRegex(t, rule.match.boundary))) {
    const [a, b] = [m.index, m.index + m[0].length];
    if (!excepts.some(([s, e]) => s <= a && b <= e)) hits.push({ start: a, end: b, term: t });
  }
  for (const rx of rule.regex ?? []) for (const m of text.matchAll(new RegExp(rx, 'gu')))
    hits.push({ start: m.index, end: m.index + m[0].length, term: m[0] });
  return hits;
}
```

- 코드 파일의 `onlyIn`은 키가 없으므로 `onlyIn.globs`로 판단한다. xcstrings와 문구 덱은 키로 판단한다.

### 7.4 인과 패턴(경고)

| ID | 부록 C.2 행 | 정규식 | 허용 표현 예 |
|---|---|---|---|
| C2-01 | A 때문에 B / A로 인해 B | `(때문에\|(으)?로 인해\|덕분에)` | 같은 기간에 ~와 ~ 변화가 함께 관찰됐어요 |
| C2-02 | A하면 B가 좋아진다 | `하면\s?\S{0,12}\s?(좋아\|나아\|맞춰\|바로잡)` | 이 운동과 ~ 변화는 연관 가능성이 있어요. 인과를 뜻하지 않아요 |
| C2-03 | 효과 단정 | `효과(가\|를)?\s?(있어\|봤\|나타났\|입증)` | 측정 오차보다 큰 변화가 나타났어요(자격 있는 지표만) |
| C2-04 | 누락을 채운 서술 | `(했\|였)을\s?거(예요\|에요\|야)` | 지난달 기록이 없어 비교할 수 없어요 |

- 'MDC 미만 변화를 변화로 서술'(부록 C.2 5행)은 정규식으로 잡을 수 없다. 회원 변화 문장을 `mb.change.*` 키로만 만들게 하는 구조(자유 문장 금지)와 G-10으로 막는다.

### 7.5 약어 규칙

| 대상 | 허용 목록 | 동작 |
|---|---|---|
| 회원 노출 문자열·회원 요약 | BMI, D-FET | 목록 밖 토큰(라틴 대문자 2개 이상, 예 CVA, NRS, SOAP, MMT, LiDAR)이 있으면 **차단**(`ABBR`). TR-06 공유 버튼 비활성 + `copy.warning.abbreviation`(F-SOAP-07.3, AC-SOAP-07.3) |
| 트레이너 원 기록 텍스트(A·P·memberNote·맞춤 문구) | SOAP, ROM, AROM, PROM, MMT, NRS, MDC(부록 B.8) | 앱 안에서 **경고**만(`copy.warning.abbreviation`). 저장은 막지 않음 |
| 트레이너 앱 UI 문자열 | 검사하지 않음 | CVA, BMI, C7, ASIS, LiDAR 등 해부·기기 명칭을 라벨로 쓴다 |

- **ASM-12-12** 회원 허용 목록에 BMI와 D-FET만 둔다. BMI는 부록 A 지표명 '체질량지수(BMI)'로 회원에게 보이고, D-FET은 서비스명이다. 목록을 늘리려면 부록 B.8 개정이 필요하다.

### 7.6 식별자 규칙(이벤트·audit)

- 대상: `contracts/analytics-events.v1.json`의 이벤트명·속성 키·enum 값, `contracts/audit-actions.v1.json`의 `action`·`metadataKeys`, `admin_web/lib/audit.ts` 호출부의 action 리터럴(`writeAudit(actor, '<action>'`).
- 규칙: 소문자로 바꾼 식별자에 금지 어간(§7.1 identifier)이 들어 있으면 차단. 한국어 식별자는 없어야 하며 있으면 `common` 세트도 적용한다.
- **레거시 식별자 허용 목록**(`identifier.allowIdentifiers`): 기존 장·혈액 파이프라인의 감사 action `clinical.ingestion.submit`(dfet:admin_web/app/api/ingestions/[kind]/route.ts:49), `clinical.config.publish`(dfet:admin_web/app/api/clinical/config/route.ts:140-145). D4에 따라 이름을 바꾸지 않는다. 새 action에는 `clinic` 어간을 쓰지 않는다.
- Firestore 필드명·코드 식별자(예 레거시 `diagnosis`, `legacy.diagnosisRaw`, `clinicalApi`, `functions/src/clinical/`)는 린트 대상이 아니다. 린트는 **문자열 리터럴과 카탈로그 값**만 읽는다(§7.8). 그래서 `"diagnosis"` 같은 영문 키 리터럴은 걸리지 않고, v2 쓰기 경로의 `diagnosis` 금지는 규칙(R-04)과 static-guards가 맡는다.

### 7.7 경로 매핑·제외·허용 목록

경로별 규칙 세트(`pathRuleSets`, 위에서부터 첫 일치 하나)

| glob | 세트 | 비고 |
|---|---|---|
| `trainer_app/**` | common, trainer | Localizable.xcstrings(ko) + Swift 리터럴 |
| `ios/Runner/AppDelegate.swift` | common, trainer | ASM-12-17 |
| `ios/Runner/**` | common, member | |
| `lib/screens/trainer/**`, `lib/widgets/shells/trainer_shell.dart` | common, trainer | Flutter 폴백 트레이너 |
| `lib/admin/**` | common | 레거시 Flutter 관리자 |
| `lib/**` | common, member, memberAbbreviation | 회원 앱 기본 |
| `admin_web/**` | common | |
| `functions/src/summaries/templates/**` | common, member, memberAbbreviation | P2 |
| `functions/src/**` | common | 서버는 한국어 사용자 문장을 보내지 않는다(V1-06 §3.5). 걸리는 한국어 리터럴은 로그 문자열뿐이어야 한다 |
| `contracts/metric-catalog.v1.json`, `contracts/vocab.v1.json` | common, trainer | `nameKo`·`labelsKo` 값 |
| `contracts/analytics-events.v1.json`, `contracts/audit-actions.v1.json`, `docs/v1/data/analytics_events.json` | common, identifier | |
| `docs/v1/data/copy_ko.json` | 항목별 `audience` → §4.2 | |

검사하지 않는 경로

| 구분 | glob | 사유 |
|---|---|---|
| allowPaths | `docs/**`(단 `docs/v1/data/copy_ko.json`, `docs/v1/data/analytics_events.json`은 검사), `**/*.md`, `schemas/**` | 부록 C·법령 인용 문서(C.3 예외) |
| allowPaths | `contracts/prohibited-terms.v1.json`, `contracts/fixtures/**`, `contracts/vectors/**`, `**/test/**`, `**/Tests/**`, `**/*Tests.swift`, `functions/test/**`, `tool/lint/test/**` | 규칙 원본·테스트 픽스처(C.3 예외) |
| allowPaths | `functions/scripts/migrations/**` | MIG-03~06 레거시 라벨 매핑 입력(읽기 전용) |
| excludePaths | `trainer_ios/**` | 동결된 이식 원본, 출시되지 않음, DF-142에서 삭제 |
| excludePaths | `**/Generated/**`, `lib/contracts/generated/**`, `functions/src/shared/generated/**`, `admin_web/lib/generated/**` | 생성물(원본 contracts를 검사) |
| excludePaths | `build/**`, `**/Pods/**`, `**/node_modules/**` | 산출물·서드파티 |

허용 목록(`allowEntries`, `active=true`만 적용)

| ID | kind | 대상 | 규칙 | 상태 | 사유 |
|---|---|---|---|---|---|
| AE-01 | regulatoryDisclaimer | 정확 문자열 '운동 지도와 건강관리 기록용이며 진단이나 치료를 위한 정보가 아닙니다.' | C1-01, C1-03 | active, PRD 승인 | §3.1 짧은 고지 |
| AE-02 | regulatoryDisclaimer | 정확 문자열 `store.purpose` 전문 | C1-01, C1-03, C1-06, C1-10, C1-15 | active, PRD 승인 | §3.1 기본 문구 |
| AE-03 | legacyStoredValue | '체형 교정', `onboarding_screen.dart`·`profile_setup_screen.dart`의 `case "체형 교정":` 줄만 | C1-05 | active, 제안 | 저장된 목표 값 호환(dfet:lib/screens/onboarding_screen.dart:544, dfet:lib/screens/profile_setup_screen.dart:358). 목록 문구(:40, :38)는 DF-029에서 교체 |
| AE-04 | legacyStoredValue | '진단/이슈', 이관 스크립트·레거시 픽스처 | C1-01 | active, 제안 | allowPaths와 중복이지만 의도를 명시 |
| AE-10 | existingDisclaimerCandidate | '이 점수는 건강관리 참고용이며 의료 진단이 아닙니다.' | C1-01 | **inactive**, 소유자 검토 대기 | dfet:lib/screens/microbiome/microbiome_screen.dart:115 |
| AE-11 | existingDisclaimerCandidate | '본 리포트는 의료 진단이 아니며, 생활관리 참고용으로만 활용하십시오.' | C1-01 | inactive | dfet:lib/screens/microbiome/microbiome_screen.dart:209 |
| AE-12 | existingDisclaimerCandidate | '생활 기록과 지표 변화의 연관 가능성을 보여주는 비진단 정보입니다.' | C1-01 | inactive | dfet:lib/screens/dashboard/today_signal_screen.dart:151 |
| AE-13 | approvedNormContextCandidate | '정상범위', 혈액 화면·RangeBar·reference-ranges 관리자 화면 | C1-22 | inactive | 승인 참고범위가 있는 혈액 지표. C.1 '정상'은 '규준 없는 지표' 한정 |

- **ASM-12-14** AE-10~AE-13은 기본 비활성이다. DF-010 카드가 정한 대로 '§3.1 고지 외의 실제 UI 문장은 예외 목록에 넣지 않는다'를 지키고, 소유자가 DF-041에서 문장을 바꿀지(권장: §3.1 짧은 고지로 통일, '정상범위' → '참고 범위') 허용할지 정한다(Q-DEV-12-05). 활성화하려면 `regulatory` 라벨 PR에서 `active: true`, `reviewedBy`, `reviewStatus: "approvedByOwner"`를 적는다.

### 7.8 추출기(언어별)

| 파일 | 추출 대상 | 제외 |
|---|---|---|
| `*.swift` | `"…"`, `"""…"""` 리터럴. 보간 `\(…)` 바깥 텍스트만 | `//`, `/* */`, `///` 주석, `#if DEBUG` 블록은 검사하되 severity를 warn으로 낮춤 |
| `*.xcstrings` | `strings.<key>.localizations.ko.stringUnit.value`(키를 함께 전달) | `comment` |
| `*.dart` | `'…'`, `"…"`, `'''…'''`, `"""…"""`. `${…}` 바깥만. `r'…'` 원시 문자열 포함 | `//`, `/* */`, `///` 주석, `import`·`part` 경로 |
| `*.ts`, `*.tsx` | 따옴표·백틱 리터럴(`${…}` 바깥), JSX 텍스트 노드(`>텍스트<`), JSX 속성 문자열 | 주석, `import` 경로 |
| `*.js`(functions) | 따옴표·백틱 리터럴 | 주석, `require` 경로 |
| `contracts/*.json` | `nameKo`, `labelsKo`, `titleKo` 값 / 레지스트리 식별자(§7.6) | 그 밖의 키 |
| `docs/v1/data/copy_ko.json` | `strings.<key>.ko`(키와 audience 전달) | `note`, `screens`, `prdRefs` |

- 한 줄에 한글이 없는 리터럴은 `identifier` 대상이 아닌 한 건너뛴다(성능).
- 출력: 사람이 읽는 `path:line:col [ruleSet/ruleId] term → 대체어` 목록과 `--json` 보고서. `--summary <file>`은 GitHub Step Summary용 표를 쓴다.

### 7.9 CI 배치와 모드 전환

| CI job | 실행 | 모드 | 필수 체크 | 스토리 |
|---|---|---|---|---|
| `copy-lint`(신규, ubuntu, Node 22) | `node tool/lint/prohibited-terms.mjs --mode=${COPY_LINT_MODE} --summary "$GITHUB_STEP_SUMMARY"` 전체 저장소. `--check-deck`으로 xcstrings·`*_copy.dart`와 copy_ko.json 불일치를 경고 | S01~S04 `report`, DF-040 병합부터 `block`(저장소 변수 `COPY_LINT_MODE=block`) | DF-040부터 필수 | DF-010, DF-040 |
| `contracts`(신규) | 금지어 JSON 스키마 검증, `contracts/vectors/prohibited-terms.v1.json`을 Node 구현으로 실행, analytics·audit 레지스트리 식별자 검사(TC-12-AN-05) | block | 예 | DF-010, DF-033 |
| `trainer-app`(macos-15) | `swift test`에서 `CopyGuardTests`가 같은 벡터를 Swift 구현으로 실행, `RegistryConformanceTests` | block | 예 | DF-120(인라인 경고), DF-126 |
| `functions-and-rules` | `test/unit/summaries/prohibitedTerms.test.js`가 같은 벡터를 Functions 구현으로 실행(P2), createMemberSummary e2e 거부 케이스(AC-SOAP-05.5, AC-PRIV-06.2) | block | 예 | DF-309 |
| `docs-and-backlog` | copy_ko.json 키 정규식·중복·필수 필드(audience, phase, prdRefs) 검사, 덱 전체 lint(대상별 세트), 이 문서 헤더 표준 | block | 경로 해당 시 | DF-001, DF-010 |
| `static-guards` | `"저장됨"` 단독 리터럴(트레이너 앱), `setUserID`·`setUserProperty`, 회원 앱 원 기록 경로 문자열 등 grep 0건(ASM-12-19) | block | 예 | DF-011 |

- 전환 조건(DF-040): `report` 모드 보고서의 block 위반이 0건(§7.12 기준선 처리 완료), allowEntries 검토 기록이 PR에 있음. 전환 뒤 위반을 들이는 PR은 병합할 수 없다.
- **ASM-12-22** `--check-deck`은 v1에서 경고만 한다. 덱과 카탈로그 동기화를 차단 조건으로 올릴지는 P1a 종료 검토에서 정한다.
- **ASM-12-19** static-guards에 `"저장됨"`(앞뒤 문자 없는 단독 리터럴) 0건 규칙을 더한다. §6.0.3 '저장됨 단독 문구 금지'를 기계로 확인하기 위해서다. '기기에 저장됨'은 걸리지 않는다.

### 7.10 런타임 적용(같은 JSON)

| 위치 | 세트 | 동작 | 스토리 |
|---|---|---|---|
| TR-05 Review A·P·memberNote 입력(트레이너 앱) | common + causalPatterns + trainerRecord 약어 | 입력 중 250ms 디바운스로 검사. 일치 범위에 밑줄, `copy.warning.prohibited` + 대체어 칩(탭하면 치환). 확정은 막지 않고 `tr05.finalize.warningsRemain` 확인만(§6.4.4-7) | DF-120 |
| TR-06 Share 미리보기(P2) | common + member + memberAbbreviation + causalPatterns | block 위반이 있으면 공유 버튼 비활성(`tr06.disabled.prohibited`), 약어는 `copy.warning.abbreviation`, 인과는 경고만 | DF-311, DF-313 |
| createMemberSummary(서버, P2) | TR-06과 같음 | block 위반이면 `failed-precondition` / `summary.prohibitedTerms` + `details.violations[{field, term, start, end, ruleSet}]`. 인과 패턴은 거부하지 않고 로그(건수만) | DF-309 |
| 맞춤 빠른 문구 등록(P2) | common + causalPatterns | 등록 거부 + 대체어 제안 | DF-327 |
| 알림 템플릿(알림 도입 시) | common + member + memberAbbreviation | CI 템플릿 린트 | 알림 도입 스토리 |

- 트레이너 앱은 생성된 `ProhibitedTerms.swift`(TrainerContracts)를 쓴다. 규칙 JSON을 앱 실행 중 원격으로 받지 않는다(규칙 변경 = 앱 릴리스). 서버와 규칙 버전이 다르면 서버 결과가 이긴다(TR-06은 서버 `violations`로 표시를 갱신).

### 7.11 테스트 벡터

`contracts/vectors/prohibited-terms.v1.json`(DF-010)으로 옮기는 25개. 세 구현이 모두 같은 결과를 내야 한다(TC-12-LN-01~03).

| ID | 세트 | 입력 | 기대 |
|---|---|---|---|
| PT-V01 | common | 체형교정 프로그램 | C1-05 |
| PT-V02 | common | 자세 · 교정 운동 | C1-05 |
| PT-V03 | common+trainer | 치료계획, 홈운동, 다음 세션 | C1-03 |
| PT-V04 | common | 주간 빈도수 기록 | 위반 없음 |
| PT-V05 | common | 도수치료 기록 | C1-03, C1-16 |
| PT-V06 | common | 회원 기록과 일정이 정상적으로 정리되어 있습니다. | 위반 없음 |
| PT-V07 | common | 정상 범위 안이에요 | C1-22 |
| PT-V08 | common+member+memberAbbreviation | 측정 오차보다 큰 변화가 정한 목표 방향으로 나타났어요 | 위반 없음 |
| PT-V09 | common+member+memberAbbreviation | 의미있는 개선이 보여요 | C3-M-01, C3-M-04 |
| PT-V10 | common+trainer | 의미 있는 개선 | 위반 없음 |
| PT-V11 | common+member+memberAbbreviation | CVA가 2.0° 늘었어요 | ABBR |
| PT-V12 | common+member+memberAbbreviation | 체질량지수(BMI) 23.1 | 위반 없음 |
| PT-V13 | common+trainer | 관측 단면 측정값 (키 `tr13.title`) | C1-23 |
| PT-V14 | common+trainer | 측정값을 하나 이상 입력하세요 (키 `tr11.title`) | 위반 없음 |
| PT-V15 | common+trainer | 운동 지도와 건강관리 기록용이며 진단이나 치료를 위한 정보가 아닙니다. | 위반 없음 |
| PT-V16 | common+trainer | 운동 지도와 건강관리 기록용이며 진단이 아닙니다. | C1-01 |
| PT-V17 | common | 거북목 개선 프로그램 | C1-11, C1-13 |
| PT-V18 | common | 재활 트레이닝 | C1-06 |
| PT-V19 | common | 수술 후 환자용 코스 | C1-09 |
| PT-V20 | common | 분석 정확도 95% | C1-21 |
| PT-V21 | common | 스트레칭 때문에 CVA가 좋아졌어요 | C2-01(warn) |
| PT-V22 | identifier | posture_diagnosis_viewed | IDT |
| PT-V23 | identifier | soap_review_finalized | 위반 없음 |
| PT-V24 | common | 체\u200B형 교정 | C1-05 |
| PT-V25 | common+member+memberAbbreviation | 통증 점수(0–10) | 위반 없음 |

| ID | 종류 | 파일(신규) | 확인 |
|---|---|---|---|
| TC-12-LN-01 | node:test | `tool/lint/test/prohibited-terms.vectors.test.mjs` | 벡터 25개 기대값 일치 |
| TC-12-LN-02 | swift test | `TrainerCore/Tests/TrainerDomainTests/CopyGuardTests.swift` | 같은 벡터를 Swift 구현으로 |
| TC-12-LN-03 | node:test(P2) | `functions/test/unit/summaries/prohibitedTerms.test.js` | 같은 벡터를 Functions 구현으로 |
| TC-12-LN-04 | node:test | `tool/lint/test/extractors.test.mjs` | 언어별 추출: 주석 제외, 보간 바깥만, xcstrings 키 전달, JSX 텍스트 |
| TC-12-LN-05 | node:test | `tool/lint/test/path-rulesets.test.mjs` | 경로 첫 일치(`lib/screens/trainer/x.dart`의 '개선'은 통과, `lib/screens/insights/x.dart`는 C3-M-01) |
| TC-12-LN-06 | node:test | `tool/lint/test/allow-entries.test.mjs` | AE-01 정확 일치만 허용, AE-03은 `case` 줄만, inactive 항목은 무시 |
| TC-12-LN-07 | node:test | `tool/lint/test/copy-deck.test.mjs` | `docs/v1/data/copy_ko.json` 전체가 대상별 세트로 위반 0건, 키 정규식·중복 0 |
| TC-12-LN-08 | CI 스모크 | `copy-lint` job | `--mode=block`에서 위반 주입 시 exit 1, `--mode=report`에서 exit 0 |

### 7.12 현재 저장소 기준선(2026-09-24)

2026-09-24 작업 트리(feature/integrated-care-2026, 미커밋 포함)를 부록 C 공통·회원 세트로 grep한 결과다. 주석 줄이 섞였을 수 있는 정적 추정이며, 정확한 목록은 DF-010 보고 모드 첫 실행(TC-DF010-05)이 만든다. block 모드 전환(DF-040) 전에 모두 처리해야 한다.

- **Runner(`ios/Runner/AppDelegate.swift`) 줄 번호는 `main`(HEAD `d841412` 판, 8,800줄) 기준이다.** MIG-01에서 AppDelegate 미커밋 변경(+975/−118)은 B분류로 보관 브랜치에 가므로, DF-028은 `main` 줄을 고친다. 괄호 안은 PRD·보관 브랜치 tip(작업 트리 9,657줄) 줄이다. 대응표 정본은 [V1-11 §6.2](11_MIGRATION_RUNBOOK.md#62-출시-앱-문구--main-줄-번호-대응표)다.
- 작업 트리에만 있는 Runner 문자열(program·schedule 상세 화면 등 B분류 코드)은 `main`에 없으므로 출시 빌드 대상이 아니고 DF-028 범위도 아니다. 이 코드는 이식하지 않으며(AS-21), 보관 브랜치 문구는 고치지 않는다([V1-11 §6.2](11_MIGRATION_RUNBOOK.md#62-출시-앱-문구--main-줄-번호-대응표) 끝 목록).
- 회원 앱(`lib/**`) 줄 번호는 작업 트리 기준이다. DF-029 대상 4개 파일은 `main`과 줄이 같다(V1-11 §6.2).

| 위치 | 문자열(요지) | 규칙 | 처리 | 스토리 |
|---|---|---|---|---|
| dfet:ios/Runner/AppDelegate.swift:2062 (작업 트리 :2857) | '자세 교정', '재활 트레이닝', '체형 교정' | C1-05, C1-06 | '자세 균형 운동', '컨디션 관리 운동', '정렬 변화 기록' | DF-028(MIG-04) |
| dfet:ios/Runner/AppDelegate.swift:3049 (작업 트리 :3844) | `"diagnosis": selectedMember.subtitle` | (문구 아님, F-PRIV-06.1) | 자동 채움 제거 | DF-028 |
| dfet:ios/Runner/AppDelegate.swift:3524, :3533, :3930, :3931 (작업 트리 :4319, :4328, :4725, :4726) | '치료계획, 홈운동, 다음 세션…' | C1-03 | '운동 계획, 홈운동, 다음 세션…' | DF-028 |
| dfet:ios/Runner/AppDelegate.swift:7860 (작업 트리 :8717) | '세션 중 치료/운동 계획' | C1-03 | '세션 중 운동 계획' | DF-028 |
| dfet:ios/Runner/AppDelegate.swift:8101 (작업 트리 :8958) | '진단/이슈' 입력 | C1-01 | 입력란 제거 | DF-028 |
| dfet:ios/Runner/AppDelegate.swift:613 (`main` 전용, 작업 트리에서는 B분류 program 상세 화면으로 교체됨) | program 자리 표시 subtitle '운동 처방, 세트, 반복, 강도, 진행도를 관리합니다.' | C1-08 | '운동 계획, 세트, 반복, 강도, 진행도를 관리합니다.' **PRD MIG-04 목록에 없는 줄**(출시 중인 `main` 코드) | DF-028 범위 추가(동결 예외, 충돌 X-06) |
| dfet:lib/screens/guide_screen.dart:38, :41 | '체형 불균형', '거북목, 골반 불균형' | C1-11, C1-11b | '자세 사진 관찰', '머리 전방 자세·어깨 높이 차이 관찰' | DF-029 |
| dfet:lib/screens/onboarding_screen.dart:40, dfet:lib/screens/profile_setup_screen.dart:38 | 목표 '체형 교정' | C1-05 | 표시 '자세 균형 운동'(저장 값 호환은 AE-03) | DF-029 |
| dfet:lib/screens/create_request_screen.dart:150 | '새로운 자세 교정 요청' | C1-05 | '새로운 자세 관찰 요청' | DF-029 |
| dfet:lib/screens/trainer/trainer_soap_notes_screen.dart:548, :883, :1269 | '진단' 검색 안내, '진단/이슈' 입력·표시 | C1-01 | 입력 제거(§3.4-2), 문구 교체 | DF-041 |
| dfet:lib/services/video_pose_analyzer.dart:438, :440, :441 | '개선하면', '개선이 필요합니다', '교정해주세요' | C3-M-01, C1-05 | '다듬으면', '동작을 다시 확인해 보세요' | DF-041 |
| dfet:lib/screens/posture_result_screen.dart:331 | '개선 팁 보기' | C3-M-01 | '동작 팁 보기' | DF-041 |
| dfet:lib/screens/dashboard.dart:639 | '개선' 라벨 | C3-M-01 | 맥락 확인 후 교체 | DF-041 |
| dfet:lib/services/coaching_correlation_service.dart:83, dfet:lib/services/smart_coach_service.dart:388 | '글리코겐 회복', '회복의 핵심' | C1-06 | '에너지 보충', '컨디션 관리의 핵심'(ASM-12-13) | DF-041 |
| dfet:lib/widgets/meal_dialog.dart:356, :523 | 'AI 분석 완료: {confidence} 정확도' | (C1-21은 '정확도 N%'만) | 값이 백분율로 표시되면 C1-21. 표시 형식 확인 | DF-041 |
| dfet:lib/screens/microbiome/microbiome_screen.dart:114, :115, :204, :209 | '판정 정책', '의료 진단이 아닙니다' | C3-M-03, C1-01 | '판정' → '비교 기준'. 고지는 AE-10·AE-11 결정 | DF-041(Q-DEV-12-05) |
| dfet:lib/screens/blood/blood_screen.dart:65, dfet:lib/screens/blood/blood_report_screen.dart:139-144 | '정상범위와 판정', '의료 진단이 아닙니다' | C1-22, C3-M-03, C1-01 | '참고 범위와 결과 구분' 권장. AE-13 결정 | DF-041(Q-DEV-12-05) |
| dfet:lib/screens/insights/insight_detail_screen.dart:103, dfet:lib/screens/insights/insights_screen.dart:81, dfet:lib/screens/dashboard/today_signal_screen.dart:151 | '의료 진단을 의미하지 않습니다', '비진단 정보' | C1-01 | §3.1 짧은 고지로 통일 권장(AE-12) | DF-041 |
| dfet:lib/design_system/d_fet_evidence.dart:337, dfet:lib/screens/insights/components/action_recommendation_card.dart:149 | '판정 근거와 데이터 상태', '임상 판정에 반영되지 않습니다' | C3-M-03 | '근거와 데이터 상태', '의료 기록에 반영되지 않습니다' | DF-041 |
| dfet:lib/widgets/clinical/range_bar.dart:22 | '승인된 정상범위가 없습니다' | C1-22 | '승인된 참고 범위가 없습니다' 또는 AE-13 | DF-041 |
| dfet:lib/demo/clinical_demo_data.dart:349, :362, dfet:lib/demo/design_lab_atoms_screen.dart:221 | 데모 문장의 '개선', '판정' | C3-M-01, C3-M-03 | 데모도 출시 번들에 들어가면 교체. 들어가지 않으면 `lib/demo/**`를 allowPaths에 추가(소유자 결정) | DF-041 |
| dfet:admin_web/app/(console)/settings/reference-ranges/page.tsx:13, dfet:admin_web/components/console-shell.tsx:20 | '정상범위 버전', '정상범위' 메뉴 | C1-22 | '참고 범위' 또는 AE-13 | DF-041 |

- 작업 트리 AppDelegate.swift:1828 '정상적으로 정리되어'(B분류 alerts 상세, `main`에 없음)는 except('정상적')로 걸리지 않는다(PT-V06). 같은 패턴이 이식 코드나 새 문자열에 나타날 때의 기대 동작 예시로만 남긴다.
- 작업 트리 AppDelegate.swift:1548 '회원 목표, 운동 처방 방향, 다음 세션 계획…'(B분류 `NativeTrainerProgramDetail` :1530-1728)은 HEAD `d841412`에 없다(`git show HEAD:ios/Runner/AppDelegate.swift`에서 0건). MIG-01 뒤 `main`에 들어가지 않으므로 DF-028 범위가 아니다. program 화면은 이식 제외(AS-21)이고, 보관 브랜치 문구는 고치지 않는다.
- 주석(예 dfet:lib/screens/dashboard.dart:490, :513, dfet:lib/services/coaching_correlation_service.dart:5-7의 '처방')은 린트 대상이 아니다. 다만 영양 '처방' 용어가 UI 문자열로 새지 않는지 DF-041에서 함께 확인한다.

### 7.13 예외 추가·규칙 변경 절차

1. `contracts/prohibited-terms.v1.json`을 고치는 PR에는 `regulatory` 라벨을 단다. CODEOWNERS(GH-09)가 소유자를 지정한다.
2. PR 본문에 ① 부록 C의 어느 행·어느 사유인지 ② 새 벡터(최소 허용 1개·차단 1개) ③ 영향받는 파일 수(보고 모드 실행 결과)를 적는다.
3. 부록 C에 없는 용어를 추가하거나 빼면 PRD 변경 제안이 필요하다(PRD §13.4에 따라 부록 C 개정, 필요하면 G-10 재검수).
4. allowEntries에 실제 UI 문장을 넣을 수 있는 경우는 `regulatoryDisclaimer`(PRD 원문)와 소유자가 활성화한 `existingDisclaimerCandidate`·`approvedNormContextCandidate`뿐이다.

---

## 8 G-10 표시·광고 수동 검수 체크리스트

P3 진입 전(DF-921) 소유자가 스토어 설명, 스크린샷, 웹, IR·영업 자료, 특허 홍보를 대상으로 한 번 하고, 이후 표시·광고 문구가 바뀔 때마다 다시 한다. 증빙은 V1-T07(게이트 증빙)에 첨부한다.

| # | 확인 | 근거 | 결과 기록 |
|---|---|---|---|
| G10-01 | 첫 문단이 `store.purpose` 원문과 같다(요약·변형 없음) | §3.1 | 스크린샷 |
| G10-02 | 텍스트를 `node tool/lint/prohibited-terms.mjs --stdin --ruleSets common,member,memberAbbreviation`로 검사해 block 0건 | 부록 C.3 | 보고서 |
| G10-03 | 인과 경고(C2-*)가 0건이거나, 남은 건마다 '함께 관찰됨·연관 가능성' 표현인지 사람이 확인 | 부록 C.2 | 표 |
| G10-04 | 스크린샷 안 문자(이미지 속 텍스트)에도 금지어가 없다. 스크린샷 회원 데이터는 합성 가상 회원뿐이다 | 부록 C.1, ADR-013 | 이미지 목록 |
| G10-05 | 정확도·검증 주장('정확도 N%', '임상적으로 검증', '의료기관 수준', '3D 정밀')이 없다. 문헌값을 쓰면 출처와 '문헌값, 자체 재검사 전'이 함께 있다 | C1-20, C1-21, 부록 D | 표 |
| G10-06 | LiDAR 수치를 '측정값'으로 부르지 않고 베타 라벨이 있다. 3D 형상 기반 체지방·부피 주장이 없다 | §6.3 | 표 |
| G10-07 | 환자군·질환 표적 표현(디스크, 측만, 수술 후, 거북목 개선)이 없다 | C1-09, C1-11, C1-13 | 표 |
| G10-08 | 체형 점수·등급, '근골격 기능 등급'(특허 표현 포함)이 없다. 특허 홍보 문구는 Q-17 공개 범위 결정을 따른다 | C1-18, C1-19, Q-17 | 표 |
| G10-09 | 회원 변화 문장이 있으면 부록 B.8 문장과 글자까지 같다 | B.8 | 표 |
| G10-10 | 분석·로그·크래시 SDK 설명이 처리방침(G-09)의 국외이전 항목과 일치한다 | AS-19, G-09 | 링크 |

---

## 9 스토리 대응과 구현 순서

| 순서 | 스토리 | 이 문서에서 구현하는 것 | 완료 증빙 |
|---|---|---|---|
| 1 | DF-010(S02) | forbidden_terms.json → `contracts/prohibited-terms.v1.json` + 벡터 파일, `tool/lint/prohibited-terms.mjs`(§7.3·§7.8), `copy-lint` job(report), 기준선 보고서(§7.12) | TC-12-LN-01, -04~-08, TC-DF010-01~05 |
| 2 | DF-017·DF-016(S03·S06) | `Localizable.xcstrings` 생성, §3 매핑 함수(`SyncStateBadge`, `SourceGradeChip`, `ChangeBadge`), §4.5 식별자 규칙 | 스냅샷, XCUITest 식별자 |
| 3 | DF-028·DF-029(S04) | §7.12 Runner(`main` 줄, V1-11 §6.2)·회원 앱 4개 파일 교체(+`main` AppDelegate.swift:613) | copy-lint 해당 줄 0건 |
| 4 | DF-041(S04, 제안) | §7.12 나머지 위반 처리, AE-10~13 결정 | 보고 모드 block 0건 |
| 5 | DF-040(S05) | `COPY_LINT_MODE=block`, 필수 체크 등록 | TC-12-LN-08 |
| 6 | DF-033(S06) | analytics_events.json → `contracts/analytics-events.v1.json`, audit-actions 식별자 린트, 생성기 출력(§5.8) | TC-12-AN-05 |
| 7 | DF-126(S08) | `TrainerAnalytics`, `LiveSessionTracker`(§5.7), DebugSink | TC-12-AN-01~04 |
| 8 | DF-110·DF-122·DF-127·DF-129(S08~S12) | 각 이벤트 전송 지점 | 스토리 AC의 DebugSink 캡처 |
| 9 | DF-120(S09) | TR-05 인라인 경고(§7.10) | TC-12-LN-02, UI 테스트 |
| 10 | DF-137·DF-224 | opsMetrics(§6.1 M-03·M-05) | V1-06 TC-06-AGG |
| 11 | DF-204·DF-208·DF-209(P1b) | 체형 이벤트 | TC-12-AN-01 |
| 12 | DF-309·DF-311·DF-313·DF-315·DF-316·DF-306·DF-307(P2) | 서버 검사, TR-06 미리보기, 회원 문구 파일(§4.4), 회원 분석 클라이언트 | TC-12-LN-03, TC-12-AN-07 |
| 13 | DF-921(P3) | §8 G-10 | V1-T07 증빙 |

---

## 10 가정·충돌·열린 질문

### 10.1 가정(ASM-12-NN)

| ID | 가정 | 관련 PRD | 검증 시점 |
|---|---|---|---|
| ASM-12-01 | docs/v1/data의 D1·D2는 설계 시드이고 DF-010·DF-033 병합 뒤 contracts가 코드 정본이다. D3(copy_ko.json)는 문구 정본으로 docs에 남는다 | §13.4 | DF-010, DF-033 |
| ASM-12-02 | M-02는 종료 전 기록 완료도 충족으로 보고, 앱 백그라운드는 세션 종료가 아니다. 이를 위해 `end_relation`, `saved_before_end` 속성을 더한다 | §5.3 M-02, §5.5 | Q-DEV-12-01, P1a 종료 검토 |
| ASM-12-03 | 인과 패턴은 경고, 정확한 구 '원인은'만 차단 | 부록 C.1, C.2, F-PRIV-06.2 | DF-010 |
| ASM-12-04 | elapsed_band 경계·대표값, 평균은 대표값 가중 평균, 600s+ = 900초 | §5.3, §5.5 | P1a 종료 검토 |
| ASM-12-05 | `input_method`에 `none`(빈 기록)을 더한다 | F-SOAP-01.2 | DF-126 |
| ASM-12-06 | 신체조성·둘레의 조건 사유 회원 문장은 '측정 조건이 달라요'(B.8의 '촬영 조건이 달라요'는 사진 지표용). 승인 전에는 이 키를 쓰지 않고 해당 highlight에 배지를 붙이지 않는다 | 부록 B.8, F-VIZ-06.3 | Q-DEV-12-04, P3 진입 전(판정은 P3부터) |
| ASM-12-07 | 문헌 MDC만 있는 지표가 섞인 회원 리포트 하단 문장 `mb.change.valuesOnlyFooter` | F-VIZ-06.3, §7.6 | P3 |
| ASM-12-08 | M-G5 계산을 위해 `bodycomp_record_saved`·`member_summary_shared`에 `elapsed_band`, 새 이벤트 `circumference_saved`를 둔다 | §5.4 M-G5, §5.5 | P1b 종료 검토 |
| ASM-12-09 | `flag.disabled` 사용자 문장은 두 앱 모두 '지금은 사용할 수 없는 기능이에요.' | §8.4 | DF-306 |
| ASM-12-10 | 분석 SDK 설정(수집 기본 끔, IDFV·광고 신호·화면 자동 수집 끔, 보존 2개월, BigQuery 미사용)과 `setUserID`·`setUserProperty` 금지 | NFR-10, NFR-11, AS-19 | G-09(DF-909) |
| ASM-12-11 | 회원 앱은 ARB 없이 화면별 `*_copy.dart` 상수를 쓴다 | §10.5 | DF-306 |
| ASM-12-12 | 회원 허용 약어는 BMI, D-FET | 부록 B.8, F-SOAP-07.3 | DF-010 |
| ASM-12-13 | '회복'은 영양·수면 코칭 문장에도 예외 없이 적용 | 부록 C.1 | DF-041 |
| ASM-12-14 | 기존 4축 고지·'정상범위' 문장 허용 후보(AE-10~13)는 비활성으로 시작 | 부록 C.1·C.3, D4 | Q-DEV-12-05, DF-041 |
| ASM-12-15 | M-G2 월간 대조는 읽기 전용 스크립트 `functions/scripts/ops/consentConsistencyReport.js`(수량만)로 소유자가 실행 | §5.4 M-G2, F-PRIV-05.4 | Q-DEV-12-03 |
| ASM-12-16 | 동의 문서 초안 26개는 PRD 표를 옮긴 자리 표시이며 G-04 전 게시 금지 | F-PRIV-01, G-04, Q-24 | DF-908 |
| ASM-12-17 | Runner AppDelegate.swift에는 trainer 세트 적용 | §3.4-8 | DF-010 |
| ASM-12-18 | 기본 빠른 문구 9개(S·A·P 각 3개)는 이 문서가 정한 관찰 표현이다(PRD는 개수만 정함) | F-SOAP-07.1 | DF-124, P1a 종료 검토(M-11) |
| ASM-12-19 | static-guards에 단독 '저장됨' 리터럴 0건 규칙 추가 | §6.0.3 | DF-011 |
| ASM-12-20 | 관리자 웹 문구는 `admin_web/lib/copy/ko.ts` | §10.7 | DF-027, DF-032 |
| ASM-12-21 | 표기 규칙(음수 U+2212, 날짜 형식, 구분자 ' · ') | §8.6 A-03 | DF-016 |
| ASM-12-22 | `--check-deck`은 v1 동안 경고만 | — | P1a 종료 검토 |

### 10.2 다른 문서·스파인과의 충돌

| ID | 충돌 | 이 문서의 처리 | 후속 |
|---|---|---|---|
| X-01 | V1-06 §6.12는 MB-05의 `flag.disabled`를 '추후 추가 예정'으로 매핑했지만 PRD §8.4는 회원 앱에서 그 문구를 쓰지 않는다 | '지금은 사용할 수 없는 기능이에요.'(ASM-12-09) | V1-06 표 수정 |
| X-02 | DF-010 카드 구현 노트는 '원인은'을 경고 패턴에 넣었다. 부록 C.1은 금지어다 | '원인은' 차단, 나머지 인과 패턴 경고(ASM-12-03) | DF-010 카드 반영 |
| X-03 | DF-010 카드는 예외 목록에 §3.1 짧은 고지만 허용한다. §3.1 기본 문구(스토어), 저장 값 호환 case 줄, 기존 4축 고지 후보가 더 필요하다 | AE-02·AE-03·AE-04 활성, AE-10~13 비활성 후보(ASM-12-14) | 소유자 결정(Q-DEV-12-05) |
| X-04 | '측정값' 한정 방식: DF-010 카드는 경로(glob), P2 카드는 키 접두(`tr13.`)를 제안 | 두 방식 모두 `onlyIn`에 둔다 | — |
| X-05 | PRD §5.5 초안 이벤트만으로는 M-02(join 불가)와 M-G5(TR-11·TR-12·TR-06 시간)를 계산할 수 없다 | 속성 추가와 `circumference_saved` 제안(ASM-12-02, ASM-12-08) | 단계 종료 검토에서 PRD §5.5 개정 제안(§13.4, AS-34부터) |
| X-06 | PRD MIG-04·§3.4-4 목록에 없는 출시 앱 위반 줄 dfet:ios/Runner/AppDelegate.swift:613(`main` 판, program 자리 표시 '운동 처방, 세트…'). 작업 트리 :1548('운동 처방 방향')은 B분류라 `main`에 없어 대상 아님 | DF-028 범위에 `main` :613 추가(동결 예외) | DF-028 PR에 명시, V1-11 §6.2 표에 행 추가 제안 → V1-11 §6.2·V1-08 §7.2에 `main` :613 행 추가됨(정합 패스 2) |
| X-07 | PRD §5.5는 회원 앱 이벤트(`invite_code_redeemed`)를 두지만 회원 앱에는 분석 SDK 의존성이 없다(dfet:pubspec.yaml에 firebase_analytics 없음). PRD §10.5는 MB-01·MB-02에 새 의존성을 두지 않는다 | 회원 앱은 DebugSink만, SDK 도입은 소유자 결정 | Q-DEV-12-02 |
| X-08 | M-06·M-07은 `memberSummaries.firstViewedAt`이 필요한데 PRD §9.2·§10.6에 없다 | V1-06 ASM-06-04(`markSummaryViewed`, 소유 DF-335, 호출 MB-02·MB-04)를 따른다 | Q-DEV-04(V1-06) |
| X-09 | 부록 B.8 조건 사유 회원 문장 '촬영 조건이 달라요'는 신체조성·둘레에 맞지 않는다 | 보완 키 제안(ASM-12-06) | Q-DEV-12-04, 부록 B.8 개정 |
| X-10 | DF-029는 회원 앱 4개 파일만 다루지만 기준선(§7.12)에는 회원 세트 위반이 더 있다(insights, microbiome, blood, video_pose_analyzer 등) | DF-041(제안)로 처리, 미처리 시 DF-040 지연 | P0 백로그 스파인(DF-041 행) |
| X-11 | P1a 카드가 제안한 일부 키 이름·문장을 확정하며 바꿨다: `tr14.consent.type.required` → `consent.type.required`(두 앱 공유), `tr01.consentExpiredPurged`의 `%d` → `{count}`, `tr14.consent.documentMissing`의 '동의서' → '동의 문서' | 이 문서가 정본(§1.1) | 카드 구현 시 이 문서 키 사용 |

### 10.3 열린 질문(Q-DEV-12-NN)

| ID | 질문 | 결정 전 기본값 | 결정 시점 | 관련 |
|---|---|---|---|---|
| Q-DEV-12-01 | M-02에서 세션 종료 전 기록 완료를 충족으로 볼까? 앱 백그라운드를 종료로 볼까? | 충족으로 본다 / 종료 아님 | P1a 진입(S08, DF-126 착수 전) | §5.3 M-02 |
| Q-DEV-12-02 | 회원 앱에 firebase_analytics를 넣을까? | 넣지 않음(DebugSink) | P2 진입 | §5.5, §10.5, AS-19 |
| Q-DEV-12-03 | M-G2 월간 대조 스크립트를 스토리로 만들까? | 스크립트 없이 규칙 테스트 결과로만 보고 | P1a 종료 검토 | §5.4 M-G2 |
| Q-DEV-12-04 | 부록 B.8에 '측정 조건이 달라요'를 추가할까? | 추가 전에는 신체조성·둘레 조건 사유 배지 없음 | P3 진입(G-08 전) | 부록 B.8 |
| Q-DEV-12-05 | 기존 4축 부정문 고지와 '정상범위'·'판정' 문구를 바꿀까, 허용할까? | 바꾼다(AE-10~13 비활성) | S04(DF-041) | 부록 C.1, C.3, D4 |
| Q-DEV-12-06 | 공유 알림(F-SOAP-05.12)은 누가 어떤 경로로 보내나(서버 FCM, 인앱만)? | 인앱 목록 표시만, 푸시 없음 | P2 진입 | F-SOAP-05.12 |

## 11 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | - | 없음 |
| v1.0(검토 반영) | 2026-09-24 | :1548(보관 브랜치 전용) DF-028 범위 제외, `main` :613 추가(X-06), §7.12 Runner 행 `main` 줄 번호 | - | 없음 |
| v1.0(정합 패스 2) | 2026-09-24 | 06 가정 ID 참조 ASM-06-NN(R10), markSummaryViewed 소유·호출 화면(R5) | - | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: V1-06 가정 참조 ASM-06-04(R10), `markSummaryViewed` 소유 DF-335·호출 MB-02·MB-04(R5), X-06 후속 반영 표시 | - | 없음 |

# 기능명세

## 케어유형·프로필

- `CareType` wire 값은 `microbiome | fitness | both`만 허용한다.
- 게스트 선택은 SharedPreferences에 보존한다.
- 신규 인증 사용자의 프로필은 Firestore transaction으로 최초 1회 생성해 병행 초기화가 선택값을 덮어쓰지 못하게 한다.
- 기존 문서의 `careTypeVersion == 0`은 1회 확인 화면으로 이동한다.
- 변경 시 `careTypeVersion=1`, `careTypeConfirmedAt`을 함께 저장한다.

## 검사 수집

1. HTTP 메서드·경로 확인
2. HMAC key ID·타임스탬프·원문 서명 확인
3. envelope와 검사별 payload 검증
4. idempotency transaction 예약
5. 회원 UID/외부 별칭 해석
6. 정규화·승인 정책 조회·산정
7. 원문을 제한 Storage에 해시와 함께 저장
8. 소비자본·전문가본·스냅샷·작업 완료·감사를 Firestore batch로 커밋

동일 idempotency key와 같은 원문은 기존 결과를 반환한다. 다른 원문은 `409 idempotency_conflict`로 거부한다. 처리 중 중복은 `202`를 반환한다.

## 장내미생물

- 범위: 검사기관이 산출한 16S 결과. FASTQ/QIIME 처리는 제외한다.
- 필수: Shannon, Simpson, Chao1, Observed OTUs, PCoA, Phylum/Genus, weighted/unweighted UniFrac, metadata.
- 비율 0~1 구성비는 백분율로 변환하며 총합 100.5% 초과는 거부한다.
- 기관 승인 정책은 지표별 `referenceMean`과 최대 3개의 생활 `guides`를 포함할 수 있다. 승인된 값만 소비자본에 복사한다.
- `referenceMean`은 사용자 값과 참조집단 평균을 비교하는 `ComparisonCard`에 사용한다. 값이 없으면 비교 수치를 임의 생성하지 않는다.
- 생활가이드는 승인 정책이 없거나 목록이 비어 있으면 표시하지 않고, 검사 수치에서 임의 문구를 생성하지 않는다.
- 소비자본에는 alpha·Phylum·요약만 저장한다.
- 전문가본에는 정규화 전체와 원문 Storage 경로를 저장한다.

## 혈액 POCT

| 패널 | 코드 | 표준 단위 |
|---|---|---|
| 간 | ALT, AST | U/L |
| 간 | TBIL, DBIL | mg/dL |
| 간 | TP, ALB | g/dL |
| 신장 | UREA, CRE, UA | mg/dL |
| 대사/혈당 | GLU | mg/dL |
| 지질 | TG, CHOL, HDL-C | mg/dL |

- 13종 전체 또는 일부를 허용하고 패널 완성도를 저장한다.
- 지원 변환만 수행한다. 미지원 단위는 자동 추측하지 않고 수집 실패/검토 대상으로 남긴다.
- 보고서에는 원값·원단위(전문가본), 표준값·표준단위, 정책 버전을 저장한다.
- QR/UDI, Lot, 유효기간은 관리자·검사자 흐름에서만 입력한다.

## 임상 산정

- `status=approved AND active=true`인 최신 정책만 사용한다.
- 승인 정책이 없거나 지표 band가 없으면 `score=null`, `status=unscored`, `label=산정 준비 중`이다.
- 승인된 버전은 수정할 수 없고 새 버전으로만 게시한다.
- 활성화 시 같은 종류의 이전 버전을 transaction에서 비활성화한다.
- 보고서의 `policyVersion`으로 과거 결과를 재현한다.

## 소비자 리포트 근거 표시

- 장·혈액·통합 화면은 같은 `DfetEvidenceRibbon`으로 데이터 출처, 수신 범위 또는 완성도, 정책 버전을 표시한다.
- 정책 버전이 없으면 리본과 점수 영역 모두 `미승인`/`산정 준비 중` 상태로 유지한다.
- 리본을 펼치면 미지원 단위 검토 대기, 누락 축 비보간, 소비자/전문가 필드 분리 원칙을 화면 맥락에 맞게 설명한다.
- 검사값은 `DfetMetricValue`가 숫자·단위·미산정 상태를 동일한 tabular typography로 표현한다.

## 4축 통합 인사이트

- 축 키: `fitness`, `diet`, `gut`, `blood`.
- 검사 보고시점을 기준으로 운동·식단 정책 기간을 조회하고 최신 장·혈액 결과와 결합한다.
- 누락값은 보간하지 않으며 `missingAxes`, `availableAxes`, `completeness`를 저장한다.
- 누락 축이 있으면 레이더 차트도 해당 축을 0점으로 그리지 않고 `산정 준비 중`과 누락 축을 명시한다.
- `minimumAxes` 미만이면 통합 점수를 만들지 않는다.
- 문구는 인과 대신 연관 가능성(`wording=association`)으로 제한한다.

## 관리자 운영

- Firebase ID token을 서버에서 검증해 httpOnly 세션 쿠키로 교환한다.
- 모든 상태 변경 API는 동일 출처와 역할을 확인하고 감사로그를 기록한다.
- JSON/CSV는 관리자 서버에서 공통 envelope로 변환한 후 동일 HMAC Functions API를 호출한다.
- `lab_operator`는 수집과 작업 추적만 할 수 있고 회원·전문가 리포트를 열람하지 못한다.

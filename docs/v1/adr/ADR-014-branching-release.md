# ADR-014 브랜칭·릴리스·배포: 트렁크 기반 + 플래그 + 소유자 수동 배포

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-014 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §11.2 MIG-01(#7 이식 기준선), MIG-09, MIG-11, §12.1, §12.3, §12.4, NFR-09, G-01, D13 |
| 관련 에픽·스토리 | EP-00, EP-01, EP-13 / DF-901, DF-028, DF-139, DF-924, DF-930, DF-931 |
| 변경 규칙 | [문서 변경](../01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [상태](#1-상태)
2. [맥락](#2-맥락)
3. [결정](#3-결정)
4. [결과](#4-결과)
5. [대안](#5-대안)
6. [PRD 근거](#6-prd-근거)
7. [재검토 조건](#7-재검토-조건)
8. [관련 스토리](#8-관련-스토리)
9. [변경 이력](#9-변경-이력)

## 1 상태

**Accepted** (2026-09-24, 소유자 CJH).

## 2 맥락

- 작업 트리에 미커밋 87개 파일이 있고 브랜치는 `feature/integrated-care-2026`이다(D13). 보안·백엔드 변경과 폐기될 수 있는 트레이너 UI 변경이 섞여 있다.
- 기존 CI는 `pull_request`와 `main`, `feature/**` push에서 4개 job을 돈다(dfet:.github/workflows/ci.yml:3-6, :13-81).
- 팀은 1인(소유자 = PO + 개발자) + AI 에이전트다. 운영 Firebase 프로젝트는 dfetmanage 하나뿐이다.

## 3 결정

1. `main`을 트렁크로 두고 3작업일 안에 병합하는 짧은 브랜치에서 작업한다. 이름은 `<type>/DF-NNN-<slug>`(에이전트는 `claude/`·`codex/` 접두 허용). 병합은 스쿼시, 미완성 기능은 플래그 false로 병합한다(ADR-010).
2. **MIG-01 정리(DF-901)**: B분류(트레이너 UI 변경)는 `archive/trainer-ui-2026-09` 브랜치에 보관하고 병합하지 않으며 tip 해시를 이식 기준선으로 기록한다. A분류(보안·백엔드·테스트)만 main에 병합한 뒤 v1 작업을 시작한다. C분류는 커밋을 보류한다. `feature/integrated-care-2026`은 정리 뒤 삭제한다.
3. **버전**: 트레이너 앱 0.1(P0) → 0.2(P1a) → 0.3(P1b) → 0.4(P2) → 1.0(P3). 빌드 번호는 `github.run_number`.
4. **태그**: `trainer-vX.Y.Z`, `member-vX.Y.Z`, `rules-YYYYMMDD-N`, `functions-YYYYMMDD-N`, `mig03-apply-YYYYMMDD`, `bodypathcore-vX.Y.Z`(BodyPath 저장소), `archive/trainer_ios-final`.
5. **배포**
   - 트레이너 앱 P1a~P2: `trainer-testflight` 워크플로(workflow_dispatch, 소유자 전용)로 TestFlight 내부 그룹. P3 채널은 Q-DEV-02.
   - 규칙·인덱스·Functions: 소유자가 태그와 체크리스트를 확인한 뒤 수동 `firebase deploy --project dfetmanage --only firestore:rules,firestore:indexes,storage` / `firebase deploy --project dfetmanage --only functions:<name>`(저장소에 `.firebaserc`가 없으므로 `--project` 필수, [RELEASE_CHECKLIST](../templates/RELEASE_CHECKLIST.md)). CI는 배포하지 않는다.
   - 회원 앱: 기존 스토어 릴리스. 규제 문구 수정 릴리스는 P0(DF-911).
6. **동결 예외**: Runner 내장 트레이너·trainer_ios 수정 PR에는 `freeze-exception` 라벨과 사유를 붙인다(MIG-09).
7. **롤백**: §12.4 표와 MIG-11을 따른다. v1 SOAP 쓰기 차단 규칙은 롤백하지 않는다.
8. **병합 권한**: 소유자만 병합한다. 에이전트는 병합·배포·운영 데이터 접근·이슈 생성을 하지 않는다.

## 4 결과

**좋아지는 점**
- 미커밋 누적이 다시 생기지 않는다.
- 운영 배포가 태그로 추적되고 사람이 확인한다.

**비용·위험**
- 소유자 검토가 병목이다(속도 가정 20점/주).
- 수동 배포는 실수 여지가 있어 체크리스트(V1-T14)가 필수다.

**후속 작업**
- DF-901 MIG-01, DF-930 동결 선언, DF-139 TestFlight 워크플로, DF-931 규칙·함수 배포, DF-924 MIG-03 적용.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| GitFlow | 릴리스 분리 | 1인 팀에 과함 |
| 장기 기능 브랜치 | 격리 | 미커밋 누적 재발 |
| CI 자동 배포 | 빠름 | 운영 프로젝트 하나뿐이라 규칙 오배포 위험 |

## 6 PRD 근거

§11.2 MIG-01(#7 이식 기준선), MIG-09, MIG-11, §12.1, §12.3, §12.4, NFR-09, G-01, D13. 설계 반영 위치: [V1-01 브랜치·커밋·PR 규칙](../01_AGILE_WORKING_AGREEMENT.md#브랜치커밋pr-규칙), [V1-03 릴리스·스프린트 계획](../03_RELEASE_AND_SPRINT_PLAN.md), [V1-11 마이그레이션 런북](../11_MIGRATION_RUNBOOK.md).

## 7 재검토 조건

- 협업자가 생기면 필수 승인 수를 1로 올리고 CODEOWNERS 리뷰를 강제한다.
- 스테이징 프로젝트가 생기면 스테이징 자동 배포를 검토한다.

## 8 관련 스토리

DF-901, DF-028, DF-139, DF-924, DF-930, DF-931.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |

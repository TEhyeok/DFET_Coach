# ADR-007 바이너리는 Storage(부모 문서 권한), LiDAR 원본은 기기 로컬

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-007 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | D10, §9.5, F-ASM-01.7, F-ASM-01.10, F-SOAP-01.7, F-BC-02, F-LIDAR-02.2, NFR-05, NFR-17, S-01~S-09, RISK-06 |
| 관련 에픽·스토리 | EP-03, EP-10, EP-11, EP-14 / DF-023, DF-038, DF-906, DF-118, DF-128, DF-205, DF-206 |
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

**Accepted** (2026-09-24, 소유자 CJH). 교차 서비스 규칙의 실환경 확인(S-09, DF-038)이 실패하면 이 ADR을 개정한다.

## 2 맥락

- Runner 내장 트레이너는 필기를 base64로 문서에 넣는다(`"inkDataBase64": drawing.dataRepresentation().base64EncodedString()`, dfet:ios/Runner/AppDelegate.swift:3858). 문서 한도 1MiB 위험이 있다.
- trainer_ios는 필기를 초안에 연결하지 않아 저장하지 않는다(dfet:trainer_ios/DFETTrainer/Features/SOAP/SOAPWorkspaceView.swift:11).
- 현재 Storage 규칙은 clinical-ingest, requests, posts만 열고 그 밖은 모두 거부한다(dfet:storage.rules:15-33).
- BodyPath는 원본(깊이·프레임·메시)을 기기에만 둔다.

## 3 결정

1. 경로는 PRD §9.5를 따른다: `postureAssessments/{id}/{view}.jpg`, `{view}_thumb.jpg`, `{view}_masked_thumb.jpg`, `soapInk/{noteId}/{inkRevision}.drawing|.png`, `bodyCompositionRecords/{id}/report.jpg`, `bodyScans/{id}/thumb.jpg`, `consentSignatures/{recordId}.png`(Functions만), `rightsExports/{requestId}.zip`(Functions만).
2. 경로는 **기록 ID 기준**이며 회원 키를 넣지 않는다. 승격해도 파일을 옮기지 않는다.
3. 규칙은 `firestore.get()`으로 부모 문서를 한 번 조회해 `trainerId == uid`와 상태를 판정하고 크기·MIME을 제한한다. 그래서 **부모 문서가 서버에 반영된 뒤에만 업로드**한다(Outbox ② → ③, ADR-002).
4. 업로드 전 기기에서 EXIF·GPS를 제거하고 얼굴 가림 썸네일을 만든다. v1은 JPEG만 생성한다. 업로드 뒤 크기와 해시(서버 `md5Hash` 대 로컬 MD5, `customMetadata.sha256` 기록)를 대조한 뒤 경로를 기록한다.
5. 트레이너 앱은 SDK 바이트 다운로드와 보호된 로컬 캐시를 쓴다. `getDownloadURL()`은 모든 앱에서 금지한다(static guard). 회원은 서명 URL 함수로만 받는다(ADR-006).
6. LiDAR 깊이·프레임·메시·manifest는 업로드 경로가 없다(기본 거부, S-08). `meshSHA256`, 윤곽, 썸네일만 올린다.
7. Storage 서비스 계정의 Firestore 교차 조회 권한은 소유자가 부여하고(DF-906) 실환경에서 확인한다(DF-038, S-09).

## 4 결과

**좋아지는 점**
- 문서 크기 한도 문제가 사라지고, 사진 권한이 원 기록 권한과 같이 움직인다(담당 해제 시 읽기 차단, S-06).
- 공개·영구 링크가 없어 유출 경로가 줄어든다(RISK-06).

**비용·위험**
- 규칙 평가마다 Firestore 읽기 1건이 추가된다.
- 부모 반영 전에는 업로드할 수 없어 오프라인 촬영 사진은 로컬에 머문다.
- 교차 서비스 규칙이 실환경에서 동작하지 않으면 대안(Functions 경유 업로드 등)이 필요하다.

**후속 작업**
- DF-023 규칙과 S-01~S-08, DF-038 실환경 확인, DF-118 필기 업로드, DF-128 결과지, DF-205 EXIF·얼굴 가림, DF-206 체형 업로드 큐.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| 문서 안 base64·Bytes 인라인 | 구현 단순 | 1MiB 한도 위험(dfet:ios/Runner/AppDelegate.swift:3858) |
| 회원 키 기반 경로 | 회원 단위 삭제 쉬움 | 승격 시 파일 이동 필요 |
| 트레이너도 서명 URL로 읽기 | 규칙 단순 | 오프라인 캐시에 불리하고 함수 비용 |
| LiDAR 원본 업로드 | 서버 재계산 가능 | D10 위반, 민감도·용량 과다 |

## 6 PRD 근거

D10, §9.5, F-ASM-01.7, F-ASM-01.10, F-SOAP-01.7, F-BC-02, F-LIDAR-02.2, NFR-05, NFR-17, S-01~S-09, RISK-06. 설계 반영 위치: [V1-04 §13](../04_ARCHITECTURE.md#13-바이너리-흐름), 규칙은 [V1-05 §8](../05_DATA_MODEL_AND_RULES.md#8-storage-경로규칙-초안).

## 7 재검토 조건

- S-09 실환경 확인 실패 → 업로드를 callable 경유로 바꾸는 개정.
- Q-03에서 iPad LiDAR 촬영이 결정되면 원본 로컬 원칙은 유지하되 썸네일 생성 위치를 재검토한다.

## 8 관련 스토리

DF-023, DF-038, DF-906, DF-118, DF-128, DF-205, DF-206.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |

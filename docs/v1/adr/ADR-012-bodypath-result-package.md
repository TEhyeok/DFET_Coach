# ADR-012 BodyPathCore 단계적 패키지: v1은 BodyPathResult + BodyPathCoreUI만

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-012 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | D2, §10.4.1~§10.4.3, F-LIDAR-01~03, NFR-13, NFR-14, NFR-18, G-07a, AS-28, AS-29, Q-03 |
| 관련 에픽·스토리 | EP-19 / DF-300, DF-301, DF-302, DF-303, DF-320, DF-321, DF-917, DF-923 |
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

**Accepted** (2026-09-24, 소유자 CJH). 결과 패키지 컨테이너 형식은 DF-301의 `docs/RESULT_PACKAGE_V1.md`가 정본이다(V1-04 ASM-04-09).

## 2 맥락

- D2는 'BodyPath 코어를 Swift Package로'를 요구한다. 그러나 v1 기본 경로는 BodyPath iPhone에서 계산하고 결과만 가져오는 것이라(AS-14), 트레이너 앱은 계산 코어를 호출하지 않는다(PRD §10.4).
- BodyPath는 iPhone 전용 SwiftData 앱이며(bodypath:ios/BodyScan/project.yml:4-5, :54) 저장소 루트에 `Package.swift`가 없다(확인함).
- 단면 플롯 `MeasurementSectionPlot`은 private 뷰이고 색을 `Theme.accent`와 `.orange`로 하드코딩한다(bodypath:ios/BodyScan/BodyScan/Views/BodyMeasurementView.swift:322-357, :342).
- 기록 모델 `BodyMeasurementRecord`에는 `meshSHA256`, `meshAlgorithm`, `isSynthetic`, `landmarkNote`, `referenceCircumferenceCM`이 있지만 촬영 시각·대상과 연결돼 있지 않다(bodypath:ios/BodyScan/BodyScan/Storage/MeasurementRecord.swift:28-47). 촬영 시각은 `Scan.takenAt`에 있다(bodypath:ios/BodyScan/BodyScan/Models/Models.swift:32-47).

## 3 결정

1. BodyPath 저장소 **루트**에 `Package.swift`를 둔다(SPM 원격 의존은 루트 매니페스트가 필요). 소스는 `packages/BodyPathCore/Sources/`, 테스트는 `packages/BodyPathCore/Tests/`.
2. v1 product는 둘뿐이다.
   - `BodyPathResult`(Foundation만): `ResultPackageV1` Codable DTO(schemaVersion, subjectCode, takenAt, algorithmVersion, meshAlgorithm, meshSHA256, isSynthetic, sections[{metricCode, perimeterMm, contour2dMm, confirmed}], referenceTapeCm?, quality{integratedFrames, flags[]}), `ResultPackageDecoder`, `ResultPackageValidator.validate(_:knownAlgorithms:) -> [ValidationIssue]`.
   - `BodyPathCoreUI`(SwiftUI만): `MeasurementSectionPlot(contours:bounds:selection:closedColor:openColor:onSelect:)`. 닫히지 않은 윤곽을 다른 색으로 표시하는 규칙은 유지하고 색은 호스트가 주입한다.
3. 트레이너 앱은 git 태그 `bodypathcore-vX.Y.Z`로 버전을 고정하고, P2(G-07a) 전에는 의존하지 않는다. TEhyeok/BodyPath는 비공개 저장소다(2026-09-24 `gh repo view` 확인, DFET_Coach는 공개). 따라서 trainer-app CI의 SPM 해석에는 DF-923 읽기 토큰이 반드시 필요하다. AS-DEV-03은 '확인됨'으로 본다. DF-923은 must이며 S23 시작 전에 끝나야 한다.
4. 결과 전달은 결과 패키지 v1(JSON + 얼굴 없는 썸네일)을 공유 시트·파일 앱으로 수동 가져오는 방식이다. 거부: `isSynthetic = true`, takenAt 없음, 미지원 schema·algorithm, 미확정 단면, 동의 ②③ 없는 회원, 대기 회원.
5. App Group과 BodyPath의 Firebase 직결은 채택하지 않는다(NFR-14).
6. 계산 코어 추출은 Q-03 결정 때 한다. 패키지 `swift test`(DTO 왕복, 검증기, 플롯 스냅샷)가 BodyPath CI의 병합 게이트이며 기존 `tools/check_measurement.sh`는 그대로 둔다(bodypath:.github/workflows/detail-capture.yml:34).

## 4 결과

**좋아지는 점**
- v1에 필요한 최소 경계만 만들어 BodyPath 쪽 선행 비용을 줄인다.
- 스키마가 BodyPath 저장소에서 버전 관리되고 D-FET은 태그로 참조한다.

**비용·위험**
- 수동 가져오기는 트레이너 조작이 필요하다.
- 비공개 저장소(확인됨) 읽기 토큰을 GitHub Secrets로 관리해야 한다(DF-923, 로그 미출력).
- G-07a가 늦으면 lidarBeta 전체가 P3 이후로 밀린다.

**후속 작업**
- DF-300 패키지와 DTO, DF-301 내보내기와 스키마 문서, DF-302 플롯 추출, DF-303 로드맵 1~2, DF-320·DF-321 TR-13, DF-917 G-07a 증빙.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| 계산 코어 일괄 추출 | D2 문구를 한 번에 충족 | v1 경로(iPhone 계산)에서 쓰이지 않음 |
| 별도 저장소 | 경계 명확 | AS-28과 다르고 관리 대상 증가 |
| git submodule + 로컬 경로 | 태그 불필요 | CI·에이전트 환경 복잡 |
| 소스 복사 | 즉시 사용 | 두 벌이 어긋남 |
| BodyPath에서 Firebase 직접 업로드 | 수동 단계 없음 | 두 번째 앱 등록·인증·App Check 필요, 연구 앱과 제품 데이터 경계 흐려짐 |

## 6 PRD 근거

D2, §10.4.1~§10.4.3, F-LIDAR-01~03, NFR-13, NFR-14, NFR-18, G-07a, AS-28, AS-29, Q-03. 설계 반영 위치: [V1-04 §18](../04_ARCHITECTURE.md#18-bodypathresult-패키지-경계).

## 7 재검토 조건

- Q-03에서 iPad 트레이너 앱 촬영이 결정되면 `BodyPathCore` 계산 코어 product를 추가한다(Foundation·simd·CryptoKit만).
- G-07 예비 결과로 베타가 해제되면 lidarBeta 관련 의존을 제거할지 결정한다.

## 8 관련 스토리

DF-300, DF-301, DF-302, DF-303, DF-320, DF-321, DF-917, DF-923.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |

# 알고리즘·계산 규칙 명세

| 항목 | 내용 |
|---|---|
| 문서 ID | V1-09 |
| 버전 | v1.0.1 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | §5.5, §6.1(F-ASM-01~06), §6.2(F-BC-01~03), §6.3(F-LIDAR-01~03), §6.4.4, F-SOAP-03, §6.5(F-VIZ-01~03, F-VIZ-07), §7.1~§7.9, §10.4.3, §12.6, 부록 A, 부록 B.4·B.8, 부록 C |
| 관련 에픽·스토리 | EP-06, EP-10, EP-11, EP-14, EP-15, EP-19, EP-21 / DF-010, DF-122, DF-126, DF-127, DF-128, DF-129, DF-130, DF-200, DF-201, DF-203, DF-204, DF-205, DF-207, DF-208, DF-209, DF-212, DF-215, DF-216, DF-217, DF-224, DF-300, DF-309, DF-320, DF-321, DF-322, DF-326, DF-380, DF-381, DF-382, DF-383, DF-939 |
| 변경 규칙 | [문서 변경](01_AGILE_WORKING_AGREEMENT.md#문서-변경) |

## 목차

1. [범위·정본 관계·공통 수치 규약](#1-범위정본-관계공통-수치-규약)
2. [이미지 좌표계와 방향](#2-이미지-좌표계와-방향)
3. [촬영 프로토콜 파라미터와 셔터 게이트](#3-촬영-프로토콜-파라미터와-셔터-게이트)
4. [랜드마크 집합·출처·확정 규칙](#4-랜드마크-집합출처확정-규칙)
5. [자세 지표 산식](#5-자세-지표-산식)
6. [체형평가 수명주기 계산 규칙](#6-체형평가-수명주기-계산-규칙)
7. [출처 등급·신뢰 등급·MDC 적용](#7-출처-등급신뢰-등급mdc-적용)
8. [조건 키·seriesBreak·seriesKey](#8-조건-키seriesbreakserieskey)
9. [4상태 변화 판정(evaluateChange, 서버 전용)](#9-4상태-변화-판정evaluatechange-서버-전용)
10. [신체조성 입력 검증과 단위](#10-신체조성-입력-검증과-단위)
11. [줄자 둘레 입력 규칙](#11-줄자-둘레-입력-규칙)
12. [NRS·ROM·MMT 입력 검증](#12-nrsrommmt-입력-검증)
13. [SOAP O 자동 불러오기와 확정 최소 요건](#13-soap-o-자동-불러오기와-확정-최소-요건)
14. [LiDAR 결과 패키지 가져오기 검증(BodyPathResult)](#14-lidar-결과-패키지-가져오기-검증bodypathresult)
15. [사진 개인정보 처리: EXIF 제거·얼굴 가림](#15-사진-개인정보-처리-exif-제거얼굴-가림)
16. [재검사 연구 분석(ICC·SEM·MDC95)](#16-재검사-연구-분석iccsemmdc95)
17. [금지어 매칭 규칙](#17-금지어-매칭-규칙)
18. [분석 이벤트 구간 계산](#18-분석-이벤트-구간-계산)
19. [가정(ASM-09-NN)](#19-가정asm-09-nn)
20. [PRD·스파인·다른 문서와의 충돌과 명확화](#20-prd스파인다른-문서와의-충돌과-명확화)
21. [변경 이력](#21-변경-이력)

---

## 1 범위·정본 관계·공통 수치 규약

### 1.1 정본 관계

- **PRD가 정본이다.** 산식은 [PRD F-ASM-03.3](../PRD_V1.md), 판정은 PRD §7.5 의사코드, 지표 메타는 부록 A가 정본이다. 이 문서는 그것을 **같은 입력에서 세 플랫폼(Swift·Dart·JS)이 같은 출력을 내도록** 구현 수준으로 고정한다. PRD와 어긋나면 PRD가 이기고, 발견한 어긋남은 [§20](#20-prd스파인다른-문서와의-충돌과-명확화)에 적었다.
- 이 문서가 정본인 것: 좌표계·회전 부호, 반올림, 조건 비교 순서, seriesKey 입력 문자열, 판정 경계(|Δ|=MDC), 입력 파싱, 결과 패키지 검증 코드, ICC 계산식 선택, 금지어 매칭 동작, 분석 구간 경계.
- 이 문서가 정본이 아닌 것: 필드 타입·규칙 코드는 [V1-05](05_DATA_MODEL_AND_RULES.md), callable 요청·응답과 오류 코드는 [V1-06](06_API_SPEC.md), 화면·문구 키는 [V1-07](07_TRAINER_APP_SPEC.md)·[V1-12](12_COPY_ANALYTICS_AND_LINT.md), 테스트 운영은 [V1-10](10_TEST_PLAN.md). 여기서는 링크만 한다.
- 변화 판정(MDC 비교)은 **서버 한 곳**(`functions/src/change/evaluateChange.js`, P3)에만 구현한다(ADR-009). 클라이언트(TrainerDomain, Dart)에는 조건 비교·seriesBreak(표시 규칙)만 두고 MDC 상수·판정 분기를 두지 않는다. static-guards가 이를 검사한다(AC-DF-216.8, TC-06-EVC-28).

### 1.2 규칙 → 구현 위치 → 벡터 → 스토리

| 규칙 | 구현 위치(생성 예정 경로) | 공유 벡터 | 스토리 |
|---|---|---|---|
| 좌표 변환·회전·자세 산식·확정 가능성 | `trainer_app/Packages/TrainerCore/Sources/PostureMath/` | `contracts/vectors/posture-metrics.v1.json` | DF-201 |
| roll·pitch 계산, 셔터 게이트 | `Sources/PostureVision/Capture/MotionLevelMonitor.swift`, `Sources/TrainerDomain/Posture/ShutterGate.swift` | `contracts/vectors/level-gate.v1.json`(신규 제안, ASM-09-03) | DF-203, DF-204 |
| Vision 제안 매핑 | `Sources/PostureVision/Landmarks/VisionLandmarkSuggester.swift` | 합성 이미지 픽스처(`trainer_app/Packages/TrainerKit/Tests/PostureVisionTests/Fixtures/`) | DF-207 |
| EXIF 제거·얼굴 가림 | `Sources/PostureVision/Privacy/{ExifStripper,FaceMasker}.swift` | 단위 테스트 픽스처 | DF-205 |
| 조건 비교·seriesBreak·seriesKey | `Sources/TrainerDomain/Series/`, `lib/utils/series_segmenter.dart`, `functions/src/change/conditions.js` | `contracts/vectors/series-break.v1.json` | DF-216, DF-309 |
| 4상태 판정 | `functions/src/change/evaluateChangeCore.js` | `contracts/vectors/change-eval.v1.json` | DF-380, DF-381 |
| 신체조성 파싱·검증·BMI·timeOfDayBand | `Sources/TrainerDomain/BodyComposition/` | `contracts/fixtures/body/*.json` | DF-127, DF-128 |
| 줄자 반복·평균 | `Sources/TrainerDomain/Circumference/` | `contracts/fixtures/body/*.json` | DF-129 |
| O 후보 선택·스냅샷·확정 요건 | `Sources/TrainerDomain/Objective/`, `Sources/TrainerDomain/Soap/FinalizeRequirements.swift` | — | DF-122, DF-217 |
| 결과 패키지 검증 | BodyPath 저장소 `packages/BodyPathCore/Sources/BodyPathResult/` | `packages/BodyPathCore/Tests/BodyPathResultTests/Fixtures/` | DF-300, DF-320 |
| ICC·SEM·MDC95 | 소유자 실행 분석(도구는 ASM-09-20) | [§16.6](#166-검증용-예제-벡터) 예제 | DF-939 |
| 금지어 매칭 | `tool/lint/prohibited-terms.mjs`, `functions/src/summaries/prohibitedTerms.js`, `Sources/TrainerDomain/Copy/ProhibitedTermMatcher.swift` | `contracts/fixtures/prohibited-terms/*.json`(ASM-09-24) | DF-010, DF-120, DF-309 |
| elapsed_band·count band | `Sources/TrainerAnalytics/Bands.swift` | 단위 테스트 | DF-126 |

### 1.3 공통 수치 규약

**반올림(정본).** 모든 저장값·Δ 계산은 '0에서 먼 쪽 반올림'(half away from zero)이다(ASM-P1b-03 채택). 세 플랫폼이 IEEE 754 double에서 **같은 연산 순서**로 계산해 결과가 비트 단위로 같게 한다. 보정용 epsilon을 더하지 않는다(더하면 플랫폼별로 결과가 달라질 수 있다). 기존 `round(value, digits)`(dfet:functions/src/clinical/normalization.js:6-9)는 `Number.EPSILON`을 더하는 다른 규칙이므로 판정 코드에서 재사용하지 않는다.

```
roundHalfAway(v, d):  f = 10^d;  return sign(v) * round(|v| * f) / f     // round = 가장 가까운 정수, .5는 위로(양수 입력)
scaled(v, d):         f = 10^d;  return sign(v) * round(|v| * f)          // 정수(스케일 단위)
```

| 언어 | 구현 |
|---|---|
| Swift | `let f = pow(10.0, Double(d)); return (abs(v) * f).rounded(.toNearestOrAwayFromZero) / f * (v < 0 ? -1 : 1)` |
| Dart | `final f = math.pow(10, d); return (v.abs() * f).round() / f * v.sign` (`double.round()`는 half away from zero) |
| JS | `const f = 10 ** d; return Math.sign(v) * Math.round(Math.abs(v) * f) / f` (`Math.round`는 양수에서 .5를 올린다) |

- 경계 사례 벡터에는 이진수로 정확히 표현되는 값만 쓴다(2.25 → 2.3, −2.25 → −2.3). 2.85처럼 표현이 부정확한 값은 벡터 경계 사례로 쓰지 않는다(AC-DF-201 PM-11).
- `-0.0`은 저장 전에 `0.0`으로 바꾼다(`v == 0 ? 0 : v`).

**정밀도(저장·Δ 계산 단위).** 카탈로그(`contracts/metric-catalog.v1.json`)에 `decimals` 필드로 둔다(ASM-09-01).

| metricCode 계열 | 단위 | decimals | 근거 |
|---|---|---|---|
| 자세 4종 | deg | 1 | F-ASM-03.6, §7.5 |
| `weightKg`, `skeletalMuscleMassKg`, `bodyFatMassKg`, `segmentalLeanMassKg` | kg | 1 | §7.5 |
| `bodyFatPercent` | % | 1 | §7.5 |
| `bmi` | kg/m² | 1 | ASM-09-01 |
| `visceralFatLevel` | level | 1 | ASM-09-01(기기 표기 0.5 단계 수용) |
| `totalBodyWaterL` | L | 1 | ASM-09-01 |
| `phaseAngleDeg` | deg | 1 | V2 |
| 둘레 6종 | cm | 1 | F-ASM-06.5 |
| `painNrs` | 점 | 0 | §7.5(NRS 정수) |
| `romDeg` | deg | 0 | ASM-09-19 |
| `mmtGrade` | grade | 0 | §9.3(0–5 정수) |

- 표의 단위 열은 읽기용이다. 문서·contracts에 저장하는 단위 코드는 ASCII(`deg`, `kg`, `percent`, `kgPerM2`, `level`, `liter`, `cm`, `point`, `grade`)를 따른다(DF-003 ASM-P0-02).

**스케일 정수 비교.** Δ와 MDC 비교는 부동소수 뺄셈 결과로 하지 않는다. `aS = scaled(a,d)`, `bS = scaled(b,d)`, `ΔS = aS − bS`(정수), `Δ = ΔS / 10^d`. MDC 비교는 `|ΔS| < mdcValue × 10^d − 1e-9`이면 오차 범위 안이다. 이 규칙이 필요한 이유: 30.3 → 35.8의 부동소수 차는 5.4999999999999964라서 MDC 5.5와 비교가 틀어진다([§9.7](#97-테스트-벡터) T38).

**평균.** 줄자 반복값 평균 등은 스케일 정수 합을 개수로 나눈 뒤 반올림한다: `meanS = roundHalfAway(Σ scaled(x_i,d) / n, 0)`, `mean = meanS / 10^d`. 예: [82.2, 80.9, 81.5] → (822+809+815)/3 = 815.33… → 815 → 81.5.

**시간대.** '같은 날', `timeOfDayBand`, 달력 경계는 `Asia/Seoul`(UTC+9, 일광절약시간 없음)로 계산한다(ASM-P1b-23 채택, ASM-09-02). 기기 시간대 설정에 의존하지 않는다: Swift `TimeZone(identifier: "Asia/Seoul")!`, Dart `DateTime.toUtc().add(const Duration(hours: 9))`, JS `Date` UTC 값 + 9h.

**각도 단위.** 저장·표시는 도(deg). 내부 삼각함수는 라디안. `deg = rad × 180 / π`.

---

## 2 이미지 좌표계와 방향

### 2.1 좌표 프레임 사슬

```
[센서 버퍼]  --(촬영 방향: AVCaptureDevice.RotationCoordinator)-->  [EXIF 방향이 붙은 사진]
     --(§2.2 방향을 픽셀에 적용, orientation=1로 재인코딩)-->  [정립 이미지 W×H]  <- 모든 좌표의 기준
     --(x = px/W, y = py/H)-->  [정규화 좌표 (x,y) ∈ [0,1]², 원점 왼쪽 위, x 오른쪽+, y 아래+]  <- Firestore 저장값
     --(§2.4 px = x·W, py = y·H)-->  [픽셀 좌표]
     --(§2.4 이미지 중심 기준 imageRotationDeg 회전)-->  [수평 보정 좌표]  <- 지표 산식 입력
```

- 저장 좌표는 **정립 이미지 기준 정규화 좌표, 수평 보정 전 값**이다(PRD §9.2 랜드마크 좌표 규약, F-ASM-02.5).
- 지표는 반드시 **픽셀 좌표로 바꾼 뒤** 계산한다. 정규화 좌표로 각도를 재면 W≠H일 때 틀린다(AC-ASM-03.4). 예: 1600×1200에서 C7(800,600)·이주(900,480)px → 픽셀 CVA 50.2°, 정규화 좌표를 그대로 쓰면 58.0°.
- 픽셀 변환에는 정립 이미지의 폭·높이가 필요하다. 문서만으로 재계산(AC-ASM-02.5)이 가능하도록 `views[].imageWidthPx`, `views[].imageHeightPx`를 저장할 것을 제안한다(ASM-09-04, [§20](#20-prd스파인다른-문서와의-충돌과-명확화) C-09-01). 채택 전에는 로컬 사진 파일의 크기를 쓴다.

### 2.2 EXIF 방향 정규화

1. `AVCapturePhoto.fileDataRepresentation()`을 `CGImageSourceCreateWithData`로 연다.
2. `CGImageSourceCreateThumbnailAtIndex`에 `kCGImageSourceCreateThumbnailWithTransform: true`, `kCGImageSourceCreateThumbnailFromImageAlways: true`, `kCGImageSourceThumbnailMaxPixelSize: 4032`를 주어 **방향이 적용된 CGImage**를 얻는다. 긴 변이 4032 이하로 줄어도 가로세로 비율은 유지되므로 정규화 좌표는 변하지 않는다.
3. 이 CGImage를 [§15.1](#151-exif-제거와-재인코딩) 규칙으로 `orientation=1` JPEG로 다시 쓴다. 이후 Vision·오버레이·지표·썸네일은 모두 이 정립 이미지 하나를 기준으로 한다.
4. Vision 요청은 정립 이미지에 `orientation: .up`으로 실행한다. 원본 버퍼에 EXIF 방향을 넘겨 실행하지 않는다(좌표 프레임이 둘로 갈라진다).

### 2.3 기기 roll·pitch 계산

입력은 `CMMotionManager.deviceMotion.gravity`(단위 g, 기기 좌표: x 오른쪽, y 위(세로 방향 기준), z 화면에서 사용자 쪽)다. 30Hz로 읽는다(DF-204).

**① 중력을 이미지 축으로 옮긴다.** 이미지 축은 u(오른쪽+), v(아래+)다. 촬영 시점의 인터페이스 방향(기기 상단이 향한 방향)에 따라:

| 기기 상단 방향(사용자 시점) | `UIInterfaceOrientation` | g_img = (g_u, g_v) |
|---|---|---|
| 위(세로) | `.portrait` | ( g.x, −g.y) |
| 아래(세로 뒤집힘) | `.portraitUpsideDown` | (−g.x,  g.y) |
| 왼쪽(반시계 90°) | `.landscapeRight` | (−g.y, −g.x) |
| 오른쪽(시계 90°) | `.landscapeLeft` | ( g.y,  g.x) |

(검산: 기기를 똑바로 세우면 어느 행이든 g_img = (0, 1), 즉 이미지 아래쪽이다. `UIInterfaceOrientation.landscapeRight`는 기기 상단이 왼쪽을 향하는 방향이다.)

**② roll.** `levelDeg = atan2(g_u, g_v) × 180/π`. 화면에서 중력이 이미지 아래 축에서 **반시계로** 돌아간 각이다(오른쪽 아래로 기울면 양수). 범위 (−180, 180].

**③ pitch.** 후면 카메라 광축은 기기 −z다. `pitchDeg = asin(clamp(g.z, −1, 1)) × 180/π`. 광축이 수평보다 위를 보면 양수, 아래를 보면 음수다. 기기를 똑바로 세우면 0이다.

**④ 수평 보정각.** `imageRotationDeg = −levelDeg`(반시계 양수, PRD §9.2). 즉 중력이 오른쪽으로 r° 기울어 보이면 이미지를 시계 방향으로 r° 돌려 바로 세운다.

**⑤ 기록.**
- 뷰마다 셔터 시점의 `levelDeg`로 `views[].imageRotationDeg`를 저장한다(소수 첫째 자리로 반올림, 산식에는 반올림한 값을 쓴다. AC-ASM-02.5 재계산 동치를 위해).
- 문서 `captureConditions.levelDeg`, `captureConditions.pitchDeg`는 세션 대표값이다. 두 뷰 가운데 **절댓값이 큰 쪽**을 기록한다(보수적 기록, ASM-09-05).

**합성 수평선 테스트(ASM-P1b-02 고정용).** `levelDeg=+2`이면 이미지에서 수평인 세계 선분의 방향은 (cos2°, −sin2°)다. 2000×2000에서 A(500, 1000), B(1499.391, 965.101)을 `imageRotationDeg=−2`로 회전하면 A'(500.305, 982.550), B'(1500.305, 982.550)으로 y가 같아진다(수평). 이 사례를 `level-gate.v1.json` LG-05로 둔다.

### 2.4 픽셀 변환과 회전 보정

```
toPixel(p, W, H)                = (p.x · W, p.y · H)
rotateAboutCenter(q, θ°, W, H)  : cx = W/2, cy = H/2, dx = q.x − cx, dy = q.y − cy, t = θ·π/180
                                  x' = cx + dx·cos t + dy·sin t
                                  y' = cy − dx·sin t + dy·cos t          // y 아래 좌표계에서 화면 반시계가 양수
```

- 검산: 중심 오른쪽 점(dx=1, dy=0)을 +90° 돌리면 (0, −1), 즉 위로 간다(화면 반시계).
- 각도 지표는 평행 이동에 불변이므로 회전 중심은 결과에 영향이 없다. 오버레이 그리기(F-VIZ-02.1)에는 같은 중심을 쓴다.
- 회전 동치(AC-ASM-03.2): 똑바른 좌표 Q를 −2° 돌려 만든 P를 `imageRotationDeg=+2`로 계산하면 Q를 0°로 계산한 결과와 같다. 2000×2000에서 Q의 이주 (1100, 900) → P의 이주 (1103.429, 903.551), 정규화 (0.5517145, 0.4517754). P를 회전 없이 계산하면 43.0°가 나와 회전 누락 회귀를 잡는다.

### 2.5 Vision 좌표 변환

- `VNRecognizedPoint.location`은 **왼쪽 아래 원점, y 위로 증가**하는 정규화 좌표다. 저장 규약으로 바꿀 때 `x = location.x`, `y = 1 − location.y`.
- 정립 이미지에 `.up`으로 실행했을 때만 이 변환이 맞다([§2.2](#22-exif-방향-정규화) 4번).

### 2.6 뷰와 해부학적 좌우

| view | 정의 | 이미지에서 보이는 배치 | 쓰는 랜드마크 |
|---|---|---|---|
| `front` | 대상자가 카메라를 정면으로 봄 | 대상자 **오른쪽**이 이미지 **왼쪽**, 왼쪽이 오른쪽(F-ASM-02.7) | `earLeft/Right`, `acromionLeft/Right`, `asisLeft/Right` |
| `sagittalLeft` | 대상자 **왼쪽 옆면**이 카메라를 향함(ASM-P1b-01) | 얼굴이 이미지 **왼쪽**을 향함 → 이주가 C7보다 이미지 왼쪽 | `tragusLeft`, `c7` |
| `sagittalRight` | 대상자 오른쪽 옆면이 카메라를 향함 | 얼굴이 이미지 오른쪽을 향함 → 이주가 C7보다 이미지 오른쪽 | `tragusRight`, `c7` |

- 랜드마크 코드의 좌우 접미사는 항상 **대상자 기준**이다. 이미지 좌우와 섞지 않는다.
- 측면 방향은 첫 기준선에서 정하고 이후 기본값으로 둔다(F-ASM-01.1). 방향이 다르면 판정 불가(`conditionMismatch`, [§8](#8-조건-키seriesbreakserieskey)).

---

## 3 촬영 프로토콜 파라미터와 셔터 게이트

### 3.1 `contracts/posture-protocol.v1.json`

프로토콜 수치는 코드에 하드코딩하지 않고 이 파일에서 생성한다(ASM-P1b-05). 값은 DF-915(소유자)가 확정하고, 그 전에는 `status: "draft-until-DF-915"`인 기본값으로 개발한다. 값을 바꾸면 `protocolVersion`을 올린다(F-ASM-01.2).

```json
{
  "protocolVersion": "posture-v1",
  "status": "draft-until-DF-915",
  "shutterGate": {
    "rollAbsMaxDeg": 1.0,
    "pitchAbsMaxDeg": 2.0
  },
  "station": {
    "cameraHeightCm": {"min": 90, "max": 110},
    "cameraDistanceM": {"min": 2.5, "max": 3.5}
  },
  "clothingOptions": ["fitted", "regular", "unknown"],
  "landmarkSet": {
    "front": ["earLeft", "earRight", "acromionLeft", "acromionRight", "asisLeft", "asisRight"],
    "sagittalLeft": ["tragusLeft", "c7"],
    "sagittalRight": ["tragusRight", "c7"]
  },
  "headTiltPair": "ear",
  "suggestionMinConfidence": 0.3,
  "advisory": {
    "lightingGoodMin": 0.5,
    "lightingVeryDarkMax": 0.3
  }
}
```

- `clothingOptions`는 V1-05 ASM-05-04와 같다. `unknown`은 어떤 값과도 일치하지 않는다([§8.2](#82-조건-비교-함수)).
- `headTiltPair: "ear"`는 F-ASM-03.4 고정이다. 눈 쌍으로 바꾸려면 `protocolVersion`을 올린다.

### 3.2 셔터 게이트

셔터를 막는 조건은 PRD가 정한 세 가지뿐이다(AC-ASM-01.2, F-ASM-01.5).

```swift
// Sources/TrainerDomain/Posture/ShutterGate.swift
public enum ShutterBlockReason: Equatable, Sendable {
  case consentMissing([ConsentType])        // ②·③ 중 없는 것(F-ASM-01.5). TR-14 링크
  case consentAwaitingServer                // 로컬 캡처만 있고 서버 확인 전(F-PRIV-03.7)
  case checklistIncomplete([ChecklistItem]) // 4항목(F-ASM-01.3)
  case rollOutOfRange(Double)               // |levelDeg| > rollAbsMaxDeg
  case pitchOutOfRange(Double)              // |pitchDeg| > pitchAbsMaxDeg
  case levelUnavailable                     // 모션 값 없음(시뮬레이터·센서 오류): 실패 시 닫힘
}
public struct ShutterGate {
  public static func evaluate(consent: ConsentState, checklist: CaptureChecklist,
                              level: LevelReading?, protocol p: PostureProtocolV1) -> [ShutterBlockReason] {
    var r: [ShutterBlockReason] = []
    let missing = [ConsentType.healthData, .bodyImaging].filter { !consent.isServerConfirmedGranted($0) }
    if consent.hasOnlyLocalCapture { r.append(.consentAwaitingServer) } else if !missing.isEmpty { r.append(.consentMissing(missing)) }
    let unchecked = checklist.uncheckedItems; if !unchecked.isEmpty { r.append(.checklistIncomplete(unchecked)) }
    guard let level else { r.append(.levelUnavailable); return r }
    if abs(level.levelDeg) > p.shutterGate.rollAbsMaxDeg { r.append(.rollOutOfRange(level.levelDeg)) }
    if abs(level.pitchDeg) > p.shutterGate.pitchAbsMaxDeg { r.append(.pitchOutOfRange(level.pitchDeg)) }
    return r   // 빈 배열일 때만 셔터 활성
  }
}
```

- 경계: `|levelDeg| = 1.0`은 허용, `1.05`는 거부(비교는 반올림 전 원값).
- `levelUnavailable`로 막는 것은 PRD의 '허용 범위 밖이면 비활성'을 값이 없을 때도 안전하게 적용한 것이다(ASM-09-06). 시뮬레이터 UI 테스트는 `--preview-state`로 `LevelReading`을 주입한다.

### 3.3 안내 전용 판정(셔터를 막지 않음)

| 항목 | 계산 | 표시 | 근거 |
|---|---|---|---|
| 인물 수 | 미리보기 프레임 2~5fps 샘플에 `VNDetectHumanRectanglesRequest(upperBodyOnly=false)`. `count == 1`이면 정상 | 0명: '사람을 찾지 못했어요', 2명 이상: '한 사람만 화면에 들어오게 해 주세요'(`tr07.detect.personCount`) | F-ASM-01.4 |
| 조명 | Y 평면 평균 밝기 L(0~255, 50픽셀 간격 샘플)을 품질 q로 사상: L<50 → 0.3·L/50, 50≤L<100 → 0.3+0.3·(L−50)/50, 100≤L<180 → 0.6+0.3·(L−100)/80, L≥180 → 0.9+0.1·min(L−180,75)/75. q<0.3 '조명이 너무 어두워요', q<0.5 '조명이 어두워요' | `tr07.detect.lowLight` | 개념 출처 dfet:lib/services/pose_detection_service.dart:166-202, 임계 :329, :336 |
| 전신 프레이밍 | 인물 사각형이 이미지 안쪽 여백 2% 안에 모두 들어오면 정상 | '머리부터 발까지 화면에 들어오게 해 주세요' | F-ASM-01.4 |

- 계산이 실패하면 '확인 불가'로 표시한다. 회원 앱은 실패 시 조명을 정상(1.0)으로 가정하는데(dfet:lib/services/pose_detection_service.dart:204-205) 트레이너 앱은 이 반례를 따르지 않는다.
- 이 값들은 문서에 저장하지 않는다(분석 이벤트 속성도 아님).

### 3.4 `captureConditions` 구성

| 키 | 값 출처 |
|---|---|
| `clothing` | 체크리스트 복장 선택(`fitted`/`regular`/`unknown`) |
| `barefoot`, `markersPlaced`, `verbalConsentCheck` | 체크리스트 토글(셔터 시점에 모두 true여야 촬영 가능) |
| `cameraHeightCm`, `cameraDistanceM` | 선택한 `StationProfile` 값(프로필 저장 때 [§3.1](#31-contractsposture-protocolv1json) 범위 검사, DF-203) |
| `levelDeg`, `pitchDeg` | [§2.3](#23-기기-rollpitch-계산) ⑤ 세션 대표값(소수 첫째 자리) |

---

## 4 랜드마크 집합·출처·확정 규칙

### 4.1 랜드마크 표

부록 A.3를 구현 수준으로 옮긴 표다. 코드를 바꾸면 `protocolVersion`을 올린다.

| code | view | 해부학 정의 | 자동 제안 원천(Apple Vision 2D) | 마커 | manualRequired | 쓰는 지표 |
|---|---|---|---|---|---|---|
| `tragusLeft` | `sagittalLeft` | 왼쪽 이주 | `.leftEar`(초기 위치) | 없음 | 아니요(확정 필수) | `craniovertebralAngle` |
| `tragusRight` | `sagittalRight` | 오른쪽 이주 | `.rightEar`(초기 위치) | 없음 | 아니요(확정 필수) | `craniovertebralAngle` |
| `c7` | 측면 둘 다 | 제7경추 극돌기 | 없음(`.neck`은 C7이 아니다, F-ASM-02.2) | 촉지 후 스티커 | **예** | `craniovertebralAngle` |
| `earLeft` / `earRight` | `front` | 귀(이주 높이) | `.leftEar` / `.rightEar` | 없음 | 아니요(확정 필수) | `headTiltFrontal` |
| `acromionLeft` / `acromionRight` | `front` | 견봉 | `.leftShoulder` / `.rightShoulder`(초기 위치만) | 권장(프로토콜 v1 결정) | **예** | `shoulderTiltAngle` |
| `asisLeft` / `asisRight` | `front` | 위앞엉덩뼈가시 | 없음 | 촉지 후 스티커 | **예** | `pelvicTiltFrontal` |

지표별 필수 집합(`LandmarkRequirements`):

| metricCode | 필수 랜드마크 | 기본 활성 |
|---|---|---|
| `craniovertebralAngle` | 측면 view의 `tragus{Side}` + `c7` | 예 |
| `headTiltFrontal` | `earLeft`, `earRight` | 예(참고 지표) |
| `shoulderTiltAngle` | `acromionLeft`, `acromionRight` | 예 |
| `pelvicTiltFrontal` | `asisLeft`, `asisRight` | **아니요**(`MetricOptions.includePelvicTilt`, AC-ASM-03.6) |

### 4.2 자동 제안 어댑터(PostureVision)

```swift
// Sources/PostureVision/Landmarks/LandmarkSuggester.swift
public struct LandmarkEngine: Codable, Equatable, Sendable { public var name: String; public var version: String }
public struct LandmarkSuggestion: Equatable, Sendable { public var code: LandmarkCode; public var point: NormalizedPoint; public var confidence: Double }
public protocol LandmarkSuggester: Sendable {
  var engine: LandmarkEngine { get }                                   // {name:"appleVision2D", version:"iOS17.4-r1"}(ASM-P1b-04)
  func suggest(image: CGImage, view: PostureView) async throws -> [LandmarkSuggestion]
}
```

`VisionLandmarkSuggester` 알고리즘:

1. 정립 이미지에 `VNDetectHumanBodyPoseRequest`(리비전은 `engine.version`의 `r` 값으로 고정)를 `.up`으로 실행한다.
2. 관찰이 0개면 빈 배열(수동 지정은 항상 가능, F-ASM-02.6). 2개 이상이면 경계 상자 면적이 가장 큰 관찰 하나만 쓴다.
3. [§4.1](#41-랜드마크-표) 원천 관절을 `recognizedPoint(_:)`로 읽고 `confidence < suggestionMinConfidence(0.3)`이면 버린다(ASM-P1b-33).
4. 좌표를 `x = location.x`, `y = 1 − location.y`로 바꾼다([§2.5](#25-vision-좌표-변환)).
5. **좌우 확인(front):** `leftShoulder.x > rightShoulder.x`(또는 어깨가 없으면 귀 쌍)가 아니면 대상자가 뒤돌아섰거나 매핑이 뒤집힌 것이다. 이때 front 제안을 모두 버리고 '정면을 보고 섰는지 확인해 주세요'를 표시한다.
6. **측면:** `sagittalLeft`는 `.leftEar`만, `sagittalRight`는 `.rightEar`만 쓴다. 반대쪽 귀는 가려진 쪽이므로 쓰지 않는다.
7. Vision 관절 이름의 left/right는 **대상자 기준**이라고 가정한다(ASM-09-07). AC-ASM-02.3 합성 이미지(대상자 오른쪽 어깨 표시)에서 `acromionRight` 제안이 이미지 왼쪽 절반에 놓이는지로 고정하고, 반대로 나오면 매핑 표의 좌우를 바꾼다.

### 4.3 랜드마크 상태 전이

저장 원소는 `{code, x, y, origin: auto|manual, confirmed, suggested?: {x, y, confidence}}`다(PRD §9.2).

| 동작 | 전제 | 결과 |
|---|---|---|
| 제안 배치 | 제안 있음 | `origin=auto`, `confirmed=false`, 좌표=제안, `suggested={제안 x, y, confidence}`(ASM-09-08) |
| 핀 이동(드래그·1px 방향 버튼) | — | 좌표 갱신, `origin=manual`, `confirmed=false`. `suggested`는 그대로 둔다 |
| '이 위치로 지정' | — | 좌표 유지, `origin=manual`, `confirmed=false` |
| 수동 배치(빈 슬롯 탭) | — | `origin=manual`, `confirmed=false`, `suggested` 없음 |
| '확정' | `code ∉ manualRequired` 또는 `origin == manual` | `confirmed=true` |
| 확정 해제·되돌리기 | — | 직전 상태 복원(되돌리기 스택, 화면당 50단계) |

- 1px 방향 버튼의 이동량은 정립 이미지 픽셀 1개다(`Δx = 1/W`, `Δy = 1/H`). 화면 확대율과 무관하다(F-VIZ-02.8).
- 확정 후 핀을 옮기면 `confirmed=false`로 돌아간다(재확정 필요).
- auto이면서 확정된 이주·귀는 '확정'(속 찬 원), manual 확정은 '수동 확정'(속 찬 원+핀)으로 그린다(F-VIZ-02.2). 모양 사상은 [V1-07](07_TRAINER_APP_SPEC.md) TR-08.

### 4.4 확정 가능성(`Confirmability`)

```
confirmability(views, options):
  missing = [], blocking = []
  require views에 front와 (sagittalLeft 또는 sagittalRight) 정확히 하나                  // F-ASM-01.1
  for metric in activeMetrics(options):                                                  // 골반은 options가 켤 때만
     req = LandmarkRequirements[metric](sagittalSide)
     present = req 중 문서에 있는 것
     if metric == pelvicTiltFrontal and present.isEmpty: continue                        // 미산출 허용(F-ASM-04.2)
     for code in req:
        lm = landmark(code)
        if lm == nil: missing.append(code)                                               // '지정 필요'
        else if code ∈ manualRequired and lm.origin == auto: blocking.append(code)       // AC-ASM-02.1
        else if lm.confirmed == false: blocking.append(code)
  blocking += geometryBlockers(views)                                                    // §5.8 V-POS-03~05, 07
  canConfirm = missing.isEmpty and blocking.isEmpty
```

- 골반을 켰고 ASIS를 **하나라도 놓았으면** 두 점 모두 유효해야 확정할 수 있다(AC-DF-201.7과 같음). 하나도 놓지 않았으면 골반만 미산출이다(0 아님).
- 이 판단은 클라이언트 신뢰 경계 안의 판단이다(AS-30). 서버 재검증은 P2 `verifyPostureConfirmed`가 같은 규칙을 JS로 다시 적용한다(DF-324). 그때 쓰는 JS 구현은 이 의사코드와 `posture-metrics.v1.json`의 `confirmability` 사례를 공유한다.

---

## 5 자세 지표 산식

### 5.1 공통 전처리

1. 입력: `view`, 정립 이미지 크기 `W×H`, `imageRotationDeg θ`(소수 첫째 자리), 랜드마크 배열, `MetricOptions`.
2. 좌표 범위 검사: 모든 `x, y ∈ [0, 1]`(닫힌 구간). 밖이면 `coordinateOutOfRange(code)`로 계산 전체를 거부한다(AC-ASM-02.4).
3. `p_px = toPixel(p)` → `p' = rotateAboutCenter(p_px, θ)`([§2.4](#24-픽셀-변환과-회전-보정)).
4. 보정 후 픽셀 좌표는 y가 아래로 증가하므로 '위쪽 양수' 계산에는 −Δy를 쓴다(F-ASM-03.3).
5. 결과 각도는 `roundHalfAway(·, 1)`로 저장한다(F-ASM-03.6). 산식 중간값은 반올림하지 않는다.

### 5.2 두개척추각(`craniovertebralAngle`, 측면)

```
            T (이주 tragus, 보정 후 픽셀)
            *
           /|
          / |   h = −v.y   (위쪽 양수)
         /  |
        / θ |
   C7  *----+-----------> 수평선(보정 후 +x 또는 −x, 얼굴 방향과 무관)
        |v.x|

   v = T − C7          CVA = atan2(−v.y, |v.x|) × 180/π      범위 (−90°, 90°]
```

- `|v.x|`를 쓰므로 `sagittalLeft`와 `sagittalRight`가 같은 식이다. 이주가 C7보다 아래면 음수(PM-05: C7(1000,1000)·이주(1100,1050) → −26.6°).
- `side`는 항상 `none`(방향은 view가 가진다, 부록 A.1).
- `|v| < 1px`이면 계산하지 않고 `degenerateGeometry(craniovertebralAngle)`(V-POS-03).
- `v.x = 0`, `v.y < 0`이면 90.0°다(atan2 정의).

### 5.3 머리 기울기(`headTiltFrontal`, 정면, 참고)

```
   이미지 왼쪽 = 대상자 오른쪽                 이미지 오른쪽 = 대상자 왼쪽
        earRight *
                  \  θ
                   \______________ 수평선
                    `-- earLeft *
   Δx = earLeft'.x − earRight'.x,  Δy = earLeft'.y − earRight'.y
   θ = atan(|Δy| / |Δx|) × 180/π,  side = y가 더 큰 쪽(더 낮은 귀)의 해부학적 좌우
```

- `reliabilityTier=reference`라서 어떤 정책 상태에서도 판정·배지가 없다(§7.2, AC-VIZ-01.2).
- 귀 쌍 고정(F-ASM-03.4). 눈 쌍으로 바꾸려면 `protocolVersion`을 올린다.

### 5.4 어깨 높이차(`shoulderTiltAngle`, 정면)

- `θ = atan(|Δy| / |Δx|)`, 견봉 쌍 기준, `side` = 보정 후 y가 **작은** 쪽(더 높은 어깨)의 해부학적 좌우.
- 벡터(AC-ASM-03.1): 2000×2000, 견봉 좌(1200,800)·우(800,820)px → atan(20/400) = 2.862° → **2.9°, side=left**.

**픽셀·길이 환산 정책(v1).**
- 저장·표시·판정하는 값은 **각도(deg)뿐**이다. 부록 A.1은 cm 높이차를 제외했다.
- 픽셀 높이차 `|Δy|`는 계산 중간값일 뿐이며 문서, 화면, 분석 이벤트에 내보내지 않는다.
- 사진에는 물리 스케일 기준이 없으므로 mm·cm 환산을 하지 않는다. `headForwardDistance`가 제외된 이유와 같다(부록 A.4).
- 향후 스케일 기준(예: 알려진 길이의 보정 마커)을 도입하려면 부록 A에 새 metricCode를 먼저 올리고 `protocolVersion`을 올린다. v1 코드에는 환산 함수를 두지 않는다.
- 각도는 카메라 거리와 무관하지만, 카메라 roll은 그대로 각도 오차가 된다. 그래서 [§2.3](#23-기기-rollpitch-계산) 수평 보정과 [§3.2](#32-셔터-게이트) roll 게이트가 필수다.

### 5.5 골반 기울기(`pelvicTiltFrontal`, 정면, 참고·기본 꺼짐)

- 식은 어깨와 같고 ASIS 쌍을 쓴다. `side` = 높은 쪽.
- `MetricOptions.includePelvicTilt == false`(기본)이면 계산하지 않고 결과 배열에 넣지 않는다(AC-ASM-03.6).
- 켰는데 ASIS가 하나라도 없으면 결과에 없다(0이 아니고 오류도 아님, F-ASM-04.2).
- `reliabilityTier=reference`: 판정 항상 `referenceMetric`, 배지 없음.

### 5.6 side·부호·1px 규칙

| 규칙 | 내용 | 근거 |
|---|---|---|
| 1px 미만 | 보정 후 `|Δy| < 1.0` px이면 값 `0.0`, `side=none` | F-ASM-03.4 |
| 반올림 0 | 반올림한 값이 `0.0`이면 `side=none` | V1-05 ASM-05-19 |
| 좌우 | 해부학적 좌우(코드 접미사). 이미지 좌우를 쓰지 않는다 | F-ASM-02.7 |
| 추이 부호 | 기울기 지표는 `signed = value × (+1 right, −1 left, 0 none)`로 한 선을 그린다(ASM-P1b-17) | F-ASM-03.4 '오른쪽=+' |
| 판정 | 크기(`value`)로 한다. 측면이 바뀌면 `sideChanged=true`를 따로 표시 | §7.5, T20 |

### 5.7 출처 등급 할당

```
for metric in computed:
   sourceGrade = all(requiredLandmarks(metric).map { $0.confirmed }) ? .photoManual : .photoAuto
```

- 지표마다 따로 정한다(AC-ASM-03.3: 견봉 하나가 미확정이면 어깨만 `photoAuto`).
- 확정(`status=confirmed`) 문서는 확정 전제상 모든 지표가 `photoManual`이다(ASM-P1b-07). `photoAuto`는 draft 미리보기('확정 전', '스크리닝' 칩)에만 나타난다.
- draft 동안 지표는 화면에서 계산만 하고 문서에는 확정 때 저장한다(ASM-P1b-06).

### 5.8 입력 검증과 경고

| ID | 조건 | 처리 | 분류 |
|---|---|---|---|
| V-POS-01 | 좌표가 [0,1] 밖 | `PostureMathError.coordinateOutOfRange(code)`, 계산 거부 | 거부 |
| V-POS-02 | `W ≤ 0` 또는 `H ≤ 0` | `PostureMathError.zeroImageSize` | 거부 |
| V-POS-03 | CVA `|v| < 1px`, 쌍 지표 `|Δx| < 1px` | 해당 지표 미계산 + 확정 차단 `degenerateGeometry(metric)` | 확정 차단 |
| V-POS-04 | 정면 쌍의 `|Δx| < 0.02·W` | 확정 차단 `pairTooClose(metric)` '두 점이 너무 가까워요'(ASM-09-10) | 확정 차단 |
| V-POS-05 | 정면 쌍에서 `x'(Left) ≤ x'(Right)` | 확정 차단 `sidesSwapped(metric)` '좌우가 바뀐 것 같아요' | 확정 차단 |
| V-POS-06 | `sagittalLeft`인데 이주 x' ≥ C7 x'(`sagittalRight`는 반대) | 경고 W-POS-01 '측면 방향을 확인해 주세요', 트레이너 확인 뒤 진행 | 경고 |
| V-POS-07 | view에 속하지 않는 코드(`sagittalLeft`에 `tragusRight` 등) | 저장 거부 `landmarkNotInView(code)` | 거부 |
| W-POS-02 | CVA ∉ [10°, 80°] | '값을 다시 확인해 주세요'(ASM-09-11) | 경고 |
| W-POS-03 | 어깨 > 10° | 같음 | 경고 |
| W-POS-04 | 머리 기울기 > 15° | 같음 | 경고 |
| W-POS-05 | 골반 > 10° | 같음 | 경고 |

- 경고는 저장·확정을 막지 않는다. 경고 수치는 제안값이며 규준이 아니다(§7.7 '규준 없음'). 화면에 '정상 범위'로 표시하지 않는다.
- 벡터 러너는 사례에 `expectedWarnings`가 있을 때만 경고를 비교한다(PM-01처럼 이주가 C7 오른쪽에 있는 `sagittalLeft` 사례는 W-POS-01이 나지만 값 검증에는 영향이 없다).

### 5.9 참조 구현(Swift, PostureMath)

```swift
// Sources/PostureMath/Metrics/PostureMetricCalculator.swift
public enum PostureMetricCalculator {
  /// 뷰 하나의 지표를 계산한다(DF-201 시그니처). front → 머리·어깨·(골반), sagittal* → CVA.
  public static func computeMetrics(view: PostureView, imageSize: PixelSize, imageRotationDeg: Double,
                                    landmarks: [LandmarkValue], options: MetricOptions) throws -> [PostureMetricResult] {
    let f = ViewInput(view: view, imageSize: imageSize, imageRotationDeg: imageRotationDeg,
                      landmarks: Dictionary(landmarks.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a }))
    switch view {
    case .sagittalLeft, .sagittalRight:
      let tragusCode: LandmarkCode = (view == .sagittalLeft) ? .tragusLeft : .tragusRight
      guard let t = try f.corrected(tragusCode), let c = try f.corrected(.c7) else { return [] }
      let vx = t.x - c.x, vy = t.y - c.y
      guard (vx * vx + vy * vy).squareRoot() >= 1 else { throw PostureMathError.degenerateGeometry(.craniovertebralAngle) }
      let deg = atan2(-vy, abs(vx)) * 180 / .pi
      return [.init(metricCode: .craniovertebralAngle, value: Rounding.roundTenth(deg), side: .none,
                    sourceGrade: f.grade([tragusCode, .c7]))]
    case .front:
      var out: [PostureMetricResult] = []
      out += try pair(f, .headTiltFrontal, left: .earLeft, right: .earRight, sideIsLower: true)
      out += try pair(f, .shoulderTiltAngle, left: .acromionLeft, right: .acromionRight, sideIsLower: false)
      if options.includePelvicTilt {
        out += try pair(f, .pelvicTiltFrontal, left: .asisLeft, right: .asisRight, sideIsLower: false)
      }
      return out
    }
  }

  private static func pair(_ f: ViewInput, _ metric: MetricCode, left: LandmarkCode, right: LandmarkCode,
                           sideIsLower: Bool) throws -> [PostureMetricResult] {
    guard let l = try f.corrected(left), let r = try f.corrected(right) else { return [] }   // 없으면 미산출
    let dx = l.x - r.x, dy = l.y - r.y
    guard abs(dx) >= 1 else { throw PostureMathError.degenerateGeometry(metric) }
    if abs(dy) < 1 { return [.init(metricCode: metric, value: 0, side: .none, sourceGrade: f.grade([left, right]))] }
    let value = Rounding.roundTenth(atan(abs(dy) / abs(dx)) * 180 / .pi)
    // 보정 후 y가 큰 쪽이 낮다. l.y > r.y 이면 왼쪽이 낮다.
    let leftIsLower = l.y > r.y
    let side: Side = value == 0 ? .none : ((leftIsLower == sideIsLower) ? .left : .right)
    return [.init(metricCode: metric, value: value, side: side, sourceGrade: f.grade([left, right]))]
  }
}

public struct ViewInput {
  public var view: PostureView; public var imageSize: PixelSize; public var imageRotationDeg: Double
  public var landmarks: [LandmarkCode: LandmarkValue]
  func corrected(_ code: LandmarkCode) throws -> CGPoint? {
    guard let lm = landmarks[code] else { return nil }
    guard (0...1).contains(lm.point.x), (0...1).contains(lm.point.y) else { throw PostureMathError.coordinateOutOfRange(code) }
    guard imageSize.width > 0, imageSize.height > 0 else { throw PostureMathError.zeroImageSize }
    let p = PixelGeometry.toPixel(lm.point, in: imageSize)
    return PixelGeometry.rotateAboutCenter(p, degrees: imageRotationDeg, in: imageSize)
  }
  func grade(_ codes: [LandmarkCode]) -> SourceGrade {
    codes.allSatisfy { landmarks[$0]?.confirmed == true } ? .photoManual : .photoAuto
  }
}
```

- `degenerateGeometry`는 `PostureMathError`에 추가하는 case다(DF-201 타입 목록 확장, [§20](#20-prd스파인다른-문서와의-충돌과-명확화) C-09-06). V-POS-04·05는 `Confirmability.blockingReasons`로 돌려주고 계산 자체는 막지 않는다(미리보기에 값이 보이게).
- 같은 입력이면 결과가 비트 단위로 같아야 한다(AC-ASM-02.5). 난수·현재 시각·기기 상태를 쓰지 않는다.

### 5.10 벡터: `contracts/vectors/posture-metrics.v1.json`

형식과 PM-01~PM-03 JSON은 [DF-201 카드](backlog/P1b.md)를 그대로 쓴다. 모든 사례는 합성 좌표다. 좌표는 편의상 픽셀로 적었고 JSON에는 `x = px/W`, `y = py/H`로 넣는다.

| ID | trace | 입력(픽셀, 이미지 크기, θ) | 기대 |
|---|---|---|---|
| PM-01 | AC-ASM-03.1 | `sagittalLeft`, 2000², C7(1000,1000), 이주L(1100,900), θ=0 | CVA 45.0, none, photoManual |
| PM-02 | AC-ASM-03.1 | `front`, 2000², 견봉L(1200,800), 견봉R(800,820) | 어깨 2.9, **left** |
| PM-03 | AC-ASM-03.4 | `sagittalLeft`, 1600×1200, C7(800,600), 이주L(900,480) | CVA 50.2(정규화 좌표 오답 58.0) |
| PM-04 | AC-ASM-03.2 | `sagittalLeft`, 2000², C7(1000,1000), 이주L(1103.429032, 903.550867), **θ=+2** | CVA 45.0(θ 무시 시 43.0) |
| PM-05 | F-ASM-03.3 | C7(1000,1000), 이주L(1100,1050) | CVA **−26.6** |
| PM-06 | F-ASM-03.3 | `front`, 귀L(1150,700), 귀R(850,690) | 머리 기울기 1.9, **left**(낮은 쪽) |
| PM-07 | F-ASM-03.4 | 견봉L(1200,800), 견봉R(800,800.6) | 0.0, none(반올림하면 0.1이지만 1px 규칙 우선) |
| PM-08 | AC-ASM-03.3 | PM-02 + 견봉R `confirmed=false` | 어깨만 photoAuto(CVA 있으면 photoManual) |
| PM-09 | AC-ASM-03.6 | 기본 옵션, ASIS 둘 다 있음 | 골반 결과 없음 |
| PM-10 | F-ASM-04.2 | 골반 켬, ASIS L만 있음 | 골반 결과 없음, 오류 없음 |
| PM-11 | §1.3 | `roundTenth` 직접: 2.25 → 2.3, −2.25 → −2.3, 44.98 → 45.0, 50.52 → 50.5 | 표 값 |
| PM-12 | AC-ASM-03.2 | `front`, 견봉L(1206.858065, 807.101734), 견봉R(806.403744, 813.129752), θ=+2 | 어깨 2.9, left(θ 무시 시 0.9) |
| PM-13 | AC-ASM-03.4 | `front`, 1600×1200, 견봉L(1000,600), 견봉R(600,660) | 어깨 8.5, left(정규화 오답 11.3) |
| PM-14 | V-POS-05 | `front`, 견봉L(800,800), 견봉R(1200,820) | 값 2.9 계산되나 `blockingReasons ∋ sidesSwapped(shoulderTiltAngle)` |
| PM-15 | F-ASM-03.3 | 골반 켬, ASIS L(1150,1300)·R(850,1320) 모두 manual·confirmed | 골반 3.8, left(높은 쪽) |
| PM-16 | ASM-P1b-01 | `sagittalRight`, C7(1000,1000), 이주R(900,900) | CVA 45.0 |
| PM-17 | V-POS-03 | C7(1000,1000), 이주L(1000.3,1000.4) | `degenerateGeometry(craniovertebralAngle)` |
| PM-18 | ASM-05-19 | `front`, 2000², 견봉L(1900,800), 견봉R(100,801.2) | Δy=1.2px(1px 이상) → 0.0382° → 0.0, **none** |
| PM-19 | AC-ASM-02.1 | `c7` `origin=auto, confirmed=false` | `confirmability.canConfirm=false`, `blocking ∋ c7` |
| PM-20 | AC-ASM-02.2 | 제안 없음, 모든 필수 랜드마크 manual·confirmed | `canConfirm=true` |


사례 JSON 예(PM-04):

```json
{
  "id": "PM-04", "trace": ["AC-ASM-03.2"], "view": "sagittalLeft",
  "image": {"width": 2000, "height": 2000}, "imageRotationDeg": 2,
  "options": {"includePelvicTilt": false},
  "landmarks": [
    {"code": "c7", "x": 0.5, "y": 0.5, "origin": "manual", "confirmed": true},
    {"code": "tragusLeft", "x": 0.5517145162, "y": 0.4517754335, "origin": "manual", "confirmed": true}
  ],
  "expected": [{"metricCode": "craniovertebralAngle", "value": 45.0, "unit": "deg", "side": "none", "sourceGrade": "photoManual"}]
}
```

`level-gate.v1.json`(ASM-09-03) 사례:

| ID | 입력 | 기대 |
|---|---|---|
| LG-01 | `.portrait`, g=(0,−1,0) | levelDeg 0.0, pitchDeg 0.0, imageRotationDeg 0.0 |
| LG-02 | `.portrait`, g=(sin2°, −cos2°, 0) | levelDeg +2.0, imageRotationDeg −2.0, 셔터 차단 `rollOutOfRange` |
| LG-03 | `.portrait`, g=(0, −cos1.5°, sin1.5°) | pitchDeg +1.5, 셔터 허용(|1.5| ≤ 2.0) |
| LG-04 | `.landscapeRight`(상단 왼쪽), g=(−1,0,0) | g_img=(0,1), levelDeg 0.0 |
| LG-05 | 수평선 사례([§2.3](#23-기기-rollpitch-계산)) | 보정 후 두 점 y 차 < 1e-6 |
| LG-06 | `level == nil` | `levelUnavailable`로 차단 |
| LG-07 | levelDeg = 1.0 정확히 | 허용 |

---

## 6 체형평가 수명주기 계산 규칙

상태 전이·규칙 코드는 [V1-05 §4.6·§7.5](05_DATA_MODEL_AND_RULES.md)가 정본이다. 여기서는 계산이 필요한 선택 규칙만 둔다.

### 6.1 기준선

- 키: `(memberKey, sagittalView)`. 회원 × 측면 방향마다 `isBaseline=true`인 confirmed 문서는 최대 1개다(F-ASM-04.4, AS-33).
- 첫 확정이면 기준선 토글이 켜진 상태로 제시한다(ASM-P1b-08).
- 기준선 문서를 새 버전으로 대체하면 새 버전이 `isBaseline=true`를 물려받는다(ASM-P1b-09).
- 정면 지표의 기준선: **현재 세션과 같은 측면 방향**의 기준선 세션의 정면 값이다(F-ASM-04.4 '정면 지표는 기준선 세션의 정면 값을 따른다'를 방향이 둘일 때로 확장, ASM-09-12).

### 6.2 추이·비교 후보 필터

```
eligiblePosture(docs):
  docs.filter { $0.status == .confirmed }                                            // draft·voided 제외(AC-ASM-04.4)
      .filter { $0.retestGroupId == nil || isFirstOfRetestGroup($0, docs) }          // F-ASM-05.3
isFirstOfRetestGroup(d, docs):
  g = docs.filter { $0.retestGroupId == d.retestGroupId && $0.status == .confirmed }
  return d == g.min(by: (capturedAt, createdAt, id) 오름차순)                          // ASM-P1b-16
```

- `capturedAt`은 세션의 첫 셔터 시각이다(ASM-P1b-35). 추이 x축은 `capturedAt`(F-ASM-04.6).
- 재검사 묶음 3건 중 추이에는 1건만 나타난다(AC-ASM-05.2).

---

## 7 출처 등급·신뢰 등급·MDC 적용

### 7.1 출처 등급 할당(쓰는 쪽)

| 데이터 | sourceGrade | 할당 주체·시점 | 거부 조건 |
|---|---|---|---|
| 자세 지표 | `photoManual` \| `photoAuto` | PostureMath, 지표별([§5.7](#57-출처-등급-할당)) | 다른 값 |
| 신체조성 `values.*` | `device`(문서 필드 하나) | 앱 고정 | 다른 값 |
| `derived.bmi` | `derived` | 앱 고정 | 다른 값 |
| 줄자 둘레 | `tape` | TR-12 고정 | — |
| LiDAR 둘레 | `observedSection` | TR-13 가져오기 고정 | `lidarBeta=false`이면 생성 불가 |
| `painNrs` | `selfReport` | SOAP S | — |
| `romDeg`, `mmtGrade` | `trainerObserved` | SOAP O 행 | — |
| `modelEstimate`, `aiAppearance` | — | v1에서 **어떤 문서에도 쓰지 않는다** | 쓰기 시도는 도메인 검증에서 거부 |

- 공통 검증: `sourceGrade ∈ catalog[metricCode].allowedSourceGrades`가 아니면 저장하지 않는다(부록 A.2).
- sourceGrade가 없는 수치는 그리거나 불러오지 않는다(C-01, AC-VIZ-07.1, F-SOAP-03.5).
- sourceGrade가 다르면 같은 metricCode라도 다른 시리즈다(§7.1, [§8.3](#83-시리즈-식별자)).

### 7.2 신뢰 등급

- 값은 카탈로그의 metric 수준 속성이다: `tier1`(CVA, 어깨), `reference`(골반, 머리 기울기, `painNrs`), `beta`(관측 단면 둘레 전체, sourceGrade로 판정), 그 밖은 미지정(`null`).
- tier1 기준(정책 제안값, G-08 승인): 문헌의 재검사 ICC와 평가자간 ICC가 **모두 보고되고 둘 다 점추정 0.75 이상**(§7.2). 신뢰구간 하한은 보고만 하고 기준에 쓰지 않는다(ASM-09-15).
- G-06 결과 ICC가 기준에 못 미치면 해당 지표를 `reference`로 내린다. 내리는 방법은 카탈로그 PR(`reliabilityTier` 변경) + 새 정책 버전이다. 이미 저장된 스냅샷은 다시 계산하지 않는다(§7.6).

### 7.3 MDC 적용 결정표

| # | 활성 bodyChange 정책 | 정책 항목(`rule`) | 지표·등급 | 판정 결과 | 트레이너 표시 | 회원 highlight `changeStatus` |
|---|---|---|---|---|---|---|
| 1 | 없음(P3 전 포함) | — | 모든 지표 | `pendingPolicy` | '산정 준비 중' + 수치 | `null` |
| 2 | 있음 | 무관 | `observedSection` | `indeterminate(betaMetric)` | 베타 라벨, 나란히 보기만 | 제외(highlight 없음) |
| 3 | 있음 | 무관 | tier `reference`(골반·머리·NRS) | `indeterminate(referenceMetric)` | '참고 지표 · 판정하지 않음' | `null`(NRS는 highlight 제외) |
| 4 | 있음 | 없음 또는 `mdcValue ≤ 0`, 서열 척도(`mmtGrade`) | 그 밖 | `indeterminate(noMdc)` | 'MDC 미확보 · 변화 판정 불가' | `null` |
| 5 | 있음 | 있음 | `photoAuto`(현재 또는 비교) | `indeterminate(noMdc)` | '스크리닝' + 판정 제외 | 제외 |
| 6 | 있음 | `literature` | `photoManual` 등 | 4상태 | 'MDC ±{값}{단위} · 문헌값, 자체 재검사 전' + `mdcReference` URL | `null`(§7.6) |
| 7 | 있음 | `inHouse`, `rule.protocolVersion == 기록 protocolVersion` | `photoManual` | 4상태 | 'MDC ±{값}{단위} · 자체 재검사 {연구 버전}' | 결과 저장(B.8 문장) |
| 8 | 있음 | `inHouse`, protocolVersion 불일치 | `photoManual` | 4상태(트레이너) | 7과 같음 | `null`(ASM-09-16) |

- 문헌 MDC는 수동 랜드마크 연구 값이므로 `photoManual`에만 적용한다(§7.3.1-3). 5행이 그 구현이다.
- MDC 값은 **활성 정책에서만** 읽는다. 카탈로그·앱·함수 코드에 MDC 숫자를 두지 않는다(§7.3.1-1). 카탈로그의 `literatureNote`는 표시용 문자열이며 계산에 쓰지 않는다(V1-05 §13.1).
- 문헌값 문구가 렌더되지 않으면 밴드도 그리지 않는다(AC-VIZ-03.4). 트레이너 표시 문구 키는 [V1-12](12_COPY_ANALYTICS_AND_LINT.md).

### 7.4 bodyChange 정책 문서 형식

문서 ID `bodyChange--{version}`(기존 `kind--version` 관례, dfet:admin_web/app/api/clinical/config/route.ts:96), 필드는 `config`를 문서 최상위에 펼쳐 저장하는 기존 방식(같은 파일 :122-123)을 따른다. 활성 정책 조회는 기존 `loadActivePolicy(db, 'insightPolicyVersions', 'bodyChange')`(dfet:functions/src/clinical/ingestion.js:104-114)를 재사용한다.

```json
{
  "kind": "bodyChange",
  "version": "bodyChange-draft-1",
  "status": "approved",
  "active": true,
  "approvedBy": "synthAdmin",
  "publishedAt": "<serverTimestamp>",
  "metrics": {
    "craniovertebralAngle": {
      "mdcValue": 5.52,
      "mdcSource": "literature",
      "mdcReference": "https://www.mdpi.com/1660-4601/17/18/6521",
      "protocolVersion": "posture-v1",
      "improvementDirection": "higherIsBetter",
      "conditionKeys": ["protocolVersion", "view", "captureConditions.clothing", "stationProfile", "device.model"]
    }
  }
}
```

- 위 값은 PRD §7.3.2의 **초안 제안**이다. 승인(G-08) 전 원문 대조가 필요하고, 이 JSON은 테스트 벡터와 개발용 에뮬레이터 시드에만 쓴다.
- `shoulderTiltAngle`, 체성분, 둘레, ROM은 MDC가 미확보라 항목을 두지 않는다(→ `noMdc`). 추정해 채우지 않는다(§7.3.1-4).
- 승인 검증 규칙(DF-221): `metricCode ∈ 부록 A`, `mdcValue > 0`, `mdcSource ∈ {literature, inHouse}`, `improvementDirection`·`conditionKeys`가 카탈로그와 같음, literature는 http(s) URL, 사진 계열은 `protocolVersion` 필수, `mmtGrade`·`painNrs`·`observedSection` 계열 항목은 거부(ASM-P1b-31 확장, ASM-09-17).

---

## 8 조건 키·seriesBreak·seriesKey

이 절은 **표시 규칙**이다. 클라이언트(TrainerDomain `Series/`, Dart `lib/utils/series_segmenter.dart`)와 서버(`functions/src/change/conditions.js`)가 같은 규칙을 쓰고 `contracts/vectors/series-break.v1.json`으로 검증한다(DF-216). 클라이언트 구현에는 MDC·판정 결과가 없어야 한다(AC-DF-216.8).

### 8.1 가족별 조건 스냅샷

`ConditionSnapshot` 필드는 DF-216 타입 그대로다. 원 기록에서 이렇게 채운다.

| family | 원 기록 | protocolVersion | protocolId | algorithmVersion | view | clothing | cameraHeightCm / cameraDistanceM | deviceKey | fasting | timeOfDayBand | source |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `posture` | postureAssessments | `protocolVersion` | — | — | 지표를 계산한 view(CVA는 `sagittalLeft/Right`, 정면 지표는 `front`, ASM-09-12) | `captureConditions.clothing` | `captureConditions.*` | `device.model` | — | — | — |
| `bodyComposition` | bodyCompositionRecords | — | — | — | — | — | — | `normalizeDevice(deviceModel)` | `fasting` | `timeOfDayBand` | `source` |
| `tape` | circumferenceMeasurements(tape) | `protocolVersion` | `protocolId` | — | — | — | — | — | — | — | — |
| `lidar` | circumferenceMeasurements(observedSection) + bodyScans | `protocolVersion` | `protocolId` | bodyScans `algorithmVersion` | — | — | — | bodyScans `device.model` | — | — | — |
| `pain` | soap_notes `subjective.painNrs` | — | — | — | — | — | — | — | — | — | — |

- `normalizeDevice(s)`: 앞뒤 공백 제거, 연속 공백을 하나로. 대소문자는 바꾸지 않는다(센터 등록 목록에서 고르므로, ASM-09-13).
- 정책 `conditionKeys` 이름과 스냅샷 필드 대응: `protocolVersion`→`protocolVersion`, `protocolId`→`protocolId`, `algorithmVersion`→`algorithmVersion`, `view`→`view`, `captureConditions.clothing`→`clothing`, `stationProfile`→카메라 높이·거리 범위 비교, `device.model`·`deviceModel`→`deviceKey`, `fasting`→`fasting`, `timeOfDayBand`→`timeOfDayBand`, `sourceGrade`·`side`→시리즈 식별자(조건 비교에서 건너뜀), `nrsScale`→비교 없음(상수 `0-10`, V1-05 §13.1). `joint`, `motion`, `activeOrPassive`, `muscleGroup`은 ROM·MMT 전용이며 v1에서 판정하지 않으므로 비교 대상이 아니다.

### 8.2 조건 비교 함수

```
compare(a, b, family) -> nil | (reason, detail)        // 순서 고정(§7.5, AC-DF-216.3)
  // 1) 프로토콜
  for k in [protocolVersion, protocolId, algorithmVersion] ∩ keys(family):
     if a[k] != b[k]: return (protocolChanged, protocolVersion(from: b[k], to: a[k]))     // 한쪽만 null도 다름
  // 2) 기기
  if family ∈ {posture, bodyComposition, lidar} and a.deviceKey != b.deviceKey:
     return (deviceChanged, device(from: b.deviceKey, to: a.deviceKey))
  // 3) 조건
  for k in conditionKeys(family):                        // posture: view, clothing, station / bodyComposition: fasting, timeOfDayBand
     if k == station:
        if !(inRange(a.cameraHeightCm, H) and inRange(b.cameraHeightCm, H) and inRange(a.cameraDistanceM, D) and inRange(b.cameraDistanceM, D)):
           return (conditionMismatch, condition(key: "stationProfile"))
     else if a[k] == nil or b[k] == nil or a[k] == "unknown" or b[k] == "unknown" or a[k] != b[k]:
        return (conditionMismatch, condition(key: k))
  return nil
```

- `H`, `D`는 `posture-protocol.v1.json`의 `station` 범위(닫힌 구간)다. 카메라 높이·거리는 **범위 안이면 같다**고 본다(§7.4, ASM-P1b-18). `stationProfileId` 자체는 비교하지 않는다.
- `unknown`은 같은 값끼리도 불일치다(§7.4). 누락(`nil`)도 `unknown`으로 본다.
- `a`는 뒤(현재·나중) 점, `b`는 앞(비교·이전) 점이다. `detail`의 from은 b, to는 a다.
- 트레이너 사유 라벨: '프로토콜 변경', '기기 변경: {from} → {to}', '조건 불일치: {조건 이름}'(F-VIZ-03.3). 조건 이름 사상(`fasting`→'공복 여부', `timeOfDayBand`→'측정 시간대', `view`→'측면 방향', `clothing`→'복장', `stationProfile`→'카메라 위치')은 V1-12 문구 키.

### 8.3 시리즈 식별자

```
identity(p) = (metricCode, sourceGrade, sideSeries(p), family == bodyComposition ? source : nil)
sideSeries(p) = catalog[metricCode].sideRule ∈ {leftRight, leftRightBilateral} ? p.side : "none"
```

- 좌우가 **별도 시리즈**인 지표(허벅지·상완·종아리 둘레, ROM, MMT)만 `side`를 식별자에 넣는다(F-ASM-06.3).
- 기울기 지표(`magnitudeWithLowerSide`, `magnitudeWithHigherSide`)의 `side`는 '어느 쪽이 높은가'라서 식별자에 넣지 않는다. 넣으면 좌우가 바뀔 때마다 시리즈가 갈라져 T20(측면 바뀜 + 오차 범위 안) 판정이 불가능해진다. 추이는 부호 있는 한 선이다(ASM-P1b-17). DF-216의 `SeriesIdentity.side`는 이 `sideSeries`로 채운다(C-09-03).
- `tape`와 `observedSection`은 sourceGrade가 다르므로 항상 다른 시리즈다(C-02, AC-C-02.1). 두 시리즈 사이는 조건 불일치가 아니라 비교 후보가 아니다(`noComparison`, §7.4).

### 8.4 분할(seriesBreak)

```
segment(points) -> [identity: [Segment]]
  groups = groupBy(points.filter { $0.value != nil }, identity)                 // 누락은 점이 없다(C-04)
  for (id, ps) in groups:
     ps.sort(by: (measuredAt, refId))                                           // 입력 순서와 무관(SB-14)
     segs = [Segment(id: "\(key(id))#0", points: [ps[0]], breakBefore: nil)]
     for i in 1..<ps.count:
        if let br = compare(ps[i].conditions, ps[i-1].conditions, family):
           segs.append(Segment(id: "\(key(id))#\(segs.count)", points: [ps[i]], breakBefore: br))
        else: segs[last].points.append(ps[i])
```

- 비교는 **바로 앞 점**과 한다. A(기기1) → B(기기2) → C(기기1)은 세그먼트 3개다.
- 세그먼트가 다른 두 점 사이에는 선, Δ, 판정을 그리지 않는다(F-VIZ-03.3).
- 줄자 점은 같은 `measuredAt` 반복값을 평균한 세션 점 하나다([§11.4](#114-세션-대표값과-추이-점)).
- 벡터 SB-01~SB-14는 DF-216 카드에 정의돼 있다. 이 문서는 다음 두 사례를 추가한다.

| ID | 입력 | 기대 |
|---|---|---|
| SB-15 | `shoulderTiltAngle` 두 점, side `left` → `right`, 다른 조건 동일 | 한 시리즈·한 세그먼트(끊지 않음) |
| SB-16 | `bodyFatPercent` A(기기1) → B(기기2) → C(기기1) | 세그먼트 3개, 사유 `deviceChanged` 두 번 |

### 8.5 seriesKey

회원 앱이 highlights를 이어 그릴지 판단하는 키다(§9.2 `memberSummaries.highlights[].seriesKey`, F-VIZ-03.3). P2 `createMemberSummary`가 서버에서 계산하고, P1b에는 저장하지 않는다(DF-216).

**입력 문자열(정본).**

```
"seriesKey.v1|" + metricCode + "|" + sourceGrade + "|" + sideSeries + "|" + conds
conds = family 조건 키를 이름 사전순으로 정렬해 "key=value"를 ";"로 이은 것
   posture         : captureConditions.clothing, device.model, protocolVersion, view
                     (카메라 높이·거리가 범위 밖이면 "station=outOfRange!{refId}"를 추가)
   bodyComposition : deviceModel, fasting, source, timeOfDayBand
   tape            : protocolId, protocolVersion
   lidar           : algorithmVersion, device.model, protocolId, protocolVersion
   pain            : (빈 문자열)
값이 null 또는 "unknown"이면 "unknown!{refId}"로 바꾼다(그 점은 누구와도 같은 키가 되지 않는다).
seriesKey = lowercaseHex(SHA-256(UTF-8(입력 문자열))).prefix(16)
```

**예시(합성 값, 검증용).**

| 입력 문자열 | seriesKey |
|---|---|
| `seriesKey.v1\|craniovertebralAngle\|photoManual\|none\|captureConditions.clothing=fitted;device.model=iPad14,5;protocolVersion=posture-v1;view=sagittalLeft` | `5d20d129dbaf756c` |
| `seriesKey.v1\|bodyFatPercent\|device\|none\|deviceModel=InBody 570;fasting=yes;source=manualEntry;timeOfDayBand=morning` | `6f31c0f9c13f3cf0` |
| `seriesKey.v1\|thighCircumference\|tape\|left\|protocolId=custom;protocolVersion=circ-v1` | `6598bb55fff15fb8` |
| `seriesKey.v1\|bodyFatPercent\|device\|none\|deviceModel=InBody 570;fasting=unknown!SYNTHbc09;source=manualEntry;timeOfDayBand=morning` | `39bc663591232997` |

(표의 `\|`는 마크다운 이스케이프이며 실제 문자열은 `|`다.)

- 회원 앱 규칙: highlights를 `measuredAt` 순으로 정렬하고, **바로 앞 점과 seriesKey가 다르면 선을 끊는다**. 그래서 [§8.4](#84-분할seriesbreak)의 분할과 같은 결과가 된다.
- V1-06 §6.13.4의 `sha256(metricCode | sourceGrade | side | conditionKey)` 앞 16자 표기는 이 절의 정본 문자열을 가리킨다(`side` 자리는 `sideSeries`, C-09-03).

---

## 9 4상태 변화 판정(evaluateChange, 서버 전용)

P3(DF-380)에 `functions/src/change/evaluateChangeCore.js`(순수 함수)와 `evaluateChange.js`(callable 어댑터, 요청·응답은 [V1-06 evaluateChange](06_API_SPEC.md))로 구현한다. `createMemberSummary`와 SOAP 스냅샷 생성은 core를 직접 호출한다(DF-381). P3 전에는 배포하지 않으며 모든 판정 자리는 `pendingPolicy`다(F-SOAP-03.4).

### 9.1 입력 정규화(`EvalRecord`)

```ts
type EvalRecord = {
  refId: string;                 // 원 기록 ID(줄자는 세션 묶음의 trialIndex 최소 문서 ID)
  refIds?: string[];             // 줄자 세션 묶음 전체
  metricCode: string; value: number; side: 'none'|'left'|'right'|'bilateral';
  sourceGrade: string; measuredAt: string /* ISO */; source?: string;
  family: 'posture'|'bodyComposition'|'tape'|'lidar'|'pain'; // 조건 비교 가족(파생). 카탈로그 family와 다르다(V1-05 ASM-05-42)
  conditions: ConditionSnapshot; // §8.1
  judgeAsRecord?: EvalRecord;    // bmi 전용: 같은 문서의 weightKg 레코드
};
```

| family | value | measuredAt | 제외(후보 아님) |
|---|---|---|---|
| posture | `metrics[].value`(해당 metricCode) | `capturedAt` | `status != confirmed`, 재검사 묶음의 첫 기록이 아님, 지표 없음 |
| bodyComposition | `values[metricCode]` 또는 `derived.bmi` | `measuredAt` | `status == voided`, 키 없음 |
| tape | 같은 `(memberKey, metricCode, sideSeries, measuredAt)`의 active 반복값 평균([§1.3](#13-공통-수치-규약)) | `measuredAt` | 반복값 전부 voided |
| lidar | `valueCm` | `measuredAt`(= `takenAt`) | voided |

### 9.2 비교 기준 선택

```
selectComparison(current, candidates, mode = .default, explicitRefId = nil):
  pool = candidates.filter { eligible($0) and identity($0) == identity(current) and $0.refId != current.refId }
  if mode == .explicit:
     c = candidates.first { $0.refId == explicitRefId }
     return (c != nil and pool.contains(c)) ? c : nil        // 다른 시리즈·voided·draft면 nil → noComparison (T18, T43)
  if current.family == posture:                                // 기본: 기준선(§7.5)
     b = pool.first { $0.isBaseline and $0.sagittalView == current.sagittalView }
     return b                                                   // 현재 문서 자체가 기준선이면 pool에 없어 nil → noComparison (T53)
  if mode == .previous or current.family != posture:          // 신체조성·줄자 기본, 자세의 '직전 기록'
     return pool.filter { ($0.measuredAt, $0.refId) < (current.measuredAt, current.refId) }.max(by: measuredAt, refId)
```

- 신체조성·줄자에는 `isBaseline` 필드가 없으므로 기본 비교 기준은 **같은 시리즈의 직전 active 기록**이다(V1-06 §evaluateChange, ASM-P1b-29와 같음, ASM-09-18). 조건이 달라도 직전 기록을 고른다. 그래야 기기가 바뀐 첫 점이 `deviceChanged`가 된다(AC-BC-03.3, AC-SOAP-03.5).
- 트레이너가 TR-10에서 '선택 시점'을 고르면 `.explicit`이다(§7.5).
- 기준선이 voided면 후보에서 빠지고 대체 후보를 찾지 않는다. 후보가 없으면 `noComparison`(T18).

### 9.3 판정 의사코드(정본)

PRD §7.5 의사코드를 그대로 따르고, 아래 명확화 7개만 더한다(번호는 [§20](#20-prd스파인다른-문서와의-충돌과-명확화)에서 인용).

- **J-1 정책 게이트:** 활성 정책은 `kind=='bodyChange' && status=='approved' && active===true`인 문서다. 다른 kind가 넘어오면 `pendingPolicy`.
- **J-2 bmi 위임:** `bmi`는 같은 문서의 `weightKg` 레코드로 판정하고 결과를 그대로 쓴다(§7.5 주, T21). `delta`도 weightKg 기준이다. bmi Δ는 표시 계층이 값에서 따로 계산한다.
- **J-3 서열 척도:** 카탈로그 `scale == "ordinal"`(`mmtGrade`)이면 정책 항목이 있어도 `noMdc`.
- **J-4 시리즈 확인:** 비교 레코드의 식별자가 다르면 조건 검사 전에 `noComparison`(§7.4 '시리즈가 다르면 비교 후보가 아니다').
- **J-5 조건 키:** 조건 검사 키는 가족 기본 키([§8.2](#82-조건-비교-함수)) ∪ `rule.conditionKeys`다. 프로토콜·기기 키는 1·2단계에서 이미 봤으므로 3단계에서 다시 보지 않는다. 대응표에 없는 키가 정책에 있으면 설정 오류로 `failed-precondition`(`change.policyConditionKeyUnknown`)을 돌려준다.
- **J-6 스케일 정수 비교:** Δ와 MDC 비교는 [§1.3](#13-공통-수치-규약) 규칙. `|ΔS| = MDC×10^d`는 '의미 있는 변화'다.
- **J-7 sideChanged:** 기울기 지표에서 두 레코드의 side가 둘 다 `none`이 아니고 서로 다르면 `sideChanged=true`(판정은 크기로, '측면 바뀜' 표식은 따로).

### 9.4 참조 구현(JS, CommonJS)

```js
'use strict';
// functions/src/change/evaluateChangeCore.js (P3, DF-380). 순수 함수: Firestore·시각·난수 없음.
const catalog = require('../shared/generated/metric-catalog.v1.json');
const postureProtocol = require('../shared/generated/posture-protocol.v1.json');
const {compareConditions, identityOf} = require('./conditions');

const CATALOG = new Map(catalog.metrics.map((m) => [m.metricCode, m]));

function scaled(v, d) {
  const s = Math.sign(v) * Math.round(Math.abs(v) * 10 ** d);
  return s === 0 ? 0 : s; // -0 제거
}

function isActiveBodyChangePolicy(p) {
  return Boolean(p && p.kind === 'bodyChange' && p.status === 'approved' && p.active === true &&
    p.metrics && typeof p.metrics === 'object');
}

const PENDING = Object.freeze({
  changeStatus: 'pendingPolicy', reasonCode: null, delta: null,
  mdcSource: null, mdc: null, policyVersion: null, sideChanged: false,
});

function mdcOf(rule) {
  return rule ? {value: rule.mdcValue, source: rule.mdcSource, reference: rule.mdcReference ?? null} : null;
}

function indeterminate(reasonCode, policy, rule) {
  return {changeStatus: 'indeterminate', reasonCode, delta: null,
    mdcSource: rule ? rule.mdcSource : null, mdc: mdcOf(rule), policyVersion: policy.version, sideChanged: false};
}

function judge({metricCode, current, comparison, policy}) {
  if (!isActiveBodyChangePolicy(policy)) return {...PENDING};                          // 0 / J-1
  const cat = CATALOG.get(metricCode);
  if (!cat) throw Object.assign(new Error('change.unknownMetric'), {code: 'invalid-argument'});
  if (cat.judgeAs) {                                                                     // J-2 (bmi → weightKg)
    return judge({metricCode: cat.judgeAs, current: current.judgeAsRecord,
      comparison: comparison ? comparison.judgeAsRecord : null, policy});
  }
  const rule = policy.metrics[metricCode] ?? null;
  if (current.sourceGrade === 'observedSection') return indeterminate('betaMetric', policy, rule);      // 1
  if (cat.reliabilityTier === 'reference') return indeterminate('referenceMetric', policy, rule);
  if (!rule || !(rule.mdcValue > 0) || cat.scale === 'ordinal') return indeterminate('noMdc', policy, null); // J-3
  if (current.sourceGrade === 'photoAuto' || comparison?.sourceGrade === 'photoAuto') {
    return indeterminate('noMdc', policy, rule);
  }
  if (!comparison) return indeterminate('noComparison', policy, rule);                  // 2
  if (identityOf(cat, current) !== identityOf(cat, comparison)) {                       // J-4
    return indeterminate('noComparison', policy, rule);
  }
  const br = compareConditions(cat.family, current.conditions, comparison.conditions,  // 3 / J-5
    {extraKeys: rule.conditionKeys, protocol: postureProtocol});
  if (br) return indeterminate(br.reason, policy, rule);

  const d = cat.decimals;                                                                // 4 / J-6
  let aS = scaled(current.value, d);
  let bS = scaled(comparison.value, d);
  if (cat.improvementDirection === 'towardZero') { aS = Math.abs(aS); bS = Math.abs(bS); }
  const deltaS = aS - bS;
  const delta = deltaS === 0 ? 0 : deltaS / 10 ** d;
  const sideChanged = cat.sideRule.startsWith('magnitudeWith') &&                       // J-7
    current.side !== 'none' && comparison.side !== 'none' && current.side !== comparison.side;
  const base = {reasonCode: null, delta, mdcSource: rule.mdcSource, mdc: mdcOf(rule),
    policyVersion: policy.version, sideChanged};
  if (Math.abs(deltaS) < rule.mdcValue * 10 ** d - 1e-9) return {changeStatus: 'withinError', ...base};
  if (cat.improvementDirection === 'none') return indeterminate('noMdc', policy, rule); // Q-16 예약
  const better = cat.improvementDirection === 'higherIsBetter' ? deltaS > 0 : deltaS < 0;
  return {changeStatus: better ? 'meaningfulImprovement' : 'meaningfulDecline', ...base};
}

module.exports = {judge, scaled, isActiveBodyChangePolicy};
```

- 카탈로그 필드(ASM-09-01, V1-05 §13.1에 반영됨): `decimals`(int), `scale`(`"ratio"` \| `"ordinal"`), `judgeAs`(`bmi`만 `"weightKg"`), 카탈로그 `family`는 5개(`posture`, `bodyComposition`, `circumference`, `pain`, `trainerObservation`)이고, 조건 비교 가족 `tape`·`lidar`는 `circumference` + `sourceGrade`에서 파생한다(V1-05 ASM-05-42).
- `conditions.js`의 `compareConditions`는 [§8.2](#82-조건-비교-함수) 의사코드의 JS 번역이며 클라이언트 벡터(`series-break.v1.json`)를 같이 통과해야 한다.
- `evaluateChange.js`(어댑터)는 권한·입력 수집·[§9.2](#92-비교-기준-선택)·응답 형식만 한다. 판정 분기를 두지 않는다.

### 9.5 회원 highlight 필터

```
memberChangeStatus(result, rule, current):
  if result.changeStatus == pendingPolicy: return null                          // P3 전 전부 null
  if rule == nil or rule.mdcSource != inHouse: return null                      // §7.6
  if rule.protocolVersion == nil or current.conditions.protocolVersion != rule.protocolVersion: return null   // ASM-09-16
  if result.changeStatus == indeterminate and result.reasonCode ∈ {noMdc, referenceMetric, betaMetric}: return null   // B.8 '배지 없음'
  return result.changeStatus      // reasonCode·mdcSource·mdc도 함께 저장
```

- `painNrs`, `photoAuto`, `observedSection`, 결과지, 필기, A 원문은 highlight 자체를 만들지 않는다(F-SOAP-05, AC-LIDAR-01.5).
- 신체조성·줄자 레코드에는 `protocolVersion`이 없거나 G-06 연구 대상이 아니므로 v1에서 회원 배지가 붙지 않는다.
- 회원 문장(B.8)과 사유 문구 사상은 [V1-12](12_COPY_ANALYTICS_AND_LINT.md).

### 9.6 결과 → 스냅샷·highlight 사상

| 판정 결과 필드 | `objective.snapshots[]` | `memberSummaries.highlights[]` |
|---|---|---|
| `changeStatus` | 그대로(P3 전 `pendingPolicy`) | [§9.5](#95-회원-highlight-필터) 결과 |
| `reasonCode` | indeterminate일 때만, 아니면 null | 같음(null이면 null) |
| `policyVersion` | pendingPolicy면 null, 그 밖은 정책 버전 | 같음 |
| `mdcSource` | rule 있으면 값, 없으면 null | highlight changeStatus가 null이면 null |
| `mdc{value, source, reference}` | 저장 안 함(§9.3 스냅샷 필드에 없음) | 같은 조건 |
| `delta`, `sideChanged` | 저장 안 함(표시 계층이 값에서 다시 계산) | 저장 안 함 |
| 비교 레코드 | — | `comparedTo{refId, measuredAt, value}` |

### 9.7 테스트 벡터

`contracts/vectors/change-eval.v1.json`. 모든 값은 합성이다. T01~T25는 PRD §7.9 그대로, T26~T53은 이 문서가 추가한다. `target`별 러너: `judge`(judge 직접), `select+judge`(§9.2 후 judge), `memberHighlight`(judge 후 §9.5), `series`(§8.4), `display`(트레이너 라벨 조립, Swift).

**파일 구조와 병합 규칙.** `current`·`comparison`은 `base` 레코드를 복사한 뒤 나머지 키를 깊은 병합한다. `comparison: null`은 비교 없음이다.

```json
{
  "schemaVersion": 1,
  "vectorSet": "change-eval",
  "rounding": "halfAwayFromZero",
  "policies": {
    "P_DRAFT": {"kind": "bodyChange", "version": "bodyChange-draft-1", "status": "approved", "active": true,
      "metrics": {"craniovertebralAngle": {"mdcValue": 5.52, "mdcSource": "literature",
        "mdcReference": "https://www.mdpi.com/1660-4601/17/18/6521", "protocolVersion": "posture-v1",
        "improvementDirection": "higherIsBetter",
        "conditionKeys": ["protocolVersion", "view", "captureConditions.clothing", "stationProfile", "device.model"]}}},
    "P_T55": {"$extends": "P_DRAFT", "version": "test-mdc55", "metrics": {"craniovertebralAngle": {"mdcValue": 5.5}}},
    "P_T_SHOULDER5": {"$extends": "P_DRAFT", "version": "test-shoulder5",
      "metrics": {"shoulderTiltAngle": {"mdcValue": 5.0, "mdcSource": "literature", "mdcReference": "https://example.invalid/test",
        "protocolVersion": "posture-v1", "improvementDirection": "towardZero",
        "conditionKeys": ["protocolVersion", "view", "captureConditions.clothing", "stationProfile", "device.model"]}}},
    "P_T_BC": {"kind": "bodyChange", "version": "test-bc", "status": "approved", "active": true, "metrics": {
      "bodyFatPercent": {"mdcValue": 1.0, "mdcSource": "literature", "mdcReference": "https://example.invalid/test", "protocolVersion": null, "improvementDirection": "none", "conditionKeys": ["deviceModel", "fasting", "timeOfDayBand"]},
      "weightKg": {"mdcValue": 1.0, "mdcSource": "literature", "mdcReference": "https://example.invalid/test", "protocolVersion": null, "improvementDirection": "none", "conditionKeys": ["deviceModel", "fasting", "timeOfDayBand"]},
      "skeletalMuscleMassKg": {"mdcValue": 0.5, "mdcSource": "literature", "mdcReference": "https://example.invalid/test", "protocolVersion": null, "improvementDirection": "higherIsBetter", "conditionKeys": ["deviceModel", "fasting", "timeOfDayBand"]}}},
    "P_T_TAPE": {"kind": "bodyChange", "version": "test-tape", "status": "approved", "active": true, "metrics": {
      "waistCircumference": {"mdcValue": 1.0, "mdcSource": "literature", "mdcReference": "https://example.invalid/test", "protocolVersion": null, "improvementDirection": "none", "conditionKeys": ["sourceGrade", "protocolId", "protocolVersion"]},
      "thighCircumference": {"mdcValue": 1.0, "mdcSource": "literature", "mdcReference": "https://example.invalid/test", "protocolVersion": null, "improvementDirection": "none", "conditionKeys": ["sourceGrade", "protocolId", "protocolVersion", "side"]}}},
    "P_INHOUSE": {"$extends": "P_DRAFT", "version": "test-inhouse",
      "metrics": {"craniovertebralAngle": {"mdcValue": 2.0, "mdcSource": "inHouse", "mdcReference": "G-06 report v1 (synthetic)"}}},
    "P_INACTIVE": {"$extends": "P_DRAFT", "version": "test-inactive", "active": false},
    "P_WRONG_KIND": {"$extends": "P_DRAFT", "version": "test-integrated", "kind": "integrated"},
    "P_T_MMT": {"kind": "bodyChange", "version": "test-mmt", "status": "approved", "active": true, "metrics": {
      "mmtGrade": {"mdcValue": 1.0, "mdcSource": "literature", "mdcReference": "https://example.invalid/test", "protocolVersion": null, "improvementDirection": "higherIsBetter", "conditionKeys": ["muscleGroup", "side"]}}}
  },
  "bases": {
    "postureA": {"family": "posture", "metricCode": "craniovertebralAngle", "sourceGrade": "photoManual", "side": "none",
      "measuredAt": "2027-01-18T10:00:00+09:00",
      "conditions": {"protocolVersion": "posture-v1", "view": "sagittalLeft", "clothing": "fitted",
        "cameraHeightCm": 100, "cameraDistanceM": 3.0, "deviceKey": "iPad14,5"}},
    "frontA": {"$extends": "postureA", "metricCode": "shoulderTiltAngle", "conditions": {"view": "front"}},
    "bodyA": {"family": "bodyComposition", "metricCode": "bodyFatPercent", "sourceGrade": "device", "side": "none", "source": "manualEntry",
      "measuredAt": "2027-01-04T07:30:00+09:00",
      "conditions": {"deviceKey": "InBody 570", "fasting": "yes", "timeOfDayBand": "morning", "source": "manualEntry"}},
    "tapeWaist": {"family": "tape", "metricCode": "waistCircumference", "sourceGrade": "tape", "side": "none",
      "measuredAt": "2027-01-04T08:00:00+09:00", "conditions": {"protocolId": "waistMidpoint", "protocolVersion": "circ-v1"}},
    "tapeThighL": {"$extends": "tapeWaist", "metricCode": "thighCircumference", "side": "left",
      "conditions": {"protocolId": "custom"}},
    "lidarWaist": {"family": "lidar", "metricCode": "waistCircumference", "sourceGrade": "observedSection", "side": "none",
      "measuredAt": "2027-03-16T10:00:00+09:00",
      "conditions": {"protocolId": "waistMidpoint", "protocolVersion": "bodypath-manual-landmarks-1",
        "algorithmVersion": "rgbd-surface-4", "deviceKey": "iPhone16,1"}}
  },
  "cases": [
    {"id": "T01", "target": "judge", "policy": "P_DRAFT", "current": {"base": "postureA", "value": 50.5}, "comparison": {"base": "postureA", "value": 45.0},
     "expected": {"changeStatus": "withinError", "reasonCode": null, "delta": 5.5, "mdcSource": "literature", "policyVersion": "bodyChange-draft-1", "sideChanged": false}},
    {"id": "T02", "target": "judge", "policy": "P_DRAFT", "current": {"base": "postureA", "value": 50.52}, "comparison": {"base": "postureA", "value": 44.98},
     "expected": {"changeStatus": "withinError", "delta": 5.5}},
    {"id": "T03", "target": "judge", "policy": "P_T55", "current": {"base": "postureA", "value": 50.5}, "comparison": {"base": "postureA", "value": 45.0},
     "expected": {"changeStatus": "meaningfulImprovement", "delta": 5.5}},
    {"id": "T06", "target": "judge", "policy": "P_DRAFT", "current": {"base": "postureA", "value": 50.0, "conditions": {"view": "sagittalRight"}}, "comparison": {"base": "postureA", "value": 45.0},
     "expected": {"changeStatus": "indeterminate", "reasonCode": "conditionMismatch", "delta": null}},
    {"id": "T13", "target": "judge", "policy": "P_T_BC", "current": {"base": "bodyA", "value": 22.0, "conditions": {"deviceKey": "InBody 270"}}, "comparison": {"base": "bodyA", "value": 25.0},
     "expected": {"changeStatus": "indeterminate", "reasonCode": "deviceChanged", "policyVersion": "test-bc"}},
    {"id": "T38", "target": "judge", "policy": "P_T55", "current": {"base": "postureA", "value": 35.8}, "comparison": {"base": "postureA", "value": 30.3},
     "expected": {"changeStatus": "meaningfulImprovement", "delta": 5.5}}
  ]
}
```

- `$extends`는 벡터 파일 안에서만 쓰는 병합 지시어다(러너가 해석). 스키마는 `schemas/contracts-meta.schema.json`의 `changeEvalVectors` 정의로 둔다(DF-004 메타 스키마 확장).
- 위 JSON은 형식 예다. 파일에는 아래 표의 53개 사례가 모두 들어간다. 기대값에 적지 않은 필드는 비교하지 않는다.

**PRD §7.9 사례(T01~T25)의 구체 입력.**

| # | target | 정책 | 현재 | 비교 | 기대 |
|---|---|---|---|---|---|
| T01 | judge | P_DRAFT | postureA 50.5 | postureA 45.0 | withinError, Δ=5.5 |
| T02 | judge | P_DRAFT | 50.52 | 44.98 | withinError, Δ=5.5(반올림 후 계산) |
| T03 | judge | P_T55 | 50.5 | 45.0 | meaningfulImprovement(|Δ|=MDC) |
| T04 | judge | P_DRAFT | 39.4 | 45.0 | meaningfulDecline, Δ=−5.6 |
| T05 | judge | P_DRAFT | 52.0, photoAuto | 45.0 | indeterminate(noMdc) · 표시 '스크리닝' |
| T06 | judge | P_DRAFT | view sagittalRight | view sagittalLeft | indeterminate(conditionMismatch) |
| T07 | judge | P_DRAFT | protocolVersion posture-v2 | posture-v1 | indeterminate(protocolChanged) |
| T08 | display | P_DRAFT | T01과 같음 | T01과 같음 | 트레이너 라벨에 '문헌값, 자체 재검사 전'과 `mdcReference` URL, MDC '±5.52°' |
| T09 | judge | 없음(null) | 임의 | 임의 | pendingPolicy, 나머지 null |
| T10 | judge | P_DRAFT | frontA `pelvicTiltFrontal` 6.0 left | 2.0 left | indeterminate(referenceMetric) |
| T11 | judge | P_DRAFT | frontA `headTiltFrontal` 3.0 | 1.0 | indeterminate(referenceMetric) |
| T12 | judge | P_DRAFT | frontA `shoulderTiltAngle` 3.0 | 2.0 | indeterminate(noMdc) |
| T13 | judge | P_T_BC | bodyA 22.0, deviceKey InBody 270 | bodyA 25.0 | indeterminate(deviceChanged), policyVersion test-bc |
| T14 | judge | P_T_BC | bodyA `weightKg` 68.0, fasting unknown | 70.0 | indeterminate(conditionMismatch) |
| T15 | judge | P_T_TAPE | lidarWaist 78.0 | lidarWaist 80.0 | indeterminate(betaMetric) |
| T16a | select+judge | P_DRAFT(허리 항목 없음) | tapeWaist 80.0 | 후보: lidarWaist만 | indeterminate(noMdc) |
| T16b | select+judge | P_T_TAPE | tapeWaist 80.0 | 후보: lidarWaist만 | indeterminate(noComparison) |
| T17 | select+judge | P_DRAFT | postureA 48.0 | 후보 없음 | indeterminate(noComparison) |
| T18 | select+judge | P_DRAFT | postureA 48.0 | 후보: 기준선 문서가 voided | indeterminate(noComparison) |
| T19 | judge | P_DRAFT | `painNrs` 3(pain) | 7 | indeterminate(referenceMetric) · 회원 비노출 |
| T20 | judge | P_T_SHOULDER5 | frontA 3.0 right | 3.0 left | withinError, Δ=0, sideChanged=true |
| T21 | judge | P_T_BC | bodyA `bmi` 22.9(judgeAs weightKg 62.4) | bmi 23.6(weightKg 64.3) | weightKg 판정과 같음: Δ=−1.9 ≥ 1.0, 방향 none → indeterminate(noMdc) |
| T22 | series | — | bodyFatPercent 3회차 중 2회차 값 없음(points 2개) | — | 점 2개·세그먼트 1개, 보간·0 점 없음 |
| T23 | judge | P_DRAFT | frontA `shoulderTiltAngle` 3.0, deviceKey iPad16,3 | 2.0, iPad14,5 | 조건 검사 전 indeterminate(noMdc)(deviceChanged 아님, null 참조 없음) |
| T24 | memberHighlight | P_DRAFT | postureA 50.5 | 45.0 | judge=withinError, highlight changeStatus=null |
| T25 | memberHighlight | P_INHOUSE | postureA 48.0 | 45.0 | judge=meaningfulImprovement(Δ=3.0 ≥ 2.0), highlight=meaningfulImprovement |

**추가 사례(T26~T53).**

| # | target | 정책 | 현재 | 비교 | 기대 | 근거 |
|---|---|---|---|---|---|---|
| T26 | judge | P_DRAFT | postureA 50.0 | 45.0 photoAuto | noMdc | §7.3.1-3 |
| T27 | judge | P_DRAFT | deviceKey iPad16,3 | iPad14,5 | deviceChanged | §7.4 |
| T28 | judge | P_DRAFT | clothing regular | fitted | conditionMismatch | §7.4 |
| T29 | judge | P_DRAFT | clothing unknown | clothing unknown | conditionMismatch | §7.4 unknown |
| T30 | judge | P_DRAFT | 46.0, cameraHeightCm 104 | 45.0, 98 | withinError, Δ=1.0 | ASM-P1b-18 |
| T31 | judge | P_DRAFT | cameraHeightCm 115 | 100 | conditionMismatch | 범위 밖 |
| T32 | judge | P_DRAFT | posture-v2 + iPad16,3 | posture-v1 + iPad14,5 | protocolChanged(하나만) | AC-DF-216.3 |
| T33 | judge | P_T_BC | bodyA 24.0, timeOfDayBand evening | 25.0 morning | conditionMismatch | §7.4 |
| T34 | judge | P_T_BC | `weightKg` 71.5 | 70.0 | indeterminate(noMdc)(방향 none, Q-16) | §7.5 |
| T35 | judge | P_T_BC | `weightKg` 70.6 | 70.0 | withinError, Δ=0.6 | §7.5 |
| T36 | judge | P_T_BC | `skeletalMuscleMassKg` 30.6 | 30.0 | meaningfulImprovement | higherIsBetter |
| T37 | judge | P_T_BC | `skeletalMuscleMassKg` 29.4 | 30.0 | meaningfulDecline | 〃 |
| T38 | judge | P_T55 | 35.8 | 30.3 | meaningfulImprovement, Δ=5.5(부동소수 차 5.4999…) | J-6 |
| T39 | judge | P_DRAFT | 4.0 | −2.0 | meaningfulImprovement, Δ=6.0 | 음수 CVA |
| T40 | judge | P_T_SHOULDER5 | frontA 2.5 right | 8.0 left | meaningfulImprovement, Δ=−5.5, sideChanged=true | towardZero |
| T41 | judge | P_T_SHOULDER5 | frontA 6.0 left | 0.0 none | meaningfulDecline, Δ=6.0, sideChanged=false | J-7 |
| T42 | judge | P_T_TAPE | tapeThighL, protocolVersion circ-v2 | circ-v1 | protocolChanged | §7.4 |
| T43 | select+judge(explicit) | P_T_TAPE | tapeThighL 54.0 | 명시 비교 refId가 `thighCircumference` right | noComparison | J-4 |
| T44 | judge | P_T_TAPE | tapeWaist 반복 [80.2, 80.6] → 80.4 | 반복 [80.8, 81.0] → 80.9 | withinError, Δ=−0.5 | §11.4 평균 |
| T45 | judge | P_T_TAPE | lidarWaist, comparison null | — | betaMetric(noComparison보다 먼저) | 순서 |
| T46 | judge | P_INACTIVE | 임의 | 임의 | pendingPolicy | J-1 |
| T47 | judge | P_WRONG_KIND | 임의 | 임의 | pendingPolicy | J-1 |
| T48 | judge | P_T_MMT(승인 검증을 우회해 `mmtGrade` 항목을 넣은 테스트 정책) | `mmtGrade` 4(`trainerObserved`) | 3 | noMdc | J-3 |
| T49 | judge | P_T_BC | `bmi` 24.8(weightKg 70.5) | bmi 24.6(weightKg 70.0) | weightKg 판정과 같음: withinError, Δ=0.5 | J-2 |
| T50 | memberHighlight | P_INHOUSE | postureA protocolVersion posture-v2, 48.0 | posture-v2, 45.0 | judge=meaningfulImprovement, highlight=null | ASM-09-16 |
| T51 | select+judge | P_DRAFT | postureA 48.0 | 후보: 같은 재검사 묶음 R1(기준선, 첫 기록 45.0), R2(46.0) | 비교=R1, withinError, Δ=3.0 | F-ASM-05.3 |
| T52 | select+judge | P_T_BC | bodyA 22.0, InBody 270, 02-05 | 후보: A1 25.0(01-04), A2 24.6(02-03), 모두 InBody 570 | 비교=A2(직전), deviceChanged | ASM-09-18, AC-BC-03.3 |
| T53 | select+judge | P_DRAFT | 현재 문서가 기준선 자신 | 후보: 자신뿐 | noComparison | §9.2 |

- T21·T49의 bmi 값은 `derived.bmi` 저장값(표시용)이며 판정에 쓰지 않는다.
- T25의 P_INHOUSE MDC 2.0은 테스트 값이다. 실제 inHouse 값은 G-06 보고서에서만 온다.

---

## 10 신체조성 입력 검증과 단위

필드 정본은 [V1-05 §4.7](05_DATA_MODEL_AND_RULES.md). 여기서는 앱 쪽 파싱·검증·파생 계산을 정한다(TR-11, DF-127·DF-128).

### 10.1 숫자 파싱

```
parseMeasurement(text, range, decimals = 1) -> .unmeasured | .value(Double) | .error(key)
  t = text에서 앞뒤 공백(전각 공백 U+3000 포함) 제거
  if t.isEmpty: return .unmeasured                                  // 빈칸 = 미측정(F-BC-03.1), 0으로 저장하지 않음
  t = t.replacing(",", with: ".")                                   // 쉼표는 소수점으로만 받는다(자릿수 구분 아님)
  if !matches(t, "^[0-9]+(\\.[0-9]{1,\(decimals)})?$"): return .error("bc.input.notNumber")   // 부호·지수·두 번째 점 거부
  v = Double(t); if !v.isFinite: return .error("bc.input.notNumber")
  if !range.contains(v): return .error("bc.input.outOfRange")      // 문구에 {min}~{max} 표시(AC-BC-03.2)
  return .value(v)
```

- 쉼표 처리와 빈칸=미측정은 BodyPath 규칙을 계승한다(bodypath:ios/BodyScan/BodyScan/Models/WellnessModels.swift:65-77).
- 소수 둘째 자리 이상은 거부한다(반올림해서 받지 않는다, ASM-09-21). 결과지 표기가 소수 첫째 자리까지이기 때문이다.
- "1,234.5"처럼 쉼표와 점이 함께 있으면 점이 두 개가 되어 거부된다.

### 10.2 값 범위

| 키 | 앱 범위(닫힌 구간) | 0 | 규칙 범위(V1-05) | 근거 |
|---|---|---|---|---|
| `weightKg` | 0.1 ~ 600 | 거부 | `> 0 && ≤ 600` | F-BC-03.2, bodypath:ios/BodyScan/BodyScan/Models/WellnessModels.swift:93 |
| `bodyFatPercent` | 0 ~ 100 | **허용** | `≥ 0 && ≤ 100`(R-27) | F-BC-03.2, 같은 파일 :94 |
| `skeletalMuscleMassKg` | 0.1 ~ 300 | 거부 | `> 0 && ≤ 300` | F-BC-03.2, 같은 파일 :95 |
| `bodyFatMassKg` | 0.1 ~ 600(제안) | 거부 | `> 0 && ≤ 600` | ASM-05-07 |
| `visceralFatLevel` | 1 ~ 100(제안) | 거부 | `> 0 && ≤ 100` | ASM-05-07 |
| `totalBodyWaterL` | 0.1 ~ 300(제안) | 거부 | `> 0 && ≤ 300` | ASM-05-07 |
| 키(`heightCmUsed`) | 100 ~ 250 | 거부 | `100 ≤ x ≤ 250` | V1-05 §4.7 |

- 저장 조건: `values`에 키가 **1개 이상**이고 필수 메타가 모두 있다(F-BC-01.1). 체중만 입력해도 된다(AC-BC-03.1).
- 미측정 키는 `values`에 넣지 않는다. `0`을 넣지 않는다(체지방률 0은 사용자가 실제로 0을 입력한 경우만).

### 10.3 필수 메타와 `timeOfDayBand`

| 필드 | 규칙 |
|---|---|
| `deviceModel` | 센터 등록 목록에서 선택(기본값: 이 회원의 최근 active 기록 기기, 없으면 트레이너의 최근 사용 기기). `normalizeDevice` 후 1~64자 |
| `measuredAt` | 기본값 '지금', 편집 가능. `≤ 현재 + 5분`(PRD §9.1 제안값). 저장 시각과 분리(AC-BC-01.2) |
| `fasting` | **기본값 없음.** `yes`/`no` 중 하나를 반드시 고른다. `unknown`은 보조 메뉴에서만 고를 수 있다(F-BC-01.2) |
| `timeOfDayBand` | `measuredAt`에서 자동. 트레이너가 수정하지 않는다 |
| `source` | `manualEntry` 고정 |

```
timeOfDayBand(measuredAt):                 // Asia/Seoul 벽시계(§1.3)
  m = hour × 60 + minute
  if m < 11×60:  return .morning           // 00:00 ~ 10:59
  if m < 17×60:  return .midday            // 11:00 ~ 16:59
  return .evening                          // 17:00 ~ 23:59
```

| 사례 | measuredAt(+09:00) | 기대 |
|---|---|---|
| TB-01 | 10:59:59 | `morning` |
| TB-02 | 11:00:00 | `midday` |
| TB-03 | 16:59:59 | `midday` |
| TB-04 | 17:00:00 | `evening` |
| TB-05 | 00:30:00 | `morning` |
| TB-06 | 2027-01-04T01:30:00Z(= 10:30 KST) | `morning`(기기 시간대가 UTC여도 같음) |

경계(11:00, 17:00)는 PRD F-BC-01.2의 제안값이다. 바꾸면 기존 기록의 밴드는 다시 계산하지 않는다(조건 키가 달라져 seriesBreak가 생길 수 있음을 변경 PR에 적는다).

### 10.4 BMI 파생

```
bmi(weightKg, heightCm):   precondition weightKg != nil, heightCm ∈ [100, 250]
  return roundHalfAway(weightKg / pow(heightCm / 100, 2), 1)
derived = {bmi, heightCmUsed: heightCm, heightMeasuredAt, sourceGrade: "derived"}
```

- 키 출처는 **트레이너 입력 키**만이다: 대기 회원은 `pendingMembers.heightCm`(동의 ② 이후), 가입 회원은 TR-11의 '키' 입력값이다. 회원이 편집하는 `users.height`는 쓰지 않는다(F-BC-01.3, AC-BC-01.3). 가입 회원의 키 기본값은 그 회원의 가장 최근 active 기록 `derived.heightCmUsed`다(ASM-09-22).
- 키나 체중이 없으면 `derived`를 만들지 않고 '미측정'으로 보인다(AC-BC-01.5). 결과지 BMI는 따로 입력받지 않는다.
- 예: 62.4kg, 165.0cm → 22.920… → **22.9**.
- 판정은 weightKg를 따른다([§9.3](#93-판정-의사코드정본) J-2).

### 10.5 교차 일관성 경고

저장은 막지 않고 경고만 한다(F-BC-03.3, AC-BC-03.4).

| ID | 조건(모두 해당 키가 있을 때만) | 문구 키(V1-12) |
|---|---|---|
| W-BC-01 | `bodyFatMassKg > weightKg` | `tr11.warn.fatMassOverWeight` |
| W-BC-02 | `skeletalMuscleMassKg ≥ weightKg` | `tr11.warn.muscleOverWeight` |
| W-BC-03 | `|bodyFatPercent − 100 × bodyFatMassKg / weightKg| > 2.0` %p | `tr11.warn.fatPercentMismatch` |

- W-BC-03의 2.0%p는 제안값이다(ASM-09-23). 결과지 반올림(각 값 소수 첫째 자리)만으로 생기는 차이는 체중 30kg 이상에서 0.3%p 안쪽이라 2.0%p면 전사 오류만 잡는다.

### 10.6 기기 변경 안내

```
previous = 같은 회원의 active 기록 중 measuredAt < new.measuredAt 인 것의 최댓값(measuredAt, id)
if previous != nil and normalizeDevice(previous.deviceModel) != normalizeDevice(new.deviceModel):
   show "기기가 바뀌어 이전 기록과 비교할 수 없습니다"(F-BC-03.4) — 저장은 허용
```

- 추이 끊김은 [§8.4](#84-분할seriesbreak)가 처리한다(AC-BC-03.3).

### 10.7 정정

- '정정'은 원 기록을 `status=voided`, `voidReason`(1~200자), `voidedAt=serverTimestamp()`로 바꾸고, 같은 값·메타로 미리 채운 **새 입력**을 연다(F-BC-03.5).
- 미리 채운 입력의 `measuredAt`은 원 기록 값을 그대로 둔다(같은 측정의 정정이므로). `reportPhotoPath`는 복사하지 않는다(경로가 기록 ID 기준, §9.5). 로컬 캐시에 결과지 원본이 있으면 '결과지 사진 다시 첨부'를 기본 선택으로 제시한다.

### 10.8 참조 구현(Swift)

```swift
// Sources/TrainerDomain/BodyComposition/BodyCompositionValidator.swift
public struct BodyCompositionForm: Sendable {
  public var texts: [BodyCompositionKey: String]      // weightKg, bodyFatPercent, ...
  public var deviceModel: String?; public var measuredAt: Date; public var fasting: Fasting?   // nil = 미선택
  public var heightCmText: String?
}
public struct BodyCompositionDraftValues: Equatable, Sendable {
  public var values: [BodyCompositionKey: Double]; public var derived: DerivedBMI?
  public var timeOfDayBand: TimeOfDayBand; public var warnings: [BodyCompositionWarning]
}
public enum BodyCompositionValidator {
  public static func validate(_ f: BodyCompositionForm, now: Date) -> Result<BodyCompositionDraftValues, BodyCompositionErrors> {
    var errors = BodyCompositionErrors(); var values: [BodyCompositionKey: Double] = [:]
    for key in BodyCompositionKey.allCases {
      switch NumberParser.parseMeasurement(f.texts[key] ?? "", range: key.appRange, decimals: 1) {
      case .unmeasured: continue
      case .value(let v): values[key] = v
      case .error(let e): errors.fields[key] = e
      }
    }
    if values.isEmpty { errors.form.append(.noMeasuredValue) }                       // "측정한 항목을 한 가지 이상 입력해 주세요"
    let device = f.deviceModel.map(DeviceModel.normalize) ?? ""
    if !(1...64).contains(device.count) { errors.form.append(.deviceRequired) }       // AC-BC-01.1
    if f.fasting == nil { errors.form.append(.fastingRequired) }                      // AC-BC-01.1, 기본값 없음
    if f.measuredAt > now.addingTimeInterval(300) { errors.form.append(.measuredAtInFuture) }
    var derived: DerivedBMI? = nil
    if let hText = f.heightCmText, case .value(let h) = NumberParser.parseMeasurement(hText, range: 100...250, decimals: 1),
       let w = values[.weightKg] {
      derived = DerivedBMI(bmi: Rounding.roundHalfAway(w / pow(h / 100, 2), decimals: 1), heightCmUsed: h)
    }
    guard errors.isEmpty else { return .failure(errors) }
    return .success(.init(values: values, derived: derived,
                          timeOfDayBand: TimeOfDayBand(measuredAt: f.measuredAt),
                          warnings: CrossConsistency.warnings(values)))
  }
}
```

### 10.9 벡터: `contracts/fixtures/body/bodycomp-input.v1.json`

| ID | 입력 | 기대 | 근거 |
|---|---|---|---|
| BC-01 | 체중 "62,4"만, 메타 완비 | `values={weightKg:62.4}`, 0 값 없음 | AC-BC-03.1, F-BC-03.1 |
| BC-02 | 체지방률 "120" | `.error(outOfRange)` '0–100 범위' | AC-BC-03.2 |
| BC-03 | 체지방률 "0" | `values.bodyFatPercent = 0` 허용 | R-27 |
| BC-04 | 체중 "0" | `.error(outOfRange)` | F-BC-03.2 |
| BC-05 | 모든 칸 빈칸 | `.noMeasuredValue` | F-BC-01.1 |
| BC-06 | `fasting` 미선택 | `.fastingRequired` | AC-BC-01.1 |
| BC-07 | 체중 "62.45" | `.error(notNumber)`(소수 둘째 자리) | ASM-09-21 |
| BC-08 | 체중 "-3" / "6e1" / "1,234.5" | 모두 `.error(notNumber)` | §10.1 |
| BC-09 | 체중 62.4, 키 165.0 | `derived.bmi = 22.9` | F-BC-01.3 |
| BC-10 | 키 없음 | `derived = null` | AC-BC-01.5 |
| BC-11 | 체중 60.0, 체지방량 61.0 | 저장 가능 + W-BC-01 | AC-BC-03.4 |
| BC-12 | 체중 70.0, 체지방률 25.0, 체지방량 20.0 | W-BC-03(차이 3.57%p) | §10.5 |
| BC-13 | 체중 70.0, 체지방률 25.0, 체지방량 17.6 | 경고 없음(차이 0.14%p) | §10.5 |
| BC-14 | measuredAt = now + 6분 | `.measuredAtInFuture` | §9.1 공통 규약 |

---

## 11 줄자 둘레 입력 규칙

필드 정본은 [V1-05 §4.8](05_DATA_MODEL_AND_RULES.md). 한 문서 = 부위 1개 × 반복 1회다(TR-12, DF-129).

### 11.1 부위·protocolId·side

| metricCode | 기본 표시 | protocolId | side | landmarkNote | 부위 정의 |
|---|---|---|---|---|---|
| `waistCircumference` | 예 | `waistMidpoint` | `none` | 선택 | 갈비뼈 하단과 장골능 사이 중간점, 호기 말. 가장 가는 곳·배꼽으로 대체하지 않음 |
| `hipCircumference` | 예 | `hipMaximum` | `none` | 선택 | 최대 둔부 둘레 |
| `chestCircumference` | '부위 추가' | `custom` | `none` | **필수** | 기준점 문구는 프로토콜 v1(DF-915) |
| `thighCircumference` | '부위 추가' | `custom` | `left`\|`right` **필수** | **필수** | 〃 |
| `upperArmCircumference` | '부위 추가' | `custom` | `left`\|`right` **필수** | **필수** | 〃 |
| `calfCircumference` | '부위 추가' | `custom` | `left`\|`right` **필수** | **필수** | 최대 둘레 |

- 부위 정의와 안내 문구는 BodyPath에서 가져온다(bodypath:ios/BodyScan/BodyScan/Storage/MeasurementRecord.swift:6-26). 그 파일 주석처럼 다중 프레임 스캔은 WHO 줄자 검사가 아니므로(같은 파일 :4-5) 줄자에만 WHO STEPS 정의를 쓴다(F-ASM-06.2).
- `protocolVersion`은 `"circ-v1"`이다(V1-05 §4.8 예시). 생성 상수 `CircumferenceProtocol.version`으로 둔다(ASM-09-26).
- 좌우는 다른 시리즈다(F-ASM-06.3, [§8.3](#83-시리즈-식별자)).

### 11.2 한 행 입력과 반복값

```
TapeRow { metricCode, side, texts: [String] (최대 3칸), landmarkNote?, conditionsNote?, measuredAt }

parseRow(row):
  vals = []
  for (i, t) in row.texts.enumerated():
     switch parseMeasurement(t, range: 1...400, decimals: 1):     // F-ASM-06.5
       .unmeasured: continue                                       // 빈칸은 문서를 만들지 않는다(AC-ASM-06.3)
       .value(v):   vals.append(v)
       .error(e):   return .error(field: i, e)
  if vals.isEmpty: return .noDocuments
  require side 규칙(§11.1)                                         // AC-ASM-06.1
  require metricCode의 protocolId == custom ⇒ landmarkNote.trimmed.count ∈ 1...500   // AC-ASM-06.4
  require conditionsNote == nil 또는 ≤ 500자
  return vals.enumerated().map { (k, v) in Doc(trialIndex: k + 1, valueCm: v, measuredAt: row.measuredAt, ...) }

showThirdField(row):                                               // F-ASM-06.4
  a, b = 첫 두 칸의 파싱 값
  return (a != nil and b != nil and |scaled(a,1) − scaled(b,1)| ≥ 10)   // 차이 1.0cm 이상(제안값)
         or 세 번째 칸에 이미 값이 있음                                // 값이 있으면 닫지 않는다
```

- 한 행의 모든 문서는 **같은 `measuredAt`**(행 저장 시 한 번 정한 값)을 가진다. 세션 묶음은 이 값으로 식별한다(ASM-09-14).
- `trialIndex`는 비어 있지 않은 칸을 앞에서부터 1, 2, 3으로 매긴다.
- 값이 하나뿐이어도 저장할 수 있다. 이때 '2회 측정을 권장해요' 안내만 보인다(ASM-09-25).
- 세 번째 칸이 열렸는데 비워 두어도 저장할 수 있다. 차이 1cm 기준은 제안값이며 프로토콜 v1에서 바꿀 수 있다(`protocolVersion` 변경).

### 11.3 수정·무효

- 저장된 반복값 문서는 고치지 않는다. 한 값을 잘못 넣었으면 그 문서를 `voided`(사유)로 바꾸고 같은 `measuredAt`으로 새 문서를 추가한다. 새 문서의 `trialIndex`는 묶음 안 최댓값 + 1이다(최대 3을 넘지 않는다. 넘으면 새 행으로 다시 잰다).
- 개별 값은 지우지 않는다(F-ASM-06.4).

### 11.4 세션 대표값과 추이 점

```
sessionGroups = groupBy(active tape docs, (memberKey, metricCode, sideSeries, measuredAt))
representative(group) = mean(group.valueCm)   // §1.3 스케일 정수 평균, 소수 첫째 자리
```

- 표시: '평균 80.4cm (80.2 · 80.6)'. 평균과 개별값을 함께 보인다(AC-ASM-06.2).
- 추이 점 하나 = 세션 묶음 하나(`refId` = `trialIndex`가 가장 작은 active 문서, `refIds` = 묶음 전체).
- SOAP 스냅샷은 반복값 문서마다 하나씩 저장한다(ASM-P1b-22). 판정 입력은 세션 평균이다([§9.1](#91-입력-정규화evalrecord)).

### 11.5 벡터: `contracts/fixtures/body/tape-input.v1.json`

| ID | 입력 | 기대 | 근거 |
|---|---|---|---|
| TP-01 | 허리 ["80.2", "80.6", ""] | 3번째 칸 닫힘, 문서 2개(trialIndex 1·2), 평균 80.4 | AC-ASM-06.2 |
| TP-02 | 허리 ["80.0", "81.0"] | 차이 정확히 1.0 → 3번째 칸 열림 | F-ASM-06.4 경계 |
| TP-03 | 허리 ["80.0", "80.9"] | 닫힘 | 〃 |
| TP-04 | 허리 ["82.2", "80.9", "81.5"] | 문서 3개, 평균 81.5(815.33 → 815) | §1.3 |
| TP-05 | 허벅지 side 없음 | 거부 `sideRequired` | AC-ASM-06.1 |
| TP-06 | 가슴 landmarkNote "  " | 거부 `landmarkNoteRequired` | AC-ASM-06.4 |
| TP-07 | 허리 ["", "", ""] | 문서 0개 | AC-ASM-06.3 |
| TP-08 | 허리 ["0"] / ["400.1"] | 거부 `outOfRange` | F-ASM-06.5 |
| TP-09 | 허리 ["", "80.4"] | 문서 1개(trialIndex 1) + 권장 안내 | ASM-09-25 |
| TP-10 | 허리 side "left" | 거부(`none`만) | §11.1 |

---

## 12 NRS·ROM·MMT 입력 검증

| 지표 | 저장 위치 | 값 | 필수 부속 필드 | 미완성 행 조건 | 근거 |
|---|---|---|---|---|---|
| `painNrs` | `subjective.painNrs` | 0~10 **정수**, 미입력(`null`)과 0을 구분 | — | — | F-SOAP-01.3, §9.3 |
| `painRegions` | `subjective.painRegions` | 부록 A.7 regionCode 배열(≤64), 중복 제거 | — | 목록 밖 코드는 저장 거부 | F-SOAP-02.3 |
| `romDeg` | `objective.metrics[]` | 0~220 정수 deg(ASM-09-19) | `joint`, `motion`(A.5), `activeOrPassive`(기본 `active`), `side`(`left`\|`right`\|`bilateral`) | 부속 필드 하나라도 없음, 또는 A.5 허용 조합 밖(DF-916 확정 후) | F-SOAP-02.4, AC-SOAP-02.3 |
| `mmtGrade` | `objective.metrics[]` | 0~5 정수. '+/−' 등급은 v1에 없다 | `muscleGroup`(A.6), `side` | 부속 필드 없음 | §9.3, AC-SOAP-02.4 |

- `activeOrPassive=passive`(UI 'PROM')는 Q-23 결론 전까지 선택지를 숨긴다. 레거시 이관으로 들어온 passive 값은 읽기만 한다.
- 숫자가 아닌 관찰('저항 시 불편' 등)은 `value`에 넣지 않고 `note` 또는 `exerciseAssessment.observations`로 안내한다(F-SOAP-02.5).
- 미완성 행은 확정 시 자동 제외하고 목록을 알린다([§13.4](#134-확정-최소-요건) #6). NRS·ROM·MMT는 v1에서 판정하지 않는다(`painNrs`는 reference, 나머지는 MDC 없음).

---

## 13 SOAP O 자동 불러오기와 확정 최소 요건

### 13.1 후보 선택(F-SOAP-03.1~03.2, P1b)

```
candidates(member, sessionDate, flags):
  day = seoulDay(sessionDate)
  pool =  posture: eligiblePosture(docs)                          // §6.2 (confirmed, 재검사 첫 기록)
        + bodyComposition: status == active
        + tape: status == active, sourceGrade == tape, 세션 묶음 단위(§11.4)
        + (flags.lidarBeta ? bodyScans + observedSection 둘레 : [])   // AC-SOAP-03.6
  pool = pool.filter { seoulDay(measuredAt($0)) <= day }           // 세션 날짜 이후 측정은 제외(ASM-09-27)
  pool += 로컬 미동기 기록(syncState 칩과 함께)                     // ASM-P1b-21
  sameDay = pool.filter { seoulDay(measuredAt($0)) == day }         // 기본 선택(F-SOAP-03.2)
  earlier = 종류별로 pool.filter { seoulDay(...) < day }.max(by: measuredAt) 1건씩   // 기본 선택 안 함(AS-23)
            (줄자는 가장 최근 측정일의 세션 묶음 전체, ASM-P1b-22)
  return (selected: sameDay, optional: earlier)                    // 비면 '불러올 기록 없음'(F-SOAP-03.8)
```

- `measuredAt(x)`: 자세 `capturedAt`, 신체조성·줄자 `measuredAt`, 스캔 `takenAt`(§7.8).
- 쿼리는 `trainerId == uid` + 회원 키를 포함하고, 오류를 빈 목록으로 삼키지 않는다('불러오기 실패', AC-SOAP-03.7).

### 13.2 스냅샷 생성

```
snapshots(selected) -> [Snapshot]      // 종류 순서: posture → bodyComposition → tape → lidar, 그 안에서 카탈로그 순서
  posture 문서:        metrics[] 원소마다 1개
  bodyComposition 문서: values 키마다 1개 + derived.bmi(있으면)
  tape 문서:           반복값 문서마다 1개(ASM-P1b-22)
  Snapshot = {refId, metricCode, value, unit, side, sourceGrade, measuredAt,
              changeStatus: "pendingPolicy", reasonCode: null, policyVersion: null, mdcSource: null}   // P1b~P2(F-SOAP-03.4)
```

- sourceGrade가 없는 값은 스냅샷을 만들지 않는다(F-SOAP-03.5). 사진·원문은 복사하지 않는다(F-SOAP-03.3).
- `objective.snapshots` 상한은 60개다(§9.3). 넘으면 초과분을 알리고 트레이너가 선택을 줄이게 한다(자르지 않는다).
- P3부터는 스냅샷을 만들 때 서버 `evaluateChangeCore` 결과를 받아 채운다(DF-381). 오프라인이면 판정 자리에 '온라인 필요'를 보이고 스냅샷 적용 버튼을 비활성으로 둔다(ADR-009, ASM-09-28).

### 13.3 '원본 변경됨' 판정

```
sourceChanged(snapshot, note):
  ref = 원 기록(refId)
  t0  = note.status == finalized ? note.finalizedAt : local.snapshotsAppliedAt   // ASM-P1b-24
  return ref == nil                                          // 삭제·파기
      or ref.status == voided
      or exists(doc: doc.supersedesId == ref.id)             // 체형 새 버전
      or ref.updatedAt > t0
```

- 참이면 '원본 변경됨'과 원본 링크를 보인다. 스냅샷 값은 바꾸지 않는다(F-SOAP-03.6, AC-SOAP-03.3).

### 13.4 확정 최소 요건

```
finalizeCheck(note, connectivity) -> FinalizeCheck                         // §6.4.4, AS-26
  blocking = []
  if note.memberUid == nil and note.pendingMemberId == nil: blocking += .member            // #1
  if note.sessionDate == nil: blocking += .sessionDate                                      // #2
  if trimmed(note.quickNote).isEmpty and trimmed(note.subjective.chiefComplaint).isEmpty:
     blocking += .todayRecord                                                               // #3
  if trimmed(note.plan.nextSession).isEmpty: blocking += .nextPlan                          // #4
  recommended = trimmed(note.exerciseAssessment.summary).isEmpty ? [.assessment] : []       // #5 배지만
  excludedRows = note.objective.metrics.filter { !rowIsComplete($0) }                       // #6 비차단, §12
  copyWarnings = ProhibitedTermMatcher.scan([A, P, memberNote], ruleSets: [common, trainer]) // #7 확인 후 진행
  mode = connectivity.isOnline ? .finalizeNow : .pendingFinalize                            // #8 '확정 대기'
  return FinalizeCheck(canFinalize: blocking.isEmpty, blocking, recommended, excludedRows, copyWarnings, mode)
```

- `trimmed`는 공백·줄바꿈만 있는 문자열을 빈 것으로 본다.
- #7 경고가 있으면 트레이너가 '확인하고 확정'을 눌러야 진행한다(원 기록은 트레이너 전용, §6.4.4).
- 규칙에서도 #2~#4를 검사한다(V1-05 ASM-05-17).

---

## 14 LiDAR 결과 패키지 가져오기 검증(BodyPathResult)

P2 베타(`lidarBeta`, G-07a 이후)다. 결과 패키지 스키마의 **정본은 BodyPath 저장소 `docs/RESULT_PACKAGE_V1.md`**(DF-301)이고, 이 절은 트레이너 앱이 기대하는 형식과 검증 규칙의 초안이다(ADR-012, PRD §10.4.3). DF-301이 스키마를 확정하면 이 절을 그에 맞춘다.

### 14.1 패키지 형식(제안)

- 컨테이너: 확장자 `.bodypathresult`인 zip. 안에 `result.json`(UTF-8)과 선택 `thumb.jpg`(얼굴 없는 메시 렌더, ≤512KB)만 둔다. 원본 프레임·깊이·메시는 넣지 않는다(D10, ASM-09-09).
- 전달: 공유 시트·AirDrop·파일 앱으로 가져온다(F-LIDAR-01, AS-29).

```json
{
  "schemaVersion": 1,
  "packageId": "7F0C2A0E-5B1D-4C1E-9E0B-SYNTHETIC0001",
  "exportedAt": "2027-03-16T10:20:00+09:00",
  "subjectCode": "SYNTH-S012",
  "takenAt": "2027-03-16T10:05:00+09:00",
  "device": {"model": "iPhone16,1", "hasLiDAR": true},
  "captureMode": "cameraOrbit",
  "purpose": "measurements",
  "algorithmVersion": "rgbd-surface-4",
  "meshAlgorithm": "projective-tsdf-1",
  "meshSHA256": "3f1c0d8e9a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d",
  "isSynthetic": false,
  "quality": {"integratedFrames": 142, "flags": []},
  "sections": [
    {
      "metricCode": "waistCircumference",
      "protocolId": "waistMidpoint",
      "protocolVersion": "bodypath-manual-landmarks-1",
      "perimeterMm": 812.4,
      "contour2dMm": [120.0, 0.0, 118.5, 18.7, 114.1, 36.9],
      "landmarkConfirmed": true,
      "contourConfirmed": true,
      "referenceTapeCm": 81.0
    }
  ],
  "thumbnail": {"file": "thumb.jpg", "sha256": "…64 hex…"}
}
```

BodyPath 내부 값 → 패키지 필드(DF-301 내보내기 구현용):

| 패키지 필드 | BodyPath 출처 |
|---|---|
| `subjectCode` | `Subject.code`(bodypath:ios/BodyScan/BodyScan/Models/Models.swift:12) |
| `takenAt` | `Scan.takenAt`(같은 파일 :34). `BodyMeasurementRecord.createdAt`은 저장 시각이라 쓰지 않는다(F-LIDAR-01.3) |
| `algorithmVersion` | `Scan.algorithmVersion`(기본 `"rgbd-surface-4"`, 같은 파일 :53) |
| `meshAlgorithm` | manifest `measurementAlgorithm`(`"projective-tsdf-1"`, bodypath:ios/BodyScan/BodyScan/Capture/CaptureController.swift:426) |
| `captureMode` | manifest `captureMode`(`cameraOrbit` \| `subjectRotation`, bodypath:ios/BodyScan/BodyScan/Storage/ScanManifest.swift:4) |
| `meshSHA256`, `isSynthetic`, `sections[].protocolId`·`protocolVersion`·`landmarkConfirmed`·`contourConfirmed`·`referenceTapeCm` | `BodyMeasurementRecord`(bodypath:ios/BodyScan/BodyScan/Storage/MeasurementRecord.swift:28-41; `protocolVersion` 값 `"bodypath-manual-landmarks-1"`은 bodypath:ios/BodyScan/BodyScan/Views/BodyMeasurementView.swift:262) |
| `sections[].perimeterMm` | `report.perimeterMM`(bodypath:ios/BodyScan/BodyScan/Reconstruction/BodyMeasurement.swift:61) |
| `sections[].contour2dMm` | `report.contourM`의 각 점 `(x, z)`를 mm로(×1000) 평탄화. 닫힌 윤곽은 첫 점을 끝에 반복하지 않는다(같은 파일 :12-13). 평면 투영이 (x, z)인 것은 기존 플롯과 같다(bodypath:ios/BodyScan/BodyScan/Views/BodyMeasurementView.swift:338) |

- `landmarkNote`, `conditionsNote` 같은 자유 텍스트는 패키지에 넣지 않는다. 개인정보가 섞일 수 있고 트레이너 앱이 쓰지 않는다(ASM-09-32).
- `referenceTapeCm`은 부위별 값이라 `sections[]` 안에 둔다(스파인 DTO의 최상위 필드와 다름, C-09-04).

### 14.2 검증 규칙

`ResultPackageValidator.validate(_:knownAlgorithms:now:) -> [ValidationIssue]`. 패키지 수준 오류(`BP-E`)가 하나라도 있으면 가져오기 전체를 거부한다. 단면 수준 문제(`BP-S`)는 그 단면만 건너뛰고, 남는 단면이 없으면 `BP-E09`로 거부한다(ASM-09-29).

| 코드 | 수준 | 조건 | 근거 |
|---|---|---|---|
| BP-E01 | 패키지 | zip·JSON 해석 실패, 필수 키 누락 | — |
| BP-E02 | 패키지 | `schemaVersion != 1` | §10.4.3 '알 수 없는 스키마 버전' |
| BP-E03 | 패키지 | `isSynthetic == true` | F-LIDAR-01.4, AC-LIDAR-01.3 |
| BP-E04 | 패키지 | `takenAt` 없음·해석 불가·`> now + 5분` | F-LIDAR-01.3, §10.4.3 |
| BP-E05 | 패키지 | `algorithmVersion` 또는 `meshAlgorithm`이 `knownAlgorithms` 밖 | §10.4.3 |
| BP-E06 | 패키지 | `captureMode != "cameraOrbit"` 또는 `purpose != "measurements"` | F-LIDAR-01.4 |
| BP-E07 | 패키지 | `meshSHA256`이 `^[0-9a-f]{64}$`가 아님 | F-LIDAR-01.4 'meshSHA256 존재' |
| BP-E08 | 패키지 | `subjectCode`가 비었거나 64자 초과 | F-LIDAR-01.2 |
| BP-E09 | 패키지 | 유효 단면 0개 | — |
| BP-E10 | 패키지 | `device.hasLiDAR == false` | 측정 메시는 LiDAR 전용 |
| BP-E11 | 패키지 | 같은 회원에 같은 `meshSHA256`의 bodyScans가 이미 있음(가져오기 시점 조회) | MIG-10 '중복 없음' |
| BP-E12 | 패키지 | 같은 `metricCode` 단면이 둘 이상 | 모호성 |
| BP-S01 | 단면 | `metricCode ∉ {waistCircumference, hipCircumference}` | F-LIDAR-01.6 베타 부위 |
| BP-S02 | 단면 | `landmarkConfirmed == false` 또는 `contourConfirmed == false` | F-LIDAR-01.4, AC-LIDAR-01.3 |
| BP-S03 | 단면 | `perimeterMm`이 유한수가 아니거나 10~4000mm 밖 | 줄자 범위 1~400cm와 같음 |
| BP-S04 | 단면 | `protocolId`가 metricCode와 맞지 않음(허리↔`waistMidpoint`, 엉덩이↔`hipMaximum`) | F-ASM-06.2 |
| BP-S05 | 단면 | `contour2dMm` 길이가 홀수, 6 미만(점 3개 미만), 유한수 아닌 값 | 윤곽 표시 불가 |
| BP-W01 | 경고 | `referenceTapeCm`이 1~400 밖 | 값을 버리고(`null`) 경고만 |
| BP-W02 | 경고 | `thumbnail.sha256` 불일치 또는 파일 없음 | 썸네일 없이 진행 |

가져오기 단계 검사(패키지 검증 뒤, 트레이너 앱):

| 코드 | 조건 | 처리 |
|---|---|---|
| BP-I01 | `lidarBeta == false` | TR-13 진입점 자체가 없다(AC-LIDAR-01.1) |
| BP-I02 | `memberAliases`(system=bodypath)에 `subjectCode` 매핑 없음 | '회원 연결 필요' 대기열. 이름·코드로 자동 추정 매칭하지 않는다(F-LIDAR-01.2, AC-LIDAR-01.4) |
| BP-I03 | 매핑된 대상이 대기 회원 | 거부(bodyScans는 `memberUid` 필수, F-LINK-01.7) |
| BP-I04 | 동의 ② 또는 ③이 서버에서 확인되지 않음 | 거부 '동의 필요'(AC-PRIV-02.4) |

`knownAlgorithms`는 트레이너 앱 상수 `FeatureLidarBeta/KnownBodyPathAlgorithms.swift`에 둔다: `algorithmVersion ∈ {"rgbd-surface-4"}`, `meshAlgorithm ∈ {"projective-tsdf-1"}`. 값을 추가하는 PR은 seriesBreak(`algorithmVersion` 변경 = `protocolChanged`)가 생긴다는 점을 적는다(§10.4.2).

### 14.3 단위 변환과 윤곽 축소

```
valueCm = roundHalfAway(perimeterMm / 10, 1)                  // 812.4mm → 81.2cm (표시·저장값)
contourPoints = pairs(contour2dMm)                            // [(x0,y0), (x1,y1), …] mm
if contourPoints.count > 512:                                 // §9.2 contour2dMm ≤ 1024 숫자
   L = 닫힌 다각형 둘레(마지막 점 → 첫 점 변 포함)
   step = L / 512
   resampled = k = 0..511 에 대해 누적 길이 k·step 위치를 선형 보간한 점
   contourPoints = resampled
contour2dMm = flatten(contourPoints.map { (roundHalfAway(x,1), roundHalfAway(y,1)) })
```

- 둘레 값은 패키지의 `perimeterMm`을 그대로 쓴다. 축소한 윤곽으로 둘레를 다시 계산하지 않는다(ASM-09-33).
- 플롯은 윤곽의 경계 상자에 10% 여백을 두고 그린다. 닫힌 윤곽 색은 호스트가 주입하고, 열린 윤곽은 주황으로 그리는 규칙을 유지한다(bodypath:ios/BodyScan/BodyScan/Views/BodyMeasurementView.swift:327, :342, DF-302).

### 14.4 기록 사상

| 대상 | 필드 | 값 |
|---|---|---|
| `bodyScans` | `memberUid` | 매핑된 uid |
| | `takenAt` | 패키지 `takenAt` |
| | `sourceApp`, `captureMode`, `rawLocation`, `isBeta` | `bodypath`, `cameraOrbit`, `deviceLocal`, `true` |
| | `device`, `algorithmVersion`, `meshAlgorithm`, `meshSHA256`, `quality` | 패키지 값 그대로 |
| | `sections[]` | 유효 단면마다 `{metricCode, perimeterMm, contour2dMm(§14.3), confirmed: true}` |
| | `thumbnailPath` | 생성 때 null, 업로드 후 `bodyScans/{scanId}/thumb.jpg` |
| `circumferenceMeasurements`(단면마다 1건) | `sourceGrade`, `isBeta`, `validationStatus` | `observedSection`, `true`, `unvalidated` |
| | `metricCode`, `side`, `protocolId`, `protocolVersion` | 단면 값, `none` |
| | `valueCm` | §14.3 |
| | `measuredAt` | 패키지 `takenAt`(AC-LIDAR-01.2) |
| | `trialIndex`, `scanId`, `referenceTapeCm` | `1`, 새 bodyScans ID, 단면 값 또는 null |

- `referenceTapeCm`으로 `valueCm`을 보정하거나 덮어쓰지 않는다(F-LIDAR-03.2, AC-LIDAR-03.1). 줄자 시리즈 기록(F-LIDAR-03.1)은 트레이너가 TR-12에서 확인해 따로 만든다(DF-322).
- 모든 표시 위치에 '관측 단면 · 실측 대조 전 · 베타/참고' 라벨을 붙이고 '측정값'이라고 쓰지 않는다(AC-LIDAR-03.2). 판정은 항상 `betaMetric`이다([§9.3](#93-판정-의사코드정본)).

### 14.5 참조 구현(Swift, BodyPathResult)

```swift
// BodyPath 저장소: packages/BodyPathCore/Sources/BodyPathResult/ResultPackageValidator.swift (Foundation만)
public struct ValidationIssue: Equatable, Sendable {
  public enum Level: Sendable { case package, section(index: Int), warning }
  public var code: String; public var level: Level
}
public enum ResultPackageValidator {
  static let betaSites: [String: String] = ["waistCircumference": "waistMidpoint", "hipCircumference": "hipMaximum"]
  public static func validate(_ p: ResultPackageV1, knownAlgorithms: KnownAlgorithms, now: Date) -> [ValidationIssue] {
    var out: [ValidationIssue] = []
    func pkg(_ c: String) { out.append(.init(code: c, level: .package)) }
    if p.schemaVersion != 1 { pkg("BP-E02") }
    if p.isSynthetic { pkg("BP-E03") }
    if let t = p.takenAt { if t > now.addingTimeInterval(300) { pkg("BP-E04") } } else { pkg("BP-E04") }
    if !knownAlgorithms.algorithmVersions.contains(p.algorithmVersion) || !knownAlgorithms.meshAlgorithms.contains(p.meshAlgorithm) { pkg("BP-E05") }
    if p.captureMode != "cameraOrbit" || p.purpose != "measurements" { pkg("BP-E06") }
    if p.meshSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil { pkg("BP-E07") }
    if p.subjectCode.isEmpty || p.subjectCode.count > 64 { pkg("BP-E08") }
    if !p.device.hasLiDAR { pkg("BP-E10") }
    if Set(p.sections.map(\.metricCode)).count != p.sections.count { pkg("BP-E12") }
    var valid = 0
    for (i, s) in p.sections.enumerated() {
      func sec(_ c: String) { out.append(.init(code: c, level: .section(index: i))) }
      let before = out.count
      if betaSites[s.metricCode] == nil { sec("BP-S01") }
      if !s.landmarkConfirmed || !s.contourConfirmed { sec("BP-S02") }
      if !s.perimeterMm.isFinite || !(10...4000).contains(s.perimeterMm) { sec("BP-S03") }
      if let expected = betaSites[s.metricCode], expected != s.protocolId { sec("BP-S04") }
      if s.contour2dMm.count % 2 != 0 || s.contour2dMm.count < 6 || !s.contour2dMm.allSatisfy(\.isFinite) { sec("BP-S05") }
      if let r = s.referenceTapeCm, !(1...400).contains(r) { out.append(.init(code: "BP-W01", level: .warning)) }
      if out[before...].allSatisfy({ if case .warning = $0.level { return true } else { return false } }) { valid += 1 }
    }
    if valid == 0 { pkg("BP-E09") }
    return out   // BP-E01(해석 실패)은 디코더, BP-E11·BP-I*는 트레이너 앱이 판단
  }
}
```

### 14.6 벡터(BodyPath 패키지 테스트 픽스처)

| ID | 변형(기본은 §14.1 예시) | 기대 |
|---|---|---|
| BP-01 | 그대로 | 이슈 없음, valueCm 81.2 |
| BP-02 | `isSynthetic=true` | BP-E03 |
| BP-03 | `takenAt` 삭제 | BP-E04 |
| BP-04 | `algorithmVersion="rgbd-surface-9"` | BP-E05 |
| BP-05 | `captureMode="subjectRotation"` | BP-E06 |
| BP-06 | 단면 `contourConfirmed=false`(유일 단면) | BP-S02 + BP-E09 |
| BP-07 | 단면 2개 중 하나 `metricCode="thighCircumference"` | 그 단면만 BP-S01, 나머지 가져오기 |
| BP-08 | `referenceTapeCm=0` | BP-W01, 값 null로 진행 |
| BP-09 | 윤곽 점 800개(원) | 512점으로 축소, 둘레 값 불변 |
| BP-10 | `schemaVersion=2` | BP-E02 |
| BP-11 | 같은 `meshSHA256` 두 번 가져오기 | 두 번째 BP-E11(트레이너 앱 단계) |

---

## 15 사진 개인정보 처리: EXIF 제거·얼굴 가림

### 15.1 EXIF 제거와 재인코딩

- [§2.2](#22-exif-방향-정규화)에서 얻은 정립 CGImage를 `CGImageDestinationCreateWithData(…, UTType.jpeg, 1, nil)`로 쓴다. 원본 메타데이터 사전을 넘기지 않고 다음만 준다: `kCGImageDestinationLossyCompressionQuality: 0.85`, `kCGImagePropertyOrientation: 1`. 긴 변 ≤ 4032px, 파일 ≤ 10MB(ASM-P1b-14).
- 썸네일(`{view}_thumb.jpg`)과 가림본(`{view}_masked_thumb.jpg`)은 긴 변 480px, 품질 0.7, ≤ 512KB(ASM-P1b-14).
- 검사(AC-ASM-01.4 + 확장, ASM-09-34): 결과 파일을 `CGImageSourceCopyPropertiesAtIndex`로 다시 읽어
  - `kCGImagePropertyGPSDictionary`가 없다(PRD 수용 기준).
  - `kCGImagePropertyTIFFDictionary`에 `Make`, `Model`, `Software`, `DateTime`이 없다.
  - `kCGImagePropertyExifDictionary`에 `DateTimeOriginal`, `DateTimeDigitized`, `LensMake`, `LensModel`, `BodySerialNumber`, `SubsecTimeOriginal`이 없다.
  - `kCGImagePropertyMakerAppleDictionary`가 없다.
  - `Orientation`이 없거나 1이다.
- 사진은 앱 전용 저장소(`Application Support/TrainerKit/Posture/{assessmentId}/`)에만 둔다. `PHPhotoLibrary`, `UIImageWriteToSavedPhotosAlbum`을 쓰지 않는다(F-ASM-01.7, AC-DF-204.9).

### 15.2 얼굴 가림(F-ASM-01.10)

ASM-P1b-13을 구현 수준으로 옮긴다.

```
maskedThumbnail(uprightImage, view, landmarks) -> CGImage?
  thumb = resize(uprightImage, longSide: 480)
  faces = VNDetectFaceRectanglesRequest(uprightImage, .up).results      // boundingBox: 왼쪽 아래 원점 정규화
  boxes = faces.map { r in
     b = CGRect(x: r.minX, y: 1 − r.maxY, width: r.width, height: r.height)   // 왼쪽 위 원점으로
     expand(b, by: 0.30)                                                        // 가로·세로 각 30% 확장(중심 고정), [0,1]로 자름
  }
  if boxes.isEmpty:                                                            // 측면 사진은 얼굴 검출이 자주 실패
     anchor = view == front ? midpoint(earLeft, earRight) : tragus{Side}        // confirmed 좌표만
     if anchor == nil: return nil                                              // maskedThumbPath = null → P2 공유 불가
     side = 0.18 × H(정규화 높이 기준, 정사각형은 픽셀 기준 0.18·H × 0.18·H)
     boxes = [square(center: anchor, side)]
  fill(thumb, boxes, color: 단색 중립 회색, blur 금지)
  return thumb
```

- 가림은 썸네일에만 적용한다. 트레이너 앱 안의 원본 보기는 가리지 않는다(원본 표시는 트레이너 앱 안에서만).
- 얼굴을 못 찾은 경우의 머리 상자는 **확정 시점**에 확정 랜드마크로 만든다(DF-209가 호출). 확정 전 가림본은 만들지 않는다.
- 회원 공유(P2)는 가림본만 쓴다(V1-05 ASM-05-09). 연구 내보내기는 사진을 기본 제외한다(F-ASM-05.5).

---

## 16 재검사 연구 분석(ICC·SEM·MDC95)

G-06 산출물(DF-939)의 계산 규칙이다. 데이터 수집은 IRB 승인·면제 확인 뒤에만 한다(§7.3.3, §12.6). 분석은 가명 처리 데이터셋(DF-326, P1b에는 소유자 스크립트)으로만 하고 실데이터를 저장소·CI에 넣지 않는다.

### 16.1 데이터 구성

- 단위: 대상자 i(1..n) × 반복 j(1..k). P1b 평가자내 연구는 같은 날 독립 재배치 반복 촬영 k=2(Q-02 기본값 20명 × 2회), 평가자 1명(소유자)이다. P2 평가자간 연구는 평가자 r명을 k 자리에 둔다.
- 한 대상자의 반복 = 같은 `retestGroupId`의 confirmed 기록을 `capturedAt` 순으로 정렬한 앞의 k개(ASM-09-35). k개가 안 되면 그 대상자는 분석에서 빼고 제외 수를 보고한다.
- 값: 지표별 `photoManual` 값(주 분석). 같은 사진의 `photoAuto` 값은 보조 분석([§16.5](#165-photoauto-대-photomanual-일치도))에만 쓴다.
- 제외: 동의 ⑤ 또는 ③ 철회 대상자(F-ASM-05.5), 프로토콜 버전이 섞인 묶음(버전별로 따로 분석).

### 16.2 ICC(2,1): 이원 무선, 단일 측정, 절대 일치

이원 분산분석 평균제곱(행=대상자, 열=반복):

```
x̄  = 전체 평균,   x̄_i· = 대상자 i 평균,   x̄_·j = 반복 j 평균
SSR = k · Σ_i (x̄_i· − x̄)²              MSR = SSR / (n − 1)
SSC = n · Σ_j (x̄_·j − x̄)²              MSC = SSC / (k − 1)
SST = Σ_i Σ_j (x_ij − x̄)²
SSE = SST − SSR − SSC                   MSE = SSE / ((n − 1)(k − 1))

ICC(2,1) = (MSR − MSE) / (MSR + (k − 1)·MSE + k·(MSC − MSE)/n)
```

- 이 식은 McGraw & Wong의 ICC(A,1), Shrout & Fleiss의 ICC(2,1)이다. R `psych::ICC`의 `ICC2`(Single_random_raters), Python `pingouin.intraclass_corr`의 `ICC2`와 같다.

**95% 신뢰구간(McGraw & Wong 1996, ICC(A,1)).**

```
a  = k·ρ̂ / (n·(1 − ρ̂))
b  = 1 + k·ρ̂·(n − 1) / (n·(1 − ρ̂))
v  = (a·MSC + b·MSE)² / ( (a·MSC)²/(k − 1) + (b·MSE)²/((n − 1)(k − 1)) )
F₁ = F_{0.975}(n − 1, v),   F₂ = F_{0.975}(v, n − 1)
하한 = n·(MSR − F₁·MSE) / ( F₁·(k·MSC + (k·n − k − n)·MSE) + n·MSR )
상한 = n·(F₂·MSR − MSE) / ( k·MSC + (k·n − k − n)·MSE + n·F₂·MSR )
```

### 16.3 SEM과 MDC95

- 주 분석(사전 명시, ASM-09-20): `SEM = SD × √(1 − ICC)`. `SD`는 n·k개 관측값 전체의 표본 표준편차(분모 n·k − 1)다(PRD §7.3.3 식).
- 민감도 분석: `SEM_mse = √MSE`. 두 값을 모두 보고하고 정책에는 주 분석 값을 쓴다.
- `MDC95 = 1.96 × √2 × SEM`(PRD §7.3.3).
- 정책 `mdcValue`로 옮길 때는 저장 정밀도(0.1°)로 **올림**한다(작게 잡으면 오차를 변화로 판정할 위험이 커지므로, ASM-09-30). 예: 1.845 → 1.9.

### 16.4 판정 규칙(산출물 → 정책)

| 결과 | 처리 |
|---|---|
| 평가자내 ICC 점추정 ≥ 0.75 | inHouse MDC95로 새 정책 버전 초안(AD-04), `protocolVersion`·평가자 조건·엔진을 함께 기록. G-08 승인 전 자동 적용하지 않는다 |
| 평가자내 ICC < 0.75 | 해당 지표를 `reference`로 내리는 카탈로그 PR(§7.2) |
| 평가자간 ICC(P2) 미산출 | tier는 문헌 근거를 유지하되 보고서에 '평가자간 미확인'을 적는다. 트레이너 간 비교 가능성은 알 수 없다(§7.3.2) |
| 연구 미완료 | '문헌값 유지, 회원 배지 없음' 결정 문서(G-06 대체, G-08 선행 조건) |

### 16.5 `photoAuto` 대 `photoManual` 일치도

같은 사진의 두 값 차 `d_i = auto_i − manual_i`로 평균 차(편향), 차의 표준편차 `s_d`, 95% 일치한계 `평균 ± 1.96·s_d`를 보고한다(Bland–Altman). Q-18(엔진 유지)과 RISK-02의 근거이며 판정 정책에는 쓰지 않는다(photoAuto는 v1에서 판정하지 않는다).

### 16.6 검증용 예제 벡터

분석 도구(R, Python, 자체 스크립트 무엇이든)가 아래 합성 데이터에서 같은 값을 내는지 먼저 확인한다(소수 넷째 자리까지 일치).

| 대상자 | 1회 | 2회 |
|---|---|---|
| S1 | 48.2 | 47.5 |
| S2 | 52.1 | 53.0 |
| S3 | 44.8 | 45.9 |
| S4 | 50.3 | 49.6 |
| S5 | 46.7 | 47.9 |
| S6 | 55.0 | 54.1 |
| S7 | 43.2 | 44.0 |
| S8 | 49.5 | 50.8 |

| 값 | 결과 |
|---|---|
| 전체 평균 | 48.9125 |
| MSR / MSC / MSE | 26.3611 / 0.5625 / 0.4611 |
| ICC(2,1) | 0.9647 |
| 95% CI(McGraw & Wong) | 0.8494 ~ 0.9927 (v = 7.968) |
| SD(16개 관측값) | 3.5432 |
| SEM(주) / MDC95(주) | 0.6656 / 1.8451 |
| SEM(√MSE) / MDC95 | 0.6790 / 1.8822 |
| 정책 mdcValue(올림) | 1.9 |
| 2회−1회 평균 차 / SD / 95% 일치한계 | 0.375 / 0.9603 / −1.507 ~ 2.257 |

(위 일치한계는 형식 확인용으로 2회−1회 차를 쓴 것이다. 실제 §16.5 분석은 auto−manual 차를 쓴다.)

```js
// 검증용 참조(Node 22, 의존성 없음). CI는 F 분위수가 필요 없는 점추정만 확인한다.
function icc21(rows) {            // rows: [[x_i1, x_i2, ...], ...]
  const n = rows.length, k = rows[0].length;
  const all = rows.flat(), grand = all.reduce((a, b) => a + b, 0) / (n * k);
  const rowMeans = rows.map((r) => r.reduce((a, b) => a + b, 0) / k);
  const colMeans = [...Array(k).keys()].map((j) => rows.reduce((a, r) => a + r[j], 0) / n);
  const ssr = k * rowMeans.reduce((a, m) => a + (m - grand) ** 2, 0);
  const ssc = n * colMeans.reduce((a, m) => a + (m - grand) ** 2, 0);
  const sst = all.reduce((a, x) => a + (x - grand) ** 2, 0);
  const msr = ssr / (n - 1), msc = ssc / (k - 1), mse = (sst - ssr - ssc) / ((n - 1) * (k - 1));
  const icc = (msr - mse) / (msr + (k - 1) * mse + (k * (msc - mse)) / n);
  const sd = Math.sqrt(all.reduce((a, x) => a + (x - grand) ** 2, 0) / (n * k - 1));
  const sem = sd * Math.sqrt(1 - icc);
  return {msr, msc, mse, icc, sd, sem, mdc95: 1.96 * Math.SQRT2 * sem, semMse: Math.sqrt(mse)};
}
```

---

## 17 금지어 매칭 규칙

JSON 구조와 경로별 규칙 세트는 DF-010(`contracts/prohibited-terms.v1.json`: `ruleSets.{common,member,trainer}[]{id, terms[], alternatives[], scopes[], severity}`, `causalPatterns[]`, `abbreviationAllowlist`, `pathRuleSets[]`, `allowPaths[]`, `allowEntries[]`)과 [V1-12](12_COPY_ANALYTICS_AND_LINT.md)가 정본이다. 이 절은 **한 문자열에서 위반을 찾는 동작**을 정하며, 세 구현(린트 `tool/lint/prohibited-terms.mjs`, 서버 `functions/src/summaries/prohibitedTerms.js`, 트레이너 앱 `TrainerDomain/Copy/ProhibitedTermMatcher.swift`)이 같은 픽스처를 통과해야 한다.

### 17.1 정규화와 위치 사상

```
fold(text) -> (folded: String, map: [Int])        // map[i] = folded의 i번째 문자가 원문에서 시작하는 UTF-16 오프셋
  s = NFC(text)
  for each Unicode scalar c in s (원문 UTF-16 오프셋 o와 함께):
     if c ∈ 무시 문자: continue                    // 공백류(\s, U+3000), 제로폭(U+200B~U+200D, U+FEFF), 가운뎃점(·, U+00B7), '-', '_', '/', '.'
     c = ASCII면 소문자로
     folded.append(c); map.append(o)
```

- 목적: '체형 교정', '체형·교정', '재 활'처럼 띄어쓰기·구분자를 끼운 변형을 같은 단어로 잡는다.
- 오프셋은 **원문 UTF-16 코드 단위**다(JS 문자열 인덱스, Dart `String` 인덱스, Swift `String.utf16` 오프셋과 같다). 위반 위치 `{start, end}`는 원문 기준 반열린 구간이다.

### 17.2 용어 매칭

```
scan(text, field, ruleSets) -> [Violation]
  if allowEntries.any { $0.exactString == text }: return []          // §3.1 고지 원문 등 정확 문자열 예외
  (f, map) = fold(text)
  hits = []
  for set in ruleSets, rule in set, term in rule.terms:
     t = fold(term).folded
     for each occurrence index p of t in f (겹침 허용):
        if rule.exceptPhrases?.any { 그 구절의 fold가 p를 포함하는 위치에서 f와 일치 }: continue
        hits.append(Violation(field, term, start: map[p], end: endOffset(map, p + t.count), ruleSet: set.name, id: rule.id, kind: .term))
  dedupe: 같은 start에서 시작하는 hit은 가장 긴 term만 남긴다. 다른 hit에 완전히 포함되는 hit은 뺀다.
  return hits.sorted(by: start, then end desc)
```

- `endOffset(map, q)` = `map[q − 1]` + 그 문자의 UTF-16 길이. 즉 마지막으로 일치한 원문 문자 바로 다음 오프셋이다(뒤따르는 공백은 포함하지 않는다).
- 조사·어미가 붙어도 부분 문자열로 잡힌다('치료를', '개선됐어요').
- `exceptPhrases`는 오탐을 줄이기 위한 규칙별 선택 필드다(예: 관련 없는 합성어). 추가는 V1-12 절차로 한다(ASM-09-24).

### 17.3 인과 표현 패턴

- `causalPatterns[].regex`를 **원문**에 적용하되, 패턴 안 공백은 `\s*`로 해석한다. 결과는 `kind: .causal`, `severity: warn`이다. 린트는 두 모드 모두 경고로만 보고하고(ASM-P0-07), 서버 요약 생성은 거부하지 않고 `warnings[]`로 돌려준다(V1-06 §7.5, F-PRIV-06.2).

### 17.4 약어 규칙(회원 노출 세트)

```
abbreviations(text) = 원문에서 정규식 (?<![A-Za-z])[A-Z]{2,6}(?![A-Za-z]) 로 찾은 토큰
member 세트 위반 = 토큰 ∈ abbreviationAllowlist.trainer ∪ {CVA, BIA}   // 트레이너 약어는 회원 문구에 쓰지 않는다(B.8)
                 or 토큰 ∉ abbreviationAllowlist.member                 // 기본 ["BMI"](ASM-09-24)
trainer 세트: 약어 검사 없음(허용)
```

- 회원 앱은 B.8 표현('관절이 움직이는 범위', '근력 등급(0–5)' 등)을 쓴다.

### 17.5 픽스처: `contracts/fixtures/prohibited-terms/cases.v1.json`

| ID | 규칙 세트 | 입력 | 기대(UTF-16 오프셋) |
|---|---|---|---|
| PT-01 | common | "체형 교정 운동" | `교정`(C1-05) 3~5, 가장 긴 일치 `체형 교정` 0~5 하나만 |
| PT-02 | common | "재 활 트레이닝" | `재활` 0~3(가운데 공백 포함), `재활 트레이닝` 행이 있으면 그것 하나 |
| PT-03 | common | "운동 지도와 건강관리 기록용이며 진단이나 치료를 위한 정보가 아닙니다." | 위반 없음(`allowEntries`) |
| PT-04 | common | "진단이나 치료를 위한 기록" | `진단`, `치료` 두 건 |
| PT-05 | member | "CVA가 개선됐어요" | 약어 `CVA` + `개선` |
| PT-06 | trainer | "CVA가 개선됐어요" | 위반 없음(트레이너 세트는 '개선'·약어 허용) |
| PT-07 | member | "BMI 22.9" | 위반 없음(회원 허용 목록) |
| PT-08 | common | "스트레칭 때문에 좋아졌어요" | 인과 경고 1건(`때문에`), 차단 아님 |
| PT-09 | common | "체형·교정" | `체형교정` 0~5 하나(가운뎃점 무시, 포함된 `교정`은 제거) |
| PT-10 | member | "ROM 측정" | 약어 `ROM` |

---

## 18 분석 이벤트 구간 계산

이벤트·속성 레지스트리의 정본은 `contracts/analytics-events.v1.json`(DF-033)과 [V1-12](12_COPY_ANALYTICS_AND_LINT.md)다. 이 절은 구간 경계만 정한다(P1a ASM-P1a-11 값을 채택, ASM-09-31).

```
elapsedBand(ms):                           // 아래 경계 포함, 위 경계 제외
  s = ms / 1000
  s < 5    → "lt5s"
  s < 10   → "5to10s"
  s < 20   → "10to20s"
  s < 30   → "20to30s"
  s < 60   → "30to60s"
  s < 180  → "1to3m"
  s < 600  → "3to10m"
  else     → "gt10m"
countBand(n):  0 → "0",  1…3 → "1to3",  4…6 → "4to6",  7…9 → "7to9",  ≥10 → "10plus"
```

- 경계 10초·30초·60초는 M-01(평균 10초 미만, 30초 초과 비율)과 M-11(중앙값 60초 이하)을 구간만으로 판단할 수 있게 둔 것이다. 평균은 구간 중앙값(`gt10m`은 600초)으로 근사해 보고하고 근사임을 적는다.
- 시간 측정은 단조 시계(`ContinuousClock`/`DispatchTime`)로 한다. 벽시계 변경의 영향을 받지 않는다. 음수가 나오면 이벤트를 보내지 않는다.
- `count_band`는 `retake_count_band`, `manual_adjust_count_band`, `auto_ref_count_band`, `daily_session_count_reported.count_band`에 같이 쓴다.
- 경계 사례: 4999ms → `lt5s`, 5000ms → `5to10s`, 9999ms → `5to10s`, 10000ms → `10to20s`, 600000ms → `gt10m`.

---

## 19 가정(ASM-09-NN)

문서 범위 ID다. 채택되면 V1-00의 AS-DEV 목록으로 옮긴다([V1-01](01_AGILE_WORKING_AGREEMENT.md#문서-변경)). 다른 문서의 가정(ASM-P1b-NN, ASM-05-NN, ASM-P0-NN, ASM-P1a-11)을 채택한 곳은 본문에 그 ID를 그대로 적었다.

| ID | 가정 | 관련 PRD | 영향 스토리 | 틀리면 |
|---|---|---|---|---|
| ASM-09-01 | 카탈로그에 `decimals`, `scale`(`ratio`\|`ordinal`), `judgeAs`(`bmi`→`weightKg`)를 추가한다. `bmi`·`visceralFatLevel`·`totalBodyWaterL` 정밀도는 0.1, `romDeg`는 1 → 반영됨: V1-05 §13.1이 `decimals`, `scale`(`ratio`\|`ordinal`), `judgeAs`를 카탈로그 필드로 정의했다(ASM-05-40~42) | §7.5 '저장 정밀도', 부록 A | DF-003, DF-380 | 필드 대신 코드 표로 둔다 |
| ASM-09-02 | 날짜·시간대 계산은 `Asia/Seoul` 고정 | F-BC-01.2, F-SOAP-03.2, AS-15(단일 센터) | DF-127, DF-217 | 센터 시간대 설정 도입 |
| ASM-09-03 | roll·pitch 벡터 파일 `contracts/vectors/level-gate.v1.json`을 새로 둔다 | F-ASM-01.4, F-ASM-03.2 | DF-204 | 단위 테스트 안 표로 둔다 |
| ASM-09-04 | `views[]`에 `imageWidthPx`, `imageHeightPx`(정립 이미지 기준 정수)를 추가한다 | AC-ASM-02.5, §9.2 | DF-006, DF-201, DF-206 | 로컬 사진 크기로만 재계산(③ 철회 뒤에는 어차피 불가) |
| ASM-09-05 | `captureConditions.levelDeg`·`pitchDeg`는 두 뷰 중 절댓값이 큰 값 | §9.2(세션당 한 값) | DF-204 | 정면 뷰 값으로 |
| ASM-09-06 | 모션 값이 없으면 셔터를 막는다(`levelUnavailable`) | AC-ASM-01.2 | DF-203, DF-204 | 경고만 |
| ASM-09-07 | Vision 관절의 left/right는 대상자 기준이다 | F-ASM-02.7, AC-ASM-02.3 | DF-200, DF-207 | 매핑 표 좌우 교체 |
| ASM-09-08 | 제안에서 온 랜드마크는 처음부터 `suggested`(좌표·confidence)를 채운다 | F-ASM-02.5 '옮겼으면 보존' | DF-207, DF-208 | 옮길 때만 채운다 |
| ASM-09-09 | 결과 패키지는 `.bodypathresult` zip(`result.json` + 선택 `thumb.jpg`) | §10.4.3 | DF-301, DF-320 | DF-301 확정 형식으로 교체 |
| ASM-09-10 | 정면 쌍의 수평 간격이 이미지 폭 2% 미만이면 확정 차단 | F-ASM-04.2 | DF-201, DF-208 | 경고로 낮춘다 |
| ASM-09-11 | 자세 지표 확인 경고 임계(CVA 10~80°, 어깨 10°, 머리 15°, 골반 10°)는 제안값이며 규준이 아니다 | §7.7 '규준 없음' | DF-210 | G-06 파일럿으로 조정 |
| ASM-09-12 | 정면 지표의 조건 키 `view`는 `front`이고, 정면 지표의 기준선은 현재 세션과 같은 측면 방향의 기준선 세션이다 | F-ASM-01.1, F-ASM-04.4 | DF-209, DF-216, DF-380 | 정면 지표도 측면 방향이 바뀌면 끊는다 |
| ASM-09-13 | 기기 모델 비교는 앞뒤 공백 제거·연속 공백 축약 후 대소문자 구분 비교 | F-BC-03.4 | DF-127, DF-216 | 대소문자 무시 |
| ASM-09-14 | 줄자 세션 묶음은 같은 `measuredAt`(행 저장 시 한 번 정한 값)으로 식별한다 | F-ASM-06.4 | DF-129, DF-216 | 묶음 ID 필드 추가(PRD 개정) |
| ASM-09-15 | tier1 기준 0.75는 ICC 점추정에 적용한다 | §7.2 | DF-939 | 신뢰구간 하한 적용 |
| ASM-09-16 | 회원 배지는 `rule.protocolVersion == 기록 protocolVersion`일 때만. protocolVersion이 없는 신체조성·줄자는 v1에서 배지 대상이 아니다 | §7.6 | DF-309, DF-381, DF-383 | 신체조성 inHouse 연구 설계 추가 |
| ASM-09-17 | 정책 승인 검증은 `mmtGrade`, `painNrs`, `observedSection` 항목을 거부한다 | §7.3.1, §7.6, 베타 금지 | DF-221, DF-384 | 엔진이 무시(J-3 등)하므로 경고로 낮춰도 안전 |
| ASM-09-18 | 신체조성·줄자의 기본 비교 기준은 같은 시리즈의 직전 active 기록 | §7.5 '기준선'(해당 필드 없음) | DF-380, DF-224 | 최초 기록으로 |
| ASM-09-19 | `romDeg`는 0~220 정수 deg | 부록 A.1, §9.3 | DF-121 | 범위·정밀도 조정 |
| ASM-09-20 | SEM 주 분석은 SD(전체 관측값)×√(1−ICC), √MSE는 민감도 분석. 분석 도구는 소유자가 저장소 밖에서 실행 | §7.3.3 | DF-939 | 분석계획서에서 바꾸면 이 절을 갱신 |
| ASM-09-21 | 수기 입력은 소수 첫째 자리까지만 받는다 | F-BC-03.1, F-ASM-06.5 | DF-127, DF-129 | 둘째 자리 입력을 반올림해 받는다 |
| ASM-09-22 | 가입 회원의 키 기본값은 최근 active 기록의 `derived.heightCmUsed` | F-BC-01.3 | DF-127 | 매번 입력 |
| ASM-09-23 | 체지방률·체지방량 불일치 경고 임계 2.0%p | F-BC-03.3 '큰 불일치' | DF-127 | 임계 조정 |
| ASM-09-24 | 금지어 픽스처 파일 `contracts/fixtures/prohibited-terms/cases.v1.json`, 규칙별 선택 필드 `exceptPhrases[]`, 회원 약어 허용 목록 기본 `["BMI"]` | 부록 C.3, F-SOAP-05.6 | DF-010, DF-309 | V1-12 구조로 맞춘다 |
| ASM-09-25 | 줄자 반복값이 하나여도 저장할 수 있다(권장 안내) | F-ASM-06.4 '기본 2회' | DF-129 | 2개 미만 저장 차단 |
| ASM-09-26 | 줄자 `protocolVersion`(`circ-v1`)은 생성 상수로 둔다(원본은 `metric-catalog.v1.json` 최상위 `circumferenceProtocolVersion`) | F-ASM-06.2 | DF-003, DF-129 | 별도 contracts 파일 |
| ASM-09-27 | O 후보에서 세션 날짜 이후에 측정한 기록은 뺀다 | F-SOAP-03.2 | DF-217 | 포함하고 '세션 이후' 표시 |
| ASM-09-28 | P3에서 오프라인이면 스냅샷 적용을 막고 '온라인 필요'를 보인다 | F-SOAP-03.4, ADR-009 | DF-381 | `pendingPolicy`로 저장 후 재불러오기 |
| ASM-09-29 | 결과 패키지의 단면 수준 문제는 그 단면만 건너뛴다 | §10.4.3 '미확정 단면 거부' | DF-300, DF-320 | 패키지 전체 거부 |
| ASM-09-30 | inHouse MDC95를 정책에 옮길 때 0.1 단위로 올림 | §7.3.3 | DF-384, DF-939 | 반올림 |
| ASM-09-31 | `elapsed_band`·`count_band` 구간은 P1a ASM-P1a-11 값 | §5.5 | DF-033, DF-126 | 레지스트리 값 교체(코드는 생성물) |
| ASM-09-32 | 결과 패키지에는 자유 텍스트 메모를 넣지 않고 `referenceTapeCm`은 단면별로 둔다 | §10.4.3, D10 | DF-301 | 스파인 DTO대로 최상위 |
| ASM-09-33 | 윤곽은 둘레 길이 기준 균등 재표본으로 512점까지 줄이고 둘레 값은 패키지 값을 쓴다 | F-LIDAR-01.5 | DF-320 | Douglas–Peucker 등으로 교체 |
| ASM-09-34 | EXIF 제거 검사는 GPS 외에 기기·시각·렌즈 식별 키까지 본다 | F-ASM-01.7, AC-ASM-01.4 | DF-205 | GPS만 |
| ASM-09-35 | 재검사 분석의 반복은 묶음 안 confirmed 기록 중 `capturedAt` 순 앞 k개 | §7.3.3 | DF-326, DF-939 | 분석계획서 규칙 |
| ASM-09-36 | contracts 카탈로그·vocab 값의 정본은 V1-05 §13(R5) | 부록 A, §7.4 | DF-003, DF-216, DF-380 | 이 문서의 카탈로그 필드·조건 키·family 표기를 V1-05 §13에 맞춰 고친다 |

---

## 20 PRD·스파인·다른 문서와의 충돌과 명확화

| ID | 내용 | 이 문서의 처리 | 필요한 조치 |
|---|---|---|---|
| C-09-01 | PRD §9.2 `views[]`와 V1-05 §4.6에 이미지 폭·높이가 없다. 문서만으로는 AC-ASM-02.5 재계산(픽셀 변환)이 불가능하다 | ASM-09-04로 `imageWidthPx`, `imageHeightPx` 추가 제안 | V1-05·PRD §9.2 개정(schema-change) |
| C-09-02 | 카탈로그 조건 키 이름이 문서마다 다르다: V1-05 §13.1(`stationProfile`, `device.model`, `captureConditions.clothing`) → 해소: V1-05 §13이 정본(토큰은 필드 경로 `device.model`·`captureConditions.clothing`, 예외 `stationProfile`·`nrsScale`; `decimals`·`scale`·`judgeAs` 포함). P0 DF-003은 §13 링크와 개수만 적는다 | [§8.1](#81-가족별-조건-스냅샷) 대응표가 두 표기를 모두 받는다(`nrsScale`은 통증 척도로 비교 없음). ASM-09-01 | DF-003 PR에서 한 표기로 통일(권장: V1-05 §13.1). 판정 엔진·세그먼터의 키 해석은 이 표로 고정 |
| C-09-03 | V1-06 §6.13.4 seriesKey 입력의 `side`, DF-216 `SeriesIdentity.side`가 기울기 지표에도 side를 넣으면 좌우가 바뀔 때 시리즈가 갈라진다(ASM-P1b-17·T20과 충돌) | `sideSeries`([§8.3](#83-시리즈-식별자)) | DF-216 구현 때 `identity()`가 sideSeries를 쓰게 한다 |
| C-09-04 | 기술 스파인 `ResultPackageV1`은 `sections[].confirmed` 하나와 최상위 `referenceTapeCm?`만 있다. PRD F-LIDAR-01.4는 `landmarkConfirmed`, `contourConfirmed`, `captureMode`, 기기, 프로토콜을 요구한다 | [§14.1](#141-패키지-형식제안) 확장 DTO | DF-300·DF-301에서 스키마 확정 |
| C-09-05 | PRD §7.5 '기본은 같은 시리즈의 기준선(isBaseline)'인데 신체조성·줄자에는 `isBaseline`이 없다 | 직전 active 기록(ASM-09-18, V1-06과 같음) | PRD §7.5 문구 보완 제안 |
| C-09-06 | DF-201 `PostureMathError`에 `degenerateGeometry`가 없고 `Confirmability`에 기하 차단 사유가 없다 | [§5.9](#59-참조-구현swift-posturemath)에서 추가 | DF-201 구현 때 타입 확장 |
| C-09-07 | `contracts/posture-protocol.v1.json`(ASM-P1b-05), `contracts/vectors/series-break.v1.json`(ASM-P1b-19), `contracts/vectors/level-gate.v1.json`(ASM-09-03), `contracts/fixtures/prohibited-terms/`, `contracts/fixtures/body/*-input.v1.json`이 기술 스파인 repoLayout의 contracts 목록에 없다 | 이 문서가 경로를 정했다 | V1-04 저장소 배치 갱신 |
| C-09-08 | F-ASM-01.1 '측면 방향이 다르면 conditionMismatch'가 정면 지표에도 적용되는지 PRD가 정하지 않았다 | 정면 지표는 `view=front`(ASM-09-12) | 소유자 확인 |
| C-09-09 | DF-033 예시(P0 백로그)의 `elapsed_band` enum `lt5s, 5to10s, 10to30s, gt30s`가 P1a ASM-P1a-11과 다르다 | ASM-P1a-11 채택(ASM-09-31) | DF-033 구현 때 이 절 값을 쓴다(카드에 'V1-09가 정본'이라고 명시돼 있음) |
| C-09-10 | PRD §9.2 `captureConditions`는 levelDeg·pitchDeg 한 쌍인데 뷰는 둘이다 | ASM-09-05 | — |
| C-09-11 | PRD §7.3.3 SEM 식의 SD 정의(전체 관측값 SD인지 대상자 간 SD인지)가 없다 | ASM-09-20(전체 관측값 SD, √MSE 병기) | 분석계획서에 사전 명시 |
| C-09-12 | PRD §7.4는 `timeOfDayBand`의 `unknown`을 언급하지만 §9.2 enum에는 `unknown`이 없다(자동 산출이라 생기지 않음) | 누락 값은 unknown과 같이 불일치로 처리([§8.2](#82-조건-비교-함수)) | — |
| C-09-13 | 기존 `normalization.round`(dfet:functions/src/clinical/normalization.js:6-9)는 `Number.EPSILON`을 더하는 반올림이라 ASM-P1b-03 규칙과 결과가 다를 수 있다 | 판정 코드에서 재사용하지 않는다([§1.3](#13-공통-수치-규약)) | — |

---

## 21 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |
| v1.0(릴리스 편집) | 2026-09-24 | PostureMath 경로를 `Packages/TrainerCore`로 고침(V1-04 §6.2) | — | 없음 |
| v1.0(정합 패스 2) | 2026-09-24 | family 5개·파생 비교 가족, 조건 키 `nrsScale`, ASM-09-01·C-09-02 해소(R5) | — | 없음 |
| v1.0.1 | 2026-09-24 | 교차 정합성 조정: 카탈로그·vocab 정본을 V1-05 §13으로 고정(ASM-09-36), ASM-09-01·C-09-02 해소 표기, §8.1 `nrsScale` 대응 추가 | — | 없음 |

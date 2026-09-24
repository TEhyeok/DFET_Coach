# ADR-008 자세 랜드마크 엔진: Apple Vision 2D (ML Kit 미채택)

| 항목 | 내용 |
|---|---|
| 문서 ID | ADR-008 |
| 버전 | v1.0 |
| 상태 | 개발 착수 기준(Ready) |
| 작성일 | 2026-09-24 |
| 소유자 | CJH |
| 근거 PRD 절 | F-ASM-02.1~02.7, 부록 A.3, Q-18, AS-12, RISK-02, NFR-15 |
| 관련 에픽·스토리 | EP-14 / DF-200, DF-201, DF-207, DF-208 |
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

**Accepted** (2026-09-24, 소유자 CJH). Q-18 결정 전 기본값을 채택했고, P1b 선행 스파이크 DF-200에서 대상 iPad의 정확도·좌우 매핑·지연을 확인한다.

## 2 맥락

- 체형평가 v1은 정면·측면 2D 사진 정적 자세평가다(D3). 자동 랜드마크는 제안일 뿐이며 C7·견봉·ASIS는 수동 지정이 필수다(F-ASM-02).
- 회원 앱에는 ML Kit 기반 자세 검출이 있지만 운동 폼 전용이다(dfet:lib/services/pose_detection_service.dart:93-363).
- 트레이너 앱은 iOS 17 네이티브이며 새 서드파티 SDK를 늘리고 싶지 않다. 단안 2D 자동 랜드마크는 편향이 있다(RISK-02).

## 3 결정

1. 트레이너 앱은 `VNDetectHumanBodyPoseRequest`(2D)를 PostureVision 타깃의 `LandmarkSuggester` 프로토콜 뒤에 두고 **제안 용도로만** 쓴다.
   ```swift
   public protocol LandmarkSuggester: Sendable {
     var engine: LandmarkEngine { get }            // {name: "appleVision2D", version: OS 버전}
     func suggest(image: CGImage, view: PostureView) async throws -> [LandmarkSuggestion]
   }
   ```
2. 결과마다 `landmarkEngine = {name: "appleVision2D", version: <OS 버전>}`을 기록한다.
3. C7·견봉·ASIS는 엔진과 관계없이 수동 지정·확정이 필수다. auto 상태로는 확정할 수 없다(AC-ASM-02.1).
4. Vision 관절 이름을 피검자 기준 해부학적 좌우 `landmarkCode`로 매핑하는 표를 합성 이미지 테스트로 고정한다(AC-ASM-02.3).
5. 엔진이나 OS 버전이 바뀌어도 기존 기록의 지표를 다시 계산하지 않는다.
6. 회원 앱의 ML Kit는 운동 폼 전용으로 그대로 둔다.
7. 입력은 긴 변 1600px로 축소하고 백그라운드 큐에서 실행한다(NFR-15 제안 ≤2초).

## 4 결과

**좋아지는 점**
- 새 의존성이 없고 오프라인에서 동작한다.
- 엔진을 프로토콜 뒤에 두어 Q-18 결론이 바뀌어도 교체 범위가 PostureVision에 한정된다.

**비용·위험**
- 2D 단안 오차가 있어 photoAuto 값은 판정·회원 공유에서 제외한다(F-ASM-03.5).
- OS 업데이트로 제안 결과가 달라질 수 있어 엔진 버전을 반드시 기록해야 한다.

**후속 작업**
- DF-200 스파이크(2일 상한), DF-201 PostureMath, DF-207 어댑터, DF-208 보정 UI.

## 5 대안

| 대안 | 장점 | 채택하지 않은 이유 |
|---|---|---|
| ML Kit iOS SDK | 회원 앱과 같은 엔진 | CocoaPods 전용, 트레이너 앱에 이득 없음 |
| Vision 3D(`VNDetectHumanBodyPose3DRequest`) | 깊이 정보 | 2D 사진 산식과 무관하고 검증되지 않음 |
| 자체 모델 | 통제 가능 | v1 범위 밖 |

## 6 PRD 근거

F-ASM-02.1~02.7, 부록 A.3, Q-18, AS-12, RISK-02, NFR-15. 설계 반영 위치: [V1-04 §6.1 Capture 계층](../04_ARCHITECTURE.md#61-계층-모델), 산식은 [V1-09](../09_ALGORITHMS_SPEC.md).

## 7 재검토 조건

- DF-200에서 대상 iPad 1장 제안이 2초를 넘거나 좌우 매핑이 불안정하면 Q-18을 다시 연다.
- G-06 결과 photoAuto 편향이 커서 제안이 보정 시간을 늘린다면 자동 제안을 끄는 옵션을 검토한다.

## 8 관련 스토리

DF-200, DF-201, DF-207, DF-208.

## 9 변경 이력

| 버전 | 날짜 | 변경 요지 | PR | PRD 영향 |
|---|---|---|---|---|
| v1.0 | 2026-09-24 | 최초 작성 | — | 없음 |

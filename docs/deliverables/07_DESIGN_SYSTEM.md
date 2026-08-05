# 디자인 토큰·컴포넌트 규칙

## 토큰

모바일 색·간격·반경·그림자는 `lib/theme/tokens.dart`를 단일 기준으로 사용한다. 화면에서 임의 색상을 추가하기보다 `context.wellness` 의미 토큰을 사용한다.

| 용도 | 토큰 예 |
|---|---|
| 배경 | `bgRoot`, `bgCard`, `bgSubtle` |
| 텍스트 | `textPrimary`, `textSecondary`, `textTertiary` |
| 브랜드/상태 | `primary`, `primarySubtle`, `warning`, `energy` |
| 경계 | `border`, `borderSubtle` |
| 반경 | `WellnessRadius.card`, `button`, `chip` |
| 그림자 | `WellnessShadows.soft` |

light/dark는 같은 의미 구조를 유지한다. `ThemeMode.system`은 `MaterialApp.themeMode`에 그대로 전달해 OS 밝기 변화를 따른다.

## 임상 컴포넌트

| 컴포넌트 | 사용 | 상태 규칙 |
|---|---|---|
| `ScoreGauge` | 장·혈액·통합 점수 | null이면 `--`, `산정 준비 중` |
| `RangeBar` | 바이오마커 정상범위 | 범위 없으면 승인 범위 없음 |
| `CompositionBar` | Phylum 구성 | 0 초과 항목, 범례 제한 |
| `ComparisonCard` | 비교값 | 제목·값·해석 분리 |
| `PcoaScatter` | beta diversity | 대상 샘플을 크기·색으로 구분 |
| `AlphaMetricGrid` | 4개 alpha 지표 | 520px 미만 2열, 이상 4열 |
| `GenusAbundanceBar` | Genus 상대량 | 최대값 대비 시각화 |
| `GutHealthSummaryCard` | 홈 요약 | 데이터 없음 CTA |
| `BloodSummaryCard` | 혈액 최신 요약 | 부분·미산정 허용 |
| `BloodPanelCard` | 4패널 | completeness 표시 |
| `BiomarkerRow` | 개별 결과 | 수치·단위·label·range |
| `BloodTrendChart` | 시계열 | 같은 표준 코드/단위만 비교 |
| `ProBloodTable` | 전문가 표 | 원값/표준값 구분 |
| `IntegratedScoreCard` | 통합 요약 | 누락축·완성도 필수 |
| `AxisRadarChart` | 4축 | 누락값은 0 위치로만 시각화, 텍스트에 누락 명시 |
| `CrossInsightCard` | 축간 관계 | 인과 표현 금지 |
| `ActionRecommendationCard` | 행동 제안 | 승인 정책 action만 표시 |
| `HealthTimeline` | 과거 snapshot | 기준시점 순 정렬 |

## 사용자 효능감 UX

통합 케어 화면은 점수 나열보다 사용자가 자신의 변화와 다음 행동을 이해하는 순서로 구성한다.

1. **변화 인지:** 최신 점수보다 이전 동일 정책 대비 증감과 상승 축을 먼저 보여준다.
2. **행동 축소:** 한 화면의 주 행동은 `오늘의 한 가지`로 제한하고 소요 시간·연결 축·확인 시점을 함께 표시한다.
3. **즉시 피드백:** 행동 완료 시 햅틱, 체크 아이콘, 완료 문구를 동시에 제공하고 기기 로컬에 상태를 유지한다.
4. **현재 상태:** 4축 점수와 레이더는 변화·행동 다음에 배치해 상세 근거로 사용한다.
5. **안전한 설명:** 생활 기록과 지표 변화는 `함께 관찰됨`, `연관 가능성`으로 표현하며 인과효과로 단정하지 않는다.

행동 완료 표시는 동기 부여를 위한 개인 기기 상태이며 의료 기록, 임상 판정, 통합 점수 계산에 사용하지 않는다.

## 접근성·반응형

- 최소 검증 폭: 320, 390, 430px.
- 글자 배율: 1.0, 1.3, 2.0에서 overflow가 없어야 한다.
- 긴 식별자·Genus·정책명은 ellipsis 또는 가로 스크롤을 사용한다.
- 색만으로 상태를 전달하지 않고 label과 아이콘을 함께 둔다.
- 점수는 참고용/비진단 문구와 정책 버전을 함께 표시한다.
- 관리자 표는 작은 화면에서 `.table-wrap` 가로 스크롤을 사용한다.

# D-FET 회원 앱 개편 요약 (2026)

> 작성: 2026-06-18 · 대상: `dfet_coach/dfet_coach` (Flutter 회원 앱)
> 1차년도(AI 기반 퍼스널 트레이닝/식단 관리 플랫폼) MVP를 기반으로 한 UI/UX 개편.

---

## 1. 개편 목표

1. **마이크로바이옴(장내미생물) 케어**를 별도 영역으로 추가 — 기존 운동/식단 탭과 성격이 달라 분리.
2. **로그인/온보딩 단계에서 사용자 유형 분기** — 장내미생물 vs 운동·신체조성 vs 통합.
3. **숨겨져 있던 마이크로바이옴 코드 발굴 및 활성화**.
4. **디자인 템플릿 교체** — 다크+네온 → (1차) Soft Wellness → (최종) **로고 기반 스포티 테마**.
5. **하단 탭 축소**(6→4) 및 **라이트/다크 모드** 지원.
6. SOAP 노트(아이패드 트레이너) 영역은 이번 개편에서 **보류**.

---

## 2. 핵심 변경 사항

### 2-1. 사용자 케어 유형 분기
- `UserProfile.careType` 추가: `microbiome` | `fitness` | `both` (`UserCareType` 상수).
- 게스트용 메모리 상태 `guestCareTypeProvider` 추가 (Firestore 프로필 없는 게스트 대응).
- **온보딩 2번째 단계**에 케어 유형 선택 카드 3개 추가 (미선택 시 "다음" 비활성).
- 파일: `lib/models/user_profile.dart`, `lib/state/app_state.dart`, `lib/screens/onboarding_screen.dart`

### 2-2. 마이크로바이옴(장 건강) 화면
- 별개 프로젝트 `~/dfet_final`(HME랩 연동본)에서 화면을 발굴해 이식.
- **16S rRNA(V3-V4) 실제 분석 지표**로 재구성 (일반 소비자용 번역):
  - 알파 다양성 → 메인 점수 게이지 + 정상범위 띠 (Shannon·종 수 병기)
  - 상대적 풍부도 → Phylum 가로 누적바 + 범례
  - 베타 다양성 → "또래 비교" 카드 / 계통학적 유사도 → "닮은 정도 %" 카드
  - 맞춤 추천 카드 + 우상단 `16S rRNA · V3–V4` 메타 배지
- **전문가 상세 화면**(`microbiome_expert_screen.dart`): PCoA 산점도, 알파(Shannon/Simpson/Chao1/OTU), Genus 상대풍부도, UniFrac, 메타데이터(MiSeq·QIIME2).
- 파일: `lib/screens/microbiome/` (screen + expert + components)

### 2-3. 하단 탭 축소 (6 → 4)
- **홈 · 기록 · 리포트 · 내 정보** 4탭 고정.
- **리포트 탭**이 careType별 내용 분기 (운동/식단 통계 ↔ 장 건강, both는 세그먼트 토글) — `report_hub_screen.dart`.
- 커뮤니티는 내 정보 메뉴로, 코칭·장건강 통계는 리포트로 통합.
- 파일: `lib/widgets/shells/ios_destination.dart`, `ios_shell.dart`, `report_hub_screen.dart`

### 2-4. 디자인 시스템 — 로고 기반 스포티 테마
- 로고 색 추출: **딥 네이비 `#141F3A`** (육각형 DF 모노그램).
- 테마: **Navy + Electric Lime** (S1).
  - 라이트: 쿨그레이 배경 + 화이트 카드 + 네이비 텍스트/버튼 + 라임 에너지 포인트
  - 다크: 딥 네이비 배경 + 일렉트릭 라임 강조(버튼·탭·링)
- 토큰: `WellnessColors`(라이트) / `WellnessColorsDark`(다크) + `WellnessScheme`/`context.wellness` (테마 반응형 룩업).
- 에너지 라임(`energy`) 토큰 추가 — Activity Rings 영양 링, 마이크로바이옴 게이지 최고등급에 적용.
- **헤더 로고**: 홈 탭 헤더 "D-FET" 텍스트 → 육각형 로고 마크 (다크=흰색/라이트=네이비 자동).
- 파일: `lib/theme/tokens.dart`, `lib/theme/ios_theme.dart`, `lib/widgets/activity_rings.dart`, `lib/widgets/app_card.dart` 외 다수

### 2-5. 라이트/다크 모드
- 설정 → "화면" 섹션에 **라이트/다크/시스템 토글** 추가.
- 모든 화면이 `context.wellness`(테마 반응형)를 쓰도록 전환 → 토글 시 전 화면 자동 전환.
- 기본값: 라이트.
- 파일: `lib/state/theme_provider.dart`, `lib/screens/settings_screen.dart`, 전 화면

---

## 3. 테스트 & 검증

| 테스트 | 내용 |
|---|---|
| `test/care_type_tabs_test.dart` | 4탭 고정 구성 + careType 직렬화 |
| `test/onboarding_flow_test.dart` | 온보딩 전체 흐름(위젯) |
| `test/login_record_flow_test.dart` | 게스트 로그인 + 식단/운동 기록 추가 |
| `integration_test/onboarding_test.dart` | **실기기/시뮬레이터 e2e** 온보딩 |

- 위젯 테스트 총 **18개 통과**, integration_test 실 시뮬레이터 구동 통과.
- 실행: `flutter test test/` / `flutter test integration_test/ -d <device>`
- ※ 빌드·테스트 시 셸 로케일 `LANG=en_US.UTF-8` 필요 (CocoaPods/폰트).

---

## 4. 보류 / 향후 과제

- SOAP 노트(아이패드 트레이너 앱) 영역 — 이번 개편 제외.
- 일부 `static const _primaryColor = WellnessColors.x` 잔여(컴파일 제약) — 점진 전환 중.
- 커뮤니티 실 데이터 연동, 알림(FCM), 결제 서버 검증 등은 별도 과제.

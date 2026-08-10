# IA·라우트·화면설계

## 모바일 IA

4개 탭은 `StatefulShellRoute.indexedStack`으로 각각 Navigator 상태를 보존한다.

| 영역 | 경로 | 목적 | 주요 상태 |
|---|---|---|---|
| 공개 | `/intro`, `/login` | 소개·회원 인증 | 비로그인 |
| 설정 | `/profile-setup` | 기본 프로필 | 로그인, 온보딩 미완료 |
| 설정 | `/onboarding/careType` | 기존 회원 최초 케어유형 확인 | 뒤로가기 차단 |
| 홈 탭 | `/home/dashboard` | 오늘의 활동·장 요약 | 스크롤·카드 상태 유지 |
| 기록 탭 | `/home/record` | 운동·식단 기록 진입 | 탭 Navigator 유지 |
| 리포트 탭 | `/home/report` | 케어유형/플래그별 세그먼트 | 선택 세그먼트 유지 |
| 내정보 탭 | `/home/myPage` | 프로필·설정 | 탭 Navigator 유지 |
| 내정보 | `/home/myPage/careType` | 케어유형 변경 | 회원 프로필 저장 |
| 내정보 | `/home/myPage/settings/theme` | light/dark/system | OS 테마 추종 |
| 장 | `/home/gut`, `/gut/:reportId` | 목록·소비자 상세 | 본인/담당자/관리자 |
| 장 상세 | `/gut/:reportId/alpha|beta|composition|unifrac` | 세부 지표 | 승인 점수 없으면 원수치만 |
| 장 전문가 | `/gut/:reportId/expert` | PCoA·Genus·UniFrac | 담당 트레이너/관리자 |
| 혈액 | `/home/blood`, `/blood/:reportId` | 목록·검사 상세 | 13종·4패널 |
| 혈액 상세 | `/blood/:reportId/liver|kidney|metabolic|lipid` | 패널별 결과 | 부분 결과 허용 |
| 혈액 추이 | `/blood/trends` | 검사 간 시계열 | 동일 표준 단위 |
| 혈액 전문가 | `/blood/:reportId/expert` | 원단위·플래그·장비 | 담당 트레이너/관리자 |
| 통합 | `/home/insights`, `/insights/:snapshotId` | 4축·타임라인·전후 비교 | 누락 축 명시 |

라우트 가드는 인증→프로필 설정→케어유형 확인→전문가 권한→기능 플래그 순서로 평가한다. Firestore Rules가 최종 데이터 권한을 다시 검사한다.

## 모바일 화면 상태 규칙

| 상태 | 표현 |
|---|---|
| loading | 중앙 진행 표시, 기존 값 임의 생성 금지 |
| empty | 검사/스냅샷 없음과 다음 행동 안내 |
| unscored | 수치 표시, 점수·판정 대신 `산정 준비 중` |
| partial | 완성도와 누락 지표·축 표시 |
| review | 지원하지 않는 단위/검증 사유 표시, 자동 추측 금지 |
| evidence | 출처·수신 범위·정책 버전을 리본으로 표시하고 탭하면 처리 원칙 공개 |
| unauthorized | 리포트 허브로 이동, 데이터는 Rules에서 거부 |
| feature off | 리포트에서 숨김, 딥링크는 리포트 허브로 이동 |

## 관리자 IA

| 경로 | admin | trainer | lab_operator |
|---|:---:|:---:|:---:|
| `/dashboard` | 전체 현황 | 담당 회원 현황 | - |
| `/users` | 전체·역할 변경 | 담당 회원 읽기 | - |
| `/assignments` | 배정 변경 | - | - |
| `/requests` | 전체 처리 | 담당 회원 처리 | - |
| `/content` | 관리 | - | - |
| `/clinical/ingestions` | 수집 | - | 수집 |
| `/clinical/jobs` | 전체 작업 | - | 작업 추적 |
| `/clinical/reports` | 전체 전문가본 | 담당 회원 전문가본 | - |
| `/settings/reference-ranges` | 버전·승인·활성 | - | - |
| `/settings/insight-policies` | 버전·승인·활성 | - | - |
| `/settings/feature-flags` | 점진 활성화 | - | - |
| `/audit` | 조회 | - | - |

Next.js 페이지와 API가 같은 역할 검사를 수행한다. 서버의 Admin SDK 사용 시에도 트레이너 대상 UID를 `trainers/{uid}.memberIds`로 제한한다.

# D-FET Trainer iPad Design System

## Direction
- 현재 기본 홈은 `세션 보드`다.
- 홈의 목적은 `오늘 세션을 시작하고, 회원을 바꾸고, SOAP 정리로 이어지는 실제 작업 흐름`을 바로 처리하는 것이다.
- 첫 화면은 `워크플로우 단계 / 현재 세션 / 다음 액션 / 오늘 볼 회원 / 핵심 지표 / 시각화` 순서로 구성한다.
- Apple 건강 앱형 `요약`은 보조 대시보드로 유지하고, 앱의 첫인상은 cool pastel studio gradient + deep blue hero + blue gradient action 중심으로 간다.

## Visual Rules
- Primary accent: hero blue `#6670D5`, deep hero blue `#17235F`, soft violet `#8675D8`.
- Background: cool pastel studio gradient, cards: clean white/translucent white, hero: deep blue gradient, shadows: soft but visible.
- Status colors are tonal and same-family: stable uses blue, attention uses violet, high risk uses navy. Do not use traffic-light red/green/orange/yellow blocks.
- Typography: SF Rounded는 큰 숫자, 세션 타이틀, chip/label에만 사용하고 본문은 SF Pro 기본 계열로 둔다.
- Icons: filled 아이콘 남용을 피하고 `rectangle.grid.2x2`, `note.text`, `chart.line.uptrend.xyaxis`, `slider.horizontal.3`처럼 얇고 업무형인 SF Symbols를 우선한다.
- Implementation rule: SwiftUI 화면에서는 `.font(.system...)`를 직접 쓰지 않고 `TrainerFont.display/title/label/body`만 사용한다.
- Implementation rule: 화면에서는 SF Symbol 문자열을 직접 쓰지 않고 `TrainerSymbol`을 우선 사용한다. 새 아이콘은 역할을 정한 뒤 토큰에 추가한다.
- Text color rule: 본문은 `primaryText`, 보조문은 `secondaryText`, 약한 메타는 `tertiaryText`, hero 위 텍스트는 `inverseText/inverseSecondaryText/inverseTertiaryText`만 사용한다.
- Avatar rule: 이름 첫 글자 원형 뱃지는 사용하지 않는다. 회원 아바타는 Tapback-Memojis 스타일 이미지 URL을 `member.id` seed로 사용하고, 네트워크 실패 시 로컬 3D fallback을 표시한다. 실제 이름/이메일을 외부 avatar seed로 보내지 않는다.
- Cards: repeated content, metrics, dashboard highlights에만 사용한다. 섹션 전체를 과도하게 카드화하지 않는다.
- Dribbble식 polish는 `레이어, 밀도, 여백, shadow, typography hierarchy`에만 반영한다. 기능과 정보 구조는 네이티브 iPad 업무 앱 기준을 유지한다.
- 색상은 hero blue, navy, violet, pale blue, muted lavender 안에서만 쓴다. 이모지 기반 장식은 사용하지 않는다.

## iPad Layout
- Root navigation: `NavigationSplitView` with sidebar.
- Session Board: 기본 진입 화면이며 큰 blue hero와 세션 workflow를 중심으로 한다.
- Summary: 보조 대시보드이며 Apple 건강 앱형 요약 구조를 따른다.
- Members: 좌측 회원 목록, 우측 회원 상세와 타임라인.
- SOAP: 좌측 세션 큐, 중앙 Pencil/SOAP 작업면, 우측 입력 패널 또는 inspector.
- Compact width: 세로 스택으로 전환하고 입력 패널은 하단으로 내려간다.
- Compact iPad: 업무 순서를 위에서 아래로 읽는다. `워크플로우 단계 -> 현재 세션 -> 다음 액션 -> 회원 큐 -> 지표/시각화` 순서다.
- Wide iPad: 동시에 조작해야 하는 정보를 2단 또는 3단으로 고정한다. 홈은 `현재 세션/지표`와 `다음 액션/회원 큐/시각화` 2단, SOAP는 `세션 큐 / 작업면 / 빠른 입력` 3단이다.
- Stage Manager: 홈은 detail 폭 1120pt 미만, SOAP는 detail 폭 1180pt 미만이면 compact 구조로 내려간다. 방향명보다 실제 사용 가능한 폭을 우선한다.

## Secondary Summary Pattern
- SwiftUI source: `DFETTrainer/Features/Summary/SummaryView.swift`.
- Navigation: iPad sidebar는 유지하고, `요약` 탭에서만 큰 `요약` 타이틀을 가진다.
- Favorites: 오늘 세션, 관리 회원, 평균 통증, 목표 안정만 노출한다.
- Highlights: 통증 추세와 SOAP/홈운동 완료율을 흰 카드 안에서 보여준다.
- Trends: 임상적으로 볼 만한 변화만 행 단위로 표시한다.
- Today Members: 위험도/통증/신호가 있는 회원을 최대 3명까지 보여주고 회원 상세로 이동한다.
- Visual restraint: 세션 보드와 같은 pastel backdrop, blue hero, muted coral accent를 유지하되 정보 카드는 warm white 중심으로 정리한다.

## iPad Session Board
- SwiftUI source: `DFETTrainer/Features/Summary/ProductivityTrainerExampleView.swift`.
- 사용자가 저작권 보유를 명시한 Time Tracking/Productivity reference의 색감과 레이어 문법을 iPad 업무 화면으로 전환한 세션 보드다.
- phone mockup 전시가 아니라 `회원 선택 / 세션 타이머 / SOAP 저장 / 다음 액션 / 회원 큐 / 시각화`를 직접 조작할 수 있게 구성한다.
- 색상은 reference처럼 한 팔레트 안에서 정리된 blue, navy, violet, ink, cool pastel backdrop 중심으로 제한하고, 아이콘은 SF Symbols만 사용한다.
- 이 화면은 앱 기본 진입 라우트이며 `--preview-productivity-example` 실행 인자에서도 확인한다.
- 가로 캡처/QA는 `--preview-productivity-example --preview-landscape` 실행 인자를 사용한다. 실제 앱은 iPad 방향 회전과 Stage Manager 폭에 따라 GeometryReader가 레이아웃을 전환한다.

## Studio Visual Alignment
- `Summary`, `Members`, `SOAP`, `Reports`, `Settings`, `Login`은 같은 cool pastel studio backdrop, blue hero panel, blue gradient primary action, translucent white cards를 공유한다.
- 공통 구현은 `DesignSystem/TrainerTheme.swift`의 `StudioBackdrop`, `StudioHeroCard`, `HealthCard` 스타일을 기준으로 한다.
- iPad에서는 큰 작업 맥락을 blue hero card에 두고, 세부 입력/목록/차트는 glass card로 분리한다.
- 기본 동작 확인용 실행 인자는 `--preview-authenticated`, `--preview-members`, `--preview-soap`, `--preview-reports`, `--preview-settings`, `--preview-productivity-example`, `--preview-landscape`를 사용한다.

## Archived Experiments
- 아래 보드/프리미엄/Ronas/Travel/Focus 방향은 참고용 프로토타입이다. 현재 홈 기본 구현 기준으로 사용하지 않는다.

## Board Workflow
- `예정`: 오늘 수업 예정 회원과 위험 신호를 표시한다.
- `진행 중`: PencilKit 필기 중인 세션을 표시하고 빠른 저장을 제공한다.
- `SOAP 정리`: 수업 후 S/O/A/P 구조화가 필요한 노트를 모은다.
- `공유 완료`: 회원에게 공유된 리포트와 홈운동을 추적한다.
- 카드는 drag/reorder가 가능해야 하며, 선택 시 우측 inspector에서 통증, ROM/MMT, 공유 상태를 바로 수정한다.
- 고충실도 기준안은 `design/prototypes/ipad-trainer-dribbble-board-v3.html` 및 `design/prototypes/ipad-trainer-dribbble-board-v3.png`를 따른다.

## SOAP Workflow
- 기본 진입: S/O/A/P 구조화 입력을 먼저 보여준다.
- 수업 중: 상단 모드에서 `필기`로 전환해 Pencil 기록을 남긴다.
- 공유 전: 내부 필기와 회원 공유 요약을 분리한다.
- 시각화: 통증, 목표 진행, SOAP 완료율을 한 화면에서 확인한다.
- 고충실도 기준안은 `design/prototypes/ipad-trainer-dribbble-soap-v3.html` 및 `design/prototypes/ipad-trainer-dribbble-soap-v3.png`를 따른다.

## Report Chart Rules
- 통증(0-10)과 SOAP 완료율(0-100)은 같은 Y축에 섞지 않는다.
- 리포트 기본 차트는 `통증 변화` 라인/영역 차트와 `SOAP 완료율` 막대 차트로 분리한다.
- 주의 기준선은 통증 6, 목표 기준선은 SOAP 80%로 고정한다.
- `ChartsOrg/Charts(DGCharts)`는 gesture-heavy 세부 리포트나 UIKit 호환 차트가 필요할 때 검토하고, 현재 1차 리포트는 Swift Charts로 유지한다.

## High Fidelity V3
- 목표는 Dribbble의 시각 완성도를 흉내 내는 것이 아니라, 트레이너가 바로 사용할 수 있는 clinical board에 프리미엄 시각 레이어를 입히는 것이다.
- Root 화면은 `top command bar + left navigator + center board + right inspector`의 3단 구성을 유지한다.
- SOAP 화면은 `mode switcher + session queue + Pencil canvas + SOAP inspector`로 구성한다.
- 카드와 패널은 큰 radius, 얕은 border, soft shadow, 약한 glass background를 쓰되 nested card가 과해지지 않게 한다.
- 모든 decorative stroke, chart, chip은 실제 기능 상태와 연결되어야 한다. 의미 없는 그래픽은 넣지 않는다.
- SwiftUI 구현 시 `NavigationSplitView`, `Grid`, `Canvas/PencilKit`, `Charts`, `matchedGeometryEffect` 또는 explicit animation을 기준으로 옮긴다.

## Premium V4 Reset
- V3는 정보 구조가 강하고 시각 매력이 약하다. V4부터는 화면의 첫 인상이 보드가 아니라 `Clinical Studio`처럼 보여야 한다.
- 홈은 작은 카드의 균등 배치보다 `우선 관리 회원`을 크게 보여주는 hero panel을 사용한다.
- 우측은 inspector보다 `Today Queue`로 단순화하고, 실제 처리 순서가 바로 보이게 한다.
- SOAP 화면은 Apple Pencil canvas를 중심에 두고, 좌측 세션 큐와 우측 SOAP Inspector는 배경으로 물러나게 한다.
- 컬러는 charcoal, muted coral, warm white surface를 중심으로 하고 상태 색도 dusty rose, sage, clay처럼 같은 톤 안에서만 쓴다.
- 새 기준안은 `design/prototypes/ipad-trainer-premium-home-v4.html`, `design/prototypes/ipad-trainer-premium-home-v4.png`, `design/prototypes/ipad-trainer-premium-soap-v4.html`, `design/prototypes/ipad-trainer-premium-soap-v4.png`를 우선한다.

## Ronas Inspired V5
- Ronas IT의 모바일 쇼케이스 문법을 참고한다: 큰 타이포, 과감한 hero, 강한 대비, rounded phone-like mock panel, 밝은 accent block.
- D-FET에는 `deep ink control room + warm white clinical workspace + muted coral/blue accent` 조합을 사용한다.
- 홈은 `Trainer Control Room`을 좌측에 강하게 두고, 중앙은 우선 회원의 상태를 큰 product hero처럼 보여준다.
- SOAP는 `Note Mechanic` 구조를 사용한다. 좌측은 세션, 중앙은 Pencil canvas, 우측은 SOAP block과 공유 카드다.
- 텍스트는 줄이고 시각 중심을 키운다. 여러 개의 작은 카드보다 1개의 큰 맥락 카드와 2-3개의 보조 카드를 우선한다.
- 새 기준안은 `design/prototypes/ipad-trainer-ronasit-home-v5.html`, `design/prototypes/ipad-trainer-ronasit-home-v5.png`, `design/prototypes/ipad-trainer-ronasit-soap-v5.html`, `design/prototypes/ipad-trainer-ronasit-soap-v5.png`를 따른다.

## Travel Clean V6
- 사용자가 선호한 Ronas IT `Travel Mobile App`의 핵심 문법을 따른다: monochrome black-and-white, minimalist layout, large visual destination card, very low text density.
- D-FET에서는 destination image를 `우선 회원의 clinical focus visual`로 치환한다. 큰 비주얼 카드 하나가 화면의 인상을 결정해야 한다.
- Accent는 muted coral과 blue만 강하게 쓰고, 상태 표시는 같은 명도/채도의 dusty rose, sage, clay로 제한한다.
- 홈은 `large title + visual focus card + today queue`만 남기고, 나머지는 작은 보조 타일로 낮춘다.
- SOAP는 `dark current note panel + large paper canvas + minimal SOAP inspector` 구조를 사용한다.
- 새 우선 기준안은 `design/prototypes/ipad-trainer-travel-clean-home-v6.html`, `design/prototypes/ipad-trainer-travel-clean-home-v6.png`, `design/prototypes/ipad-trainer-travel-clean-soap-v6.html`, `design/prototypes/ipad-trainer-travel-clean-soap-v6.png`다.
- Figma source: `https://www.figma.com/design/rAJhOLPW15NODunQxJfIkH`, page `Travel Clean V6`, frames `01 Home - Travel Clean V6` and `02 SOAP - Travel Clean V6`.

## Focus Board V7
- 여러 화면을 동시에 정리하지 않고 iPad Home 한 장만 우선 완성한다.
- 첫 화면의 핵심은 `오늘 가장 중요한 회원 + 신체 포커스 + 다음 액션 3개`다.
- 시각 중심은 큰 dark clinical visual card 하나다. 신체 실루엣, 통증 포인트, ROM 카드만 사용한다.
- 우측 queue는 세션 순서를 보여주는 보조 패널로 유지하고, 홈의 주인공이 되지 않게 한다.
- Home에서 노출하는 기능은 `SOAP 시작`, `히스토리`, `ROM/MMT/통증 빠른 입력`, `정리 시작`으로 제한한다.
- 새 기준안은 `design/prototypes/ipad-trainer-focus-board-v7.html` 및 `design/prototypes/ipad-trainer-focus-board-v7.png`다.

## Component Rules
- `HealthCard`: 카드 표준 컨테이너.
- `HealthFavoriteTile`: 요약 수치.
- `HealthTrendRow`: 트렌드/알림 행.
- `PainCompletionChart`: 통증과 완료율 추세.
- `PencilToolbar`: 펜, 형광펜, 지우개, 되돌리기, 빠른 ROM/MMT 입력.

## References
- Apple Food Truck: App/Kit/Widgets 구조, Swift Charts, WidgetKit.
- Tapback-Memojis: MIT 오픈소스 Memoji-style avatar generator. Prototype API only; production에서는 self-host/cache를 우선 검토한다.
- IceCubesApp: 실제 배포급 SwiftUI 앱 구조와 사이드바 UX.
- SBB/Charcoal: 디자인 토큰, Dynamic Type, 컴포넌트 운영.
- Playbook: 컴포넌트 갤러리와 스냅샷 테스트 운영 방식.
- CodeEdit: navigator / editor / inspector 형태의 전문 작업 앱 구조.
- SwiftUI Kanban/Reorderable examples: 세션 카드 drag/reorder 보드 상호작용.
- Apple desktop-class iPad samples: toolbar, pointer, keyboard, multi-selection, document-style action patterns.

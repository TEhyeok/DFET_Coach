# D-FET Design Guidelines

## Product Direction

D-FET is a clinical sports performance tool for trainers and members. The iPad trainer experience should feel like a professional work surface, not a marketing page or a generic AI mockup.

Core design statement:

> During a session, D-FET should feel like paper. After a session, it should behave like structured data.

## Reference Systems

Use these systems as visual and structural references:

- Apple Human Interface Guidelines: native iPad hierarchy, toolbars, split views, sheets, Apple Pencil, system typography.
- Apple Design Resources / iOS and iPadOS UI Kit in Figma: native components, iPad layout proportions, SF type scale, system controls.
- Atlassian Design System: dense operational dashboards, tokens, status usage, tables, filters, enterprise consistency.
- Material 3 Design Kit: token discipline, role-based color naming, state layers. Use as a system reference, not as the visual style for iOS.

Useful links:

- https://developer.apple.com/design/human-interface-guidelines/
- https://developer.apple.com/design/resources/
- https://help.figma.com/hc/en-us/articles/24037833895831-Get-started-with-Apple-s-UI-kit
- https://help.figma.com/hc/en-us/articles/24037724065943-Start-designing-with-UI-kits
- https://atlassian.design/design-system/

## Visual Style

Name: D-FET Trainer Health

Principles:

- Apple Health-inspired summary first experience for trainer workflows.
- Calm, precise, clinical, performance-oriented.
- Dense enough for trainer work, but never noisy during live sessions.
- Light mode first for overview, dashboard, member status, and reporting.
- Dark work-surface mode is reserved for live Apple Pencil sessions only.
- No emoji as functional icons.
- No random color usage.
- No decorative gradients, neon glow, bokeh, blobs, or glass effects unless they serve a native iPad material purpose.
- Cards are for grouped tools or repeated items, not for every section.

## Typography

Primary font:

- iOS/iPadOS: SF Pro via system font.
- Flutter fallback: `-apple-system`, then system sans.
- Korean text should use the platform system Korean glyphs. Do not mix decorative fonts.

Type scale:

- Screen title: 22-24, semibold.
- Section title: 17-19, semibold.
- Body/input: 14-16, regular.
- Metadata/caption: 11-12, regular or medium.
- KPI numbers: 22-28, semibold. Avoid oversized dashboard numbers during session mode.

Rules:

- Letter spacing is 0.
- Avoid all-caps except short clinical labels such as ROM, MMT, SOAP.
- Do not place paragraph explanations in live-session UI.

## Color Tokens

Use semantic tokens. Do not choose colors ad hoc in screens.

Overview base:

- `health.bg.root`: `#F5F5F7`
- `health.bg.card`: `#FFFFFF`
- `health.bg.subtle`: `#FAFAFA`
- `health.text.primary`: `#1D1D1F`
- `health.text.secondary`: `#86868B`
- `health.border.subtle`: `#3C3C4336`
- `health.tint.blue`: `#0071E3`

Live session base:

- `bg.root`: `#0B0D10`
- `bg.surface`: `#141820`
- `bg.panel`: `#171B22`
- `bg.raised`: `#202631`
- `border.subtle`: `#2A303A`
- `border.focus`: `#5B8CFF`

Text:

- `text.primary`: `#F4F7FA`
- `text.secondary`: `#B7C0CC`
- `text.tertiary`: `#778292`
- `text.disabled`: `#4B5563`

Brand:

- `brand.primary`: `#5B8CFF`
- `brand.primaryMuted`: `#243452`
- `brand.onPrimary`: `#FFFFFF`

Clinical status:

- `status.success`: `#32D583`
- `status.warning`: `#FDB022`
- `status.danger`: `#F97066`
- `status.info`: `#7AA7FF`

Usage rules:

- Blue is for primary action, focus, selected tab, and active tools.
- Green is only for saved/normal/success states.
- Amber is only for caution or follow-up due soon.
- Red is only for high-risk/destructive/error states.
- Do not show red, blue, yellow, and green together unless they represent actual status categories.
- Prefer neutral chips for metadata.

## Iconography

Use SF Symbols style or lucide-style line icons.

Rules:

- Stroke icons, 1.5-2 px equivalent.
- No emoji icons in product UI.
- No mixed filled/outlined icon sets in the same toolbar.
- Label destructive icons only when the action could cause data loss.
- Pencil toolbar can use icons only if tool state is obvious.

Recommended icon mapping:

- Save: tray/arrow-down or checkmark-circle.
- Delete: trash.
- Pen: pencil.
- Highlighter: highlighter.
- Eraser: eraser.
- Undo: curved arrow.
- Internal/private: lock.
- Shared: eye or person.
- Follow-up: calendar.
- Risk: alert triangle, but use sparingly.

## Layout Patterns

### iPad Trainer Shell

Default trainer iPad layout:

- Left pane: 260-340 px.
- Main work area: flexible.
- Optional right inspector: collapsed by default during live sessions, expanded in review mode.
- Header is sticky.
- Pencil toolbar is bottom floating or bottom docked.

### Live Session Mode

Purpose: write while coaching.

Visible:

- Member name.
- Session date.
- Autosave status.
- Current SOAP section.
- Large handwriting canvas.
- 3-5 key indicators: pain, body region, risk, follow-up, goal progress.
- Previous note snippets, max 3 rows.
- Quick add chips: pain, ROM, MMT, exercise.
- Pencil toolbar.

Hidden:

- Long descriptions.
- Member share settings.
- Full dashboard charts.
- Full SOAP report.
- Dense form grids.

### Post-Session Review Mode

Purpose: convert session notes into structured SOAP data.

Visible:

- Handwriting preview.
- S/O/A/P structured cards.
- Required field checklist.
- Smart extraction action.
- ROM/MMT/test table.
- Risk/follow-up/goal progress.

### Share Preview Mode

Purpose: protect trainer internal notes and make member-facing content readable.

Visible:

- Internal note panel with lock state.
- Member summary preview.
- Share toggles.
- Sensitive memo warning.
- Final share action.

Rules:

- Raw handwriting is trainer-only by default.
- Member-facing summary is the default shared artifact.
- Sharing raw handwriting requires explicit opt-in.

## Components

### Status Chip

Used for compact states such as risk, autosave, follow-up.

Rules:

- One chip, one meaning.
- Avoid stacking more than 4 chips in one row.
- Use neutral chip for metadata, semantic chip only for actual status.

## Trainer iPad Dashboard V1

Reference direction: professional trainer iPad workspace for SOAP notes, rehabilitation, and functional training.

Scope:

- Applies first to the native SwiftUI trainer screens embedded in the current Flutter iOS app.
- The first production pass covers Home Dashboard, Member Profile / Evaluation, and SOAP Note Writing.
- Schedule, Program, and Alert screens that are not fully implemented must show `추후 추가 예정` clearly inside the same shell.
- Program and Report screens may keep existing behavior but must visually align with the same shell.

Visual rules:

- Use a fixed navy sidebar with white labels and a blue selected state.
- Use the DFET app icon/logo in the sidebar identity area; use SF Symbols only for navigation and workflow actions.
- Use white cards on a very light gray-blue canvas.
- Primary actions use blue. Success, warning, and danger colors are restricted to status dots, small chips, and progress indicators.
- Avoid pastel studio gradients, decorative glass, neon effects, emoji, and random multi-color button blocks in the trainer production UI.
- Tables, forms, and compact status cards are preferred over large marketing-style hero sections.

Screen rules:

- Home Dashboard: today schedule, quick record actions, progress status, alerts, and recent notes must be visible without navigating.
- Member Profile / Evaluation: profile, pain body map, NPRS, goals, ROM/evaluation values, and session history must be managed together.
- SOAP Note Writing: date-based notes, Subjective, Objective, Assessment, Plan segmented editor, handwriting context, pain scale, checklist, attachment placeholder, and save button are the core workflow.
- SOAP handwriting must remain visible as a reference while the trainer types the structured S/O/A/P summary.
- When the keyboard is open, convert the remaining workspace above the keyboard into a 50/50 split: structured SOAP typing on the left and handwriting reference on the right.
- The default SOAP screen should follow the same left typing / right handwriting reference rhythm before the keyboard opens.
- Date selection belongs in a dedicated SOAP date bar, not in the member/status header.
- Pending routes such as Schedule, Program, and Alerts sit in a bottom `구현 전` group and must not navigate until implemented.

Resource defaults:

- Body map uses an in-app SwiftUI silhouette for V1.
- Exercise media and SOAP attachment areas use placeholders until upload/storage is connected.
- Member avatars use the existing generated avatar fallback and do not send names or emails as external avatar seeds.
- Any incomplete feature entry must be labeled as `추후 추가 예정` rather than appearing as a broken or empty screen.

### Metric Row

Used for ROM, MMT, pain, functional tests.

Fields:

- Label
- Side
- Value
- Unit
- Score
- Note

Rules:

- Dense table in review mode.
- Quick add chip in live mode.

### Handwriting Canvas

Rules:

- Canvas should occupy at least 60% of live-session screen area.
- Use subtle ruled lines or dot grid.
- Keep internal/private state visible with a small lock label.
- Do not overlay controls on the main writing path.

### Toolbar

Rules:

- Bottom or trailing edge, reachable by Pencil hand posture.
- Icons only for tools.
- Short labels only for quick data actions.
- Active tool uses brand blue; inactive tools are neutral.

## Screen Examples To Design

Create and maintain these design frames:

1. Live session writing.
2. Live session with quick pain input open.
3. Post-session SOAP review.
4. ROM/MMT table entry.
5. Share preview.
6. Member dashboard.

## Copy Rules

Use short labels:

- Good: `자동저장`, `세션 후 정리`, `내부 메모`, `요약 공유`.
- Avoid: long explanatory text in live-session UI.

Member-facing copy should be plain Korean:

- `오늘 상태`
- `오늘 진행`
- `홈 운동`
- `다음 계획`

Trainer-only copy can use clinical abbreviations:

- SOAP
- ROM
- MMT
- RTP

## Anti-Patterns

Do not:

- Use emoji in UI controls.
- Use red/blue/yellow/green as decoration.
- Put every section into a card.
- Use large marketing hero layouts inside the app.
- Add decorative gradients or glowing surfaces.
- Show member sharing controls during active coaching unless the trainer opens share mode.
- Rely only on handwriting for searchable data.

## Implementation Notes

Flutter should map these guidelines into:

- `lib/theme/tokens.dart` for semantic colors.
- `lib/theme/text_styles.dart` and `lib/theme/ios_text_styles.dart` for typography.
- Shared status chip, metric row, handwriting canvas, and toolbar widgets.
- iPad-specific split layout helpers.

Any new UI should reference this file before implementation.

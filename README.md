# D-FET Coach

D-FET 통합 케어 서비스 저장소입니다.

- `lib/`: Flutter 회원 앱(iOS/Android)과 종료 전까지 유지하는 기존 Flutter Web 관리자
- `functions/`: Node.js 22 Firebase Functions와 임상 수집·정규화·스냅샷 처리
- `admin_web/`: TypeScript·Next.js App Router 관리자 웹
- `schemas/`: 검사 수집 JSON Schema
- `docs/deliverables/`: WBS, 화면, 기능, DB, 인터페이스, 테스트, 디자인 명세
- `trainer_ios/`: 기존 SwiftUI 트레이너 앱(이번 UI 개편 범위 밖)

## 빠른 검증

```bash
flutter pub get
flutter analyze
flutter test

npm ci --prefix functions
npm --prefix functions test

npm ci --prefix admin_web
npm --prefix admin_web run typecheck
npm --prefix admin_web run build
```

Rules 테스트는 Firebase Emulator가 필요합니다.

```bash
firebase emulators:exec --only firestore,storage --project dfet-rules-test \
  "npm --prefix functions run test:rules"

# 합성 키를 functions/.secret.local에 설정한 뒤 임상 종단검증
firebase emulators:exec --only functions,firestore,storage --project dfet-e2e \
  "npm --prefix functions run test:e2e"
```

## iOS Simulator

실기기 ML Kit 의존성은 유지하고 시뮬레이터에서만 no-op pose 패키지를 쓰는 안전한 래퍼입니다.

```bash
tool/ios_simulator.sh build
tool/ios_simulator.sh run <simulator-udid>
```

스크립트는 임시 override를 적용하고 종료 시 실제 ML Kit lockfile과 Pods를 복원합니다. 시뮬레이터 빌드에서는 자세 인식 기능을 사용할 수 없습니다.

## 임상 안전 기본값

- 기관 승인·활성 정책이 없으면 검사 수치는 표시하지만 점수와 판정은 `산정 준비 중`입니다.
- `appConfig/features`가 없으면 장·혈액·통합 기능은 모두 비활성입니다.
- 실제 건강데이터 투입 전 보존·삭제·동의 정책 승인이 필요합니다.

자세한 구현·출시 기준은 [통합 케어 산출물](docs/deliverables/README.md)을 참조하세요.

# iOS 시뮬레이터 빠른 실행 가이드

## 문제점
처음 빌드 시 Xcode 빌드가 5분 이상 소요됨 (317초+)

---

## 빠른 실행 방법

### 1. 시뮬레이터 미리 부팅 (가장 효과적)
```bash
# 터미널에서 미리 실행
open -a Simulator

# 또는 특정 기기 지정
xcrun simctl boot "iPhone 15 Pro"
open -a Simulator
```

### 2. Hot Reload 활용 (최고 속도)
앱이 이미 실행 중이라면:
- `r` : Hot Reload (0.1초, UI 변경사항)
- `R` : Hot Restart (2-3초, 상태 초기화)

**코드 수정 후 전체 재빌드하지 마세요!**

### 3. 캐시된 빌드 사용
```bash
# 첫 빌드 후에는 빠름 (10-30초)
flutter run -d "iPhone 15 Pro"

# 강제 재빌드 (피하세요)
flutter clean  # 이거 하면 다시 5분+
```

---

## 일일 워크플로우

### 아침 시작
```bash
# 1. 시뮬레이터 먼저 켜기
open -a Simulator

# 2. 앱 실행 (첫 빌드만 오래 걸림)
cd ~/dfet_coach/dfet_coach
flutter run
```

### 개발 중
- 코드 수정 → `r` (Hot Reload)
- 상태 리셋 필요 → `R` (Hot Restart)
- 앱 종료하지 않고 계속 개발

### 퇴근 전
- `q` 로 종료하거나 그냥 둠
- 시뮬레이터는 켜둔 채로 둬도 됨

---

## 빌드 시간 비교

| 상황 | 시간 | 명령어 |
|------|------|--------|
| 첫 빌드 (클린) | 5-7분 | `flutter clean && flutter run` |
| 캐시된 빌드 | 10-30초 | `flutter run` |
| Hot Restart | 2-3초 | `R` |
| Hot Reload | 0.1-0.5초 | `r` |

---

## 피해야 할 것들

### 절대 하지 마세요
```bash
flutter clean           # 캐시 전부 삭제
rm -rf build/          # 빌드 폴더 삭제
rm -rf ios/Pods/       # Pod 재설치 필요
```

### 필요할 때만
```bash
# 라이브러리 추가/삭제 시
flutter pub get

# iOS 네이티브 문제 시
cd ios && pod install && cd ..
```

---

## 유용한 단축 명령어

### ~/.zshrc 에 추가
```bash
# 시뮬레이터 빠른 시작
alias sim='open -a Simulator'
alias simboot='xcrun simctl boot "iPhone 15 Pro" 2>/dev/null; open -a Simulator'

# dfet_coach 앱 실행
alias dfet='cd ~/dfet_coach/dfet_coach && flutter run'
alias dfetdev='cd ~/dfet_coach/dfet_coach && flutter run -d "iPhone 15 Pro"'

# 기기 목록
alias devices='flutter devices'
```

사용:
```bash
source ~/.zshrc
sim          # 시뮬레이터 열기
dfet         # 앱 실행
```

---

## 트러블슈팅

### "No devices found"
```bash
xcrun simctl list devices available | grep "iPhone"
# 사용 가능한 기기 확인 후 부팅
```

### 빌드가 계속 느림
```bash
# Xcode 캐시 확인
ls -la ~/Library/Developer/Xcode/DerivedData/

# 특정 프로젝트만 삭제 (전체 삭제 X)
# DerivedData에서 dfet_coach 관련만 삭제
```

### 시뮬레이터 응답 없음
```bash
# 시뮬레이터 재시작
xcrun simctl shutdown all
open -a Simulator
```

---

## 최적 개발 환경

1. **시뮬레이터를 항상 켜둠** - 메모리 여유 있으면
2. **flutter run 종료하지 않음** - Hot Reload 사용
3. **flutter clean 피함** - 진짜 필요할 때만
4. **VS Code/Android Studio** - IDE에서 바로 실행

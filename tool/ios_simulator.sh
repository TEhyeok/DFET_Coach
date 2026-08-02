#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERRIDE_FILE="$PROJECT_DIR/pubspec_overrides.yaml"
OVERRIDE_TEMPLATE="$PROJECT_DIR/tool/ios_simulator/pubspec_overrides.yaml"
LOCK_FILE="$PROJECT_DIR/pubspec.lock"
POD_LOCK_FILE="$PROJECT_DIR/ios/Podfile.lock"
PODS_DIR="$PROJECT_DIR/ios/Pods"
BACKUP_DIR="$(mktemp -d)"
MODE="${1:-build}"
DEVICE_ID="${2:-}"

restore_project() {
  if [[ -f "$BACKUP_DIR/pubspec_overrides.yaml" ]]; then
    cp "$BACKUP_DIR/pubspec_overrides.yaml" "$OVERRIDE_FILE"
  else
    rm -f "$OVERRIDE_FILE"
  fi
  if [[ -f "$BACKUP_DIR/pubspec.lock" ]]; then
    cp "$BACKUP_DIR/pubspec.lock" "$LOCK_FILE"
  fi
  (cd "$PROJECT_DIR" && flutter pub get >/dev/null)
  rm -rf "$PODS_DIR"
  if [[ -f "$BACKUP_DIR/Podfile.lock" ]]; then
    cp "$BACKUP_DIR/Podfile.lock" "$POD_LOCK_FILE"
  fi
  (cd "$PROJECT_DIR/ios" && pod install >/dev/null)
  rm -rf "$BACKUP_DIR"
}
trap restore_project EXIT INT TERM

if [[ -f "$OVERRIDE_FILE" ]]; then
  cp "$OVERRIDE_FILE" "$BACKUP_DIR/pubspec_overrides.yaml"
fi
if [[ -f "$LOCK_FILE" ]]; then
  cp "$LOCK_FILE" "$BACKUP_DIR/pubspec.lock"
fi
if [[ -f "$POD_LOCK_FILE" ]]; then
  cp "$POD_LOCK_FILE" "$BACKUP_DIR/Podfile.lock"
fi
cp "$OVERRIDE_TEMPLATE" "$OVERRIDE_FILE"

cd "$PROJECT_DIR"
flutter clean
rm -rf "$PODS_DIR"
rm -f "$POD_LOCK_FILE"
flutter pub get

case "$MODE" in
  build)
    flutter build ios --simulator --debug \
      --dart-define=DFET_IOS_SIMULATOR=true
    ;;
  run)
    if [[ -z "$DEVICE_ID" ]]; then
      DEVICE_ID="$(flutter devices --machine | ruby -rjson -e 'puts JSON.parse(STDIN.read).find { |d| d["targetPlatform"]&.start_with?("ios") }&.fetch("id", "")')"
    fi
    if [[ -z "$DEVICE_ID" ]]; then
      echo "사용 가능한 iOS 시뮬레이터가 없습니다." >&2
      exit 1
    fi
    flutter run -d "$DEVICE_ID" --dart-define=DFET_IOS_SIMULATOR=true
    ;;
  settings)
    grep -R "EXCLUDED_ARCHS" ios/Flutter ios/Runner.xcodeproj \
      "ios/Pods/Target Support Files/Pods-Runner" || true
    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
      -configuration Debug -sdk iphonesimulator -showBuildSettings |
      grep -E '(^| )ARCHS =|EXCLUDED_ARCHS'
    ;;
  *)
    echo "사용법: tool/ios_simulator.sh [build|run|settings] [device-id]" >&2
    exit 2
    ;;
esac

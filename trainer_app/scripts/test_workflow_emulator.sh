#!/usr/bin/env bash
# Consent/body composition integration tests with synthetic data only (project demo-dfet).
# Usage: bash trainer_app/scripts/test_workflow_emulator.sh [derived-data-path] [extra xcodebuild args...]
# Requires Node 22, Java 21+, firebase-tools >= 15 and Xcode on the caller's PATH; functions/node_modules installed.
# Set XCODEBUILD_DESTINATION to override the default iPad (e.g. 'platform=iOS Simulator,id=<UDID>').
# Set DFET_EMULATOR_PORT_OFFSET=1000 to run beside another emulator suite (DEBUG builds only; default 0).
# XCODEBUILD_EXTRA_ARGS accepts whitespace-separated arguments; use trailing arguments for values containing spaces.
# Example: XCODEBUILD_DESTINATION='id=<UDID>' bash trainer_app/scripts/test_workflow_emulator.sh /tmp/dfet-workflow -parallel-testing-enabled NO
# The tests create their own fixtures. No production Firebase configuration or Functions .env files are copied.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DERIVED=${1:-"$ROOT/trainer_app/build/DerivedData-workflow-emulator"}
if [[ $# -gt 0 ]]; then shift; fi
mkdir -p "$DERIVED"
DERIVED=$(cd "$DERIVED" && pwd)
LOG="$DERIVED-test.log"

for tool in node java firebase xcodebuild lsof; do
  command -v "$tool" >/dev/null || { echo "missing tool on PATH: $tool" >&2; exit 1; }
done
if [[ $(node -p 'process.versions.node.split(".")[0]') != 22 ]]; then
  echo "put Node 22 on PATH before running this script" >&2
  exit 1
fi
if [[ ! -d "$ROOT/functions/node_modules" ]]; then
  echo "install functions dependencies before running this script" >&2
  exit 1
fi
PORT_OFFSET=$(node -e '
  const raw = process.env.DFET_EMULATOR_PORT_OFFSET ?? "0";
  const value = Number(raw);
  if (!/^[0-9]+$/.test(raw) || !Number.isSafeInteger(value) || value > 46336) {
    console.error("DFET_EMULATOR_PORT_OFFSET must be an integer from 0 through 46336");
    process.exit(1);
  }
  process.stdout.write(String(value));
')
AUTH_PORT=$((19099 + PORT_OFFSET))
FIRESTORE_PORT=$((18080 + PORT_OFFSET))
FUNCTIONS_PORT=$((5001 + PORT_OFFSET))
STORAGE_PORT=$((19199 + PORT_OFFSET))
HUB_PORT=$((4400 + PORT_OFFSET))
LOGGING_PORT=$((4500 + PORT_OFFSET))
for port in "$AUTH_PORT" "$FIRESTORE_PORT" "$FUNCTIONS_PORT" "$STORAGE_PORT" "$HUB_PORT" "$LOGGING_PORT"; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "emulator port $port is already in use; retry after the other run finishes (no process was stopped)" >&2
    exit 1
  fi
done

DESTINATION=${XCODEBUILD_DESTINATION:-}
if [[ -z "$DESTINATION" ]]; then
  DESTINATION="id=$(bash "$ROOT/trainer_app/scripts/ci_pick_ipad.sh")"
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dfet-workflow-emulator.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT
mkdir "$SANDBOX/functions"
cp "$ROOT/functions/index.js" "$ROOT/functions/package.json" "$ROOT/functions/package-lock.json" "$SANDBOX/functions/"
cp -R "$ROOT/functions/src" "$SANDBOX/functions/src"
ln -s "$ROOT/functions/node_modules" "$SANDBOX/functions/node_modules"
cp "$ROOT/firestore.rules" "$ROOT/storage.rules" "$SANDBOX/"
cat > "$SANDBOX/firebase.json" <<JSON
{
  "functions": {"source": "functions", "runtime": "nodejs22"},
  "firestore": {"rules": "firestore.rules"},
  "storage": {"rules": "storage.rules"},
  "emulators": {
    "auth": {"host": "127.0.0.1", "port": $AUTH_PORT},
    "firestore": {"host": "127.0.0.1", "port": $FIRESTORE_PORT},
    "functions": {"host": "127.0.0.1", "port": $FUNCTIONS_PORT},
    "storage": {"host": "127.0.0.1", "port": $STORAGE_PORT},
    "hub": {"host": "127.0.0.1", "port": $HUB_PORT},
    "logging": {"host": "127.0.0.1", "port": $LOGGING_PORT},
    "ui": {"enabled": false},
    "singleProjectMode": true
  }
}
JSON

XCODE=(xcodebuild test -project "$ROOT/trainer_app/DFETTrainer.xcodeproj" -scheme DFETTrainer
  -destination "$DESTINATION" -derivedDataPath "$DERIVED")
if [[ -n "${XCODEBUILD_EXTRA_ARGS:-}" ]]; then
  read -r -a EXTRA_ARGS <<< "$XCODEBUILD_EXTRA_ARGS"
  XCODE+=("${EXTRA_ARGS[@]}")
fi
XCODE+=("$@" -only-testing:DFETTrainerIntegrationTests/ConsentBodyWorkflowEmulatorTests
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
# TEST_RUNNER_ variables must reach xcodebuild as environment, not build settings.
# Auth uses the simulator keychain, so keep ad-hoc signing enabled.
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\n'
  printf '%q ' env TEST_RUNNER_DFET_AUTH_EMULATOR=1 TEST_RUNNER_DFET_FIRESTORE_EMULATOR=1 \
    TEST_RUNNER_DFET_FUNCTIONS_EMULATOR=1 "TEST_RUNNER_DFET_EMULATOR_PORT_OFFSET=$PORT_OFFSET" "${XCODE[@]}"
  printf '\n'
} > "$SANDBOX/run-tests.sh"
printf -v TEST_COMMAND '%q %q' bash "$SANDBOX/run-tests.sh"

cd "$SANDBOX"
# Only synthetic Function configuration is supplied. Demo projects cannot reach live Firebase resources.
env -u GOOGLE_APPLICATION_CREDENTIALS -u FIREBASE_CONFIG -u FIREBASE_TOKEN \
  GCLOUD_PROJECT=demo-dfet GOOGLE_CLOUD_PROJECT=demo-dfet FUNCTIONS_EMULATOR=true \
  INGEST_HMAC_KEYS='{"e2e":"emulator-only-secret"}' \
  firebase emulators:exec --only auth,firestore,functions,storage --project demo-dfet \
    --config "$SANDBOX/firebase.json" "$TEST_COMMAND" 2>&1 | tee "$LOG"

if grep -qiE 'ConsentBodyWorkflowEmulatorTests.*skipped|Test skipped|XCTSkip' "$LOG"; then
  echo "workflow tests were skipped; verify all three emulator flags reached the test process" >&2
  exit 1
fi
if ! grep -qE "Test (Suite|Case).*ConsentBodyWorkflowEmulatorTests.*passed" "$LOG" || \
   ! grep -qE 'Executed [1-9][0-9]* tests?, with 0 failures' "$LOG"; then
  echo "no successful workflow test execution found in $LOG" >&2
  exit 1
fi
echo "workflow emulator tests passed; log: $LOG"

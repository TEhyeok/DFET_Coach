#!/usr/bin/env bash
# DF-012 TC-DF012-02/03: runs FirebaseDataTests/AuthEmulatorTests against the Auth emulator (project demo-dfet).
# Usage (repo root or anywhere): bash trainer_app/scripts/test_auth_emulator.sh [derived-data-path]
# Needs firebase-tools >= 15 and Java 21 on PATH. CI automation is DF-107.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DERIVED=${1:-"$ROOT/trainer_app/build/DerivedData-auth-emulator"}
UDID=$(bash "$ROOT/trainer_app/scripts/ci_pick_ipad.sh")
cd "$ROOT"
firebase emulators:exec --only auth --project demo-dfet \
  "xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -destination id=${UDID} \
    -derivedDataPath '${DERIVED}' -only-testing:FirebaseDataTests/AuthEmulatorTests \
    TEST_RUNNER_DFET_AUTH_EMULATOR=1 CODE_SIGNING_ALLOWED=NO"

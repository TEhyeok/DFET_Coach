#!/usr/bin/env bash
# Emulator integration tests, hosted in the app (project demo-dfet): DF-012 AuthEmulatorTests (TC-DF012-02/03) and
# DF-013 MemberDirectoryEmulatorTests (TC-DF013-05) and DF-104 RemoteWriterEmulatorTests (write reconciliation)
# against the Auth and Firestore emulators with firestore.rules.
# Usage (from anywhere): bash trainer_app/scripts/test_auth_emulator.sh [derived-data-path]
# Needs firebase-tools >= 15 and Java 21 on PATH. Extra xcodebuild arguments can be passed in XCODEBUILD_EXTRA_ARGS.
# CI automation is DF-107. Fails when the tests were skipped instead of run.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DERIVED=${1:-"$ROOT/trainer_app/build/DerivedData-auth-emulator"}  # separate from unsigned builds
UDID=$(bash "$ROOT/trainer_app/scripts/ci_pick_ipad.sh")
LOG="$DERIVED-test.log"
mkdir -p "$(dirname "$LOG")"
cd "$ROOT"
# TEST_RUNNER_<VAR> must be in xcodebuild's environment (not a build setting) to reach the test process.
# Firebase Auth needs the keychain, which a simulator app only gets when it is signed: ad-hoc "Sign to Run Locally"
# (no team, no profile). CODE_SIGNING_ALLOWED=NO fails every sign-in with keychain error 17995.
firebase emulators:exec --only auth,firestore --project demo-dfet \
  "TEST_RUNNER_DFET_AUTH_EMULATOR=1 TEST_RUNNER_DFET_FIRESTORE_EMULATOR=1 xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer \
    -destination id=${UDID} -derivedDataPath '${DERIVED}' ${XCODEBUILD_EXTRA_ARGS:-} \
    -only-testing:DFETTrainerIntegrationTests/AuthEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/MemberDirectoryEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/RemoteWriterEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/PendingMemberEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/SessionSignOutEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/SessionSignOutOrderTests \
    -only-testing:DFETTrainerIntegrationTests/SessionResumeTests \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=" 2>&1 | tee "$LOG"
if grep -qE "(AuthEmulatorTests|MemberDirectoryEmulatorTests|RemoteWriterEmulatorTests|PendingMemberEmulatorTests|SessionSignOutEmulatorTests).* skipped" "$LOG"; then
  echo "emulator tests were skipped: the emulator flag did not reach the test process" >&2
  exit 1
fi
grep -q "Executed [1-9][0-9]* tests\?, with 0 failures" "$LOG"

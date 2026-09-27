#!/usr/bin/env bash
# Emulator integration tests, hosted in the app (project demo-dfet): DF-012 AuthEmulatorTests (TC-DF012-02/03) and
# DF-013 MemberDirectoryEmulatorTests (TC-DF013-05), DF-104 RemoteWriterEmulatorTests (write reconciliation) and
# DF-110/DF-111 ConsentStateEmulatorTests (consent reads)
# against the Auth and Firestore emulators with firestore.rules, and the DF-109~DF-113 consent flow end to end
# (ConsentFlowEmulatorTests) against the real `recordConsent` in the Functions emulator. Before the tests the DF-109
# test consent documents are published to the emulator by functions/scripts/publish-test-consent-documents.js.
# Usage (from anywhere): bash trainer_app/scripts/test_auth_emulator.sh [derived-data-path]
# Needs firebase-tools >= 15, Node 22 and Java 21 on PATH, and `npm ci --prefix functions` (the Functions emulator
# loads functions/). Extra xcodebuild arguments can be passed in XCODEBUILD_EXTRA_ARGS, a simulator in DFET_SIM_UDID.
# CI automation is DF-107. Fails when the tests were skipped instead of run.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DERIVED=${1:-"$ROOT/trainer_app/build/DerivedData-auth-emulator"}  # separate from unsigned builds
UDID=${DFET_SIM_UDID:-$(bash "$ROOT/trainer_app/scripts/ci_pick_ipad.sh")}  # DFET_SIM_UDID: a given simulator
LOG="$DERIVED-test.log"
mkdir -p "$(dirname "$LOG")"
cd "$ROOT"
if [ ! -d "$ROOT/functions/node_modules" ]; then
  echo "functions/node_modules is missing: run npm ci --prefix functions (the Functions emulator loads it)" >&2
  exit 1
fi
# TEST_RUNNER_<VAR> must be in xcodebuild's environment (not a build setting) to reach the test process.
# Firebase Auth needs the keychain, which a simulator app only gets when it is signed: ad-hoc "Sign to Run Locally"
# (no team, no profile). CODE_SIGNING_ALLOWED=NO fails every sign-in with keychain error 17995.
# emulators:exec sets FIRESTORE_EMULATOR_HOST for the command; the publish script requires it for a demo-* project.
firebase emulators:exec --only auth,firestore,functions --project demo-dfet \
  "node functions/scripts/publish-test-consent-documents.js --apply --project demo-dfet && \
  TEST_RUNNER_DFET_AUTH_EMULATOR=1 TEST_RUNNER_DFET_FIRESTORE_EMULATOR=1 TEST_RUNNER_DFET_FUNCTIONS_EMULATOR=1 \
  xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer \
    -destination id=${UDID} -derivedDataPath '${DERIVED}' ${XCODEBUILD_EXTRA_ARGS:-} \
    -only-testing:DFETTrainerIntegrationTests/AuthEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/MemberDirectoryEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/RemoteWriterEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/PendingMemberEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/ConsentStateEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/ConsentFlowEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/SessionSignOutEmulatorTests \
    -only-testing:DFETTrainerIntegrationTests/SessionSignOutOrderTests \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=" 2>&1 | tee "$LOG"
if grep -qE "(AuthEmulatorTests|MemberDirectoryEmulatorTests|RemoteWriterEmulatorTests|PendingMemberEmulatorTests|ConsentStateEmulatorTests|ConsentFlowEmulatorTests|SessionSignOutEmulatorTests).* skipped" "$LOG"; then
  echo "emulator tests were skipped: the emulator flag did not reach the test process" >&2
  exit 1
fi
grep -q "Executed [1-9][0-9]* tests\?, with 0 failures" "$LOG"

#!/usr/bin/env bash
# Self-test for tool/lint/static-guards.sh (DF-011: TC-DF011-01, TC-DF011-02; V1-10 §16.2).
# Builds throwaway trees in a temp directory, drops one fixture from tool/lint/test/fixtures/static-guards/ into the
# guarded scope, and checks the exit code and the reported guard ID. Also runs the real repository against the
# committed baseline and against edited copies of it.
#
# Usage: bash tool/lint/test/static-guards.test.sh      Exit: 0 all pass, 1 any failure.
set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
GUARD="$REPO/tool/lint/static-guards.sh"
ALLOW="$REPO/tool/lint/static-guards.allow"
FIX="$HERE/fixtures/static-guards"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/static-guards-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

TC="trainer_app/Packages/TrainerCore/Sources"
TK="trainer_app/Packages/TrainerKit/Sources"
passed=0
failed=0
OUT=""
RC=0

ok() { passed=$((passed + 1)); echo "ok     $1"; }
not_ok() { failed=$((failed + 1)); echo "not ok $1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/       | /'; }

# A minimal tree with every scope root the guard requires, benign files and an empty baseline.
new_tree() {
  local t="$TMP/tree.$1"
  rm -rf "$t"
  mkdir -p "$t/$TC/TrainerDomain" "$t/$TC/SyncEngine" "$t/$TK/FeatureSOAP" "$t/$TK/FirebaseData" \
    "$t/trainer_app/App" "$t/lib/services" "$t/admin_web/lib" "$t/ios/Runner"
  printf 'public enum TrainerDomain {}\n' > "$t/$TC/TrainerDomain/TrainerDomain.swift"
  printf 'import FirebaseFirestore\n' > "$t/$TK/FirebaseData/FirebaseData.swift"
  printf 'import FirebaseData\nimport SwiftUI\n' > "$t/trainer_app/App/AppDelegate.swift"
  printf "final x = 'memberSummaries';\n" > "$t/lib/services/firestore_service.dart"
  : > "$t/allow"
  printf '%s\n' "$t"
}

run() { # run ROOT [ALLOW]
  RC=0
  OUT="$(bash "$GUARD" --root "$1" --allow "${2:-$1/allow}" 2>&1)" || RC=$?
}

place() { # place TREE FIXTURE DEST
  mkdir -p "$(dirname "$1/$3")"
  cp "$FIX/$2" "$1/$3"
}

# ---------------------------------------------------------------------------------------------------------------
# TC-DF011-01: one violation file per guard fails with that guard's ID and no other.
# Format: <AC>|<guard>|<fixture>|<destination>|<expected finding count>
CASES="
AC-DF-011.1|G1|violations/G1-core-import.swift.fixture|$TC/TrainerDomain/G1Violation.swift|1
AC-DF-011.1|G1|violations/G1-feature-import.swift.fixture|$TK/FeatureSOAP/G1Violation.swift|1
AC-DF-011.1|G1|violations/G1-app-sdk-import.swift.fixture|trainer_app/App/G1Violation.swift|1
AC-DF-011.2|G2|violations/G2-swift-download-url.swift.fixture|$TK/FirebaseData/G2Violation.swift|1
AC-DF-011.2|G2|violations/G2-swift-download-url-closure.swift.fixture|$TK/FeatureSOAP/G2Violation.swift|1
AC-DF-011.4|G2|violations/G2-dart-get-download-url.dart.fixture|lib/services/g2_violation.dart|1
AC-DF-011.4|G2|violations/G2-admin-web.ts.fixture|admin_web/lib/g2-violation.ts|1
AC-DF-011.2|G3|violations/G3-interpolation.swift.fixture|$TK/FeatureSOAP/G3Violation.swift|1
AC-DF-011.2|G3|violations/G3-concatenation.swift.fixture|trainer_app/App/G3Violation.swift|1
AC-DF-011.2|G4|violations/G4-native-id.swift.fixture|$TK/FeatureSOAP/G4Violation.swift|1
AC-DF-011.2|G4|violations/G4-in-legacy-soap-view.swift.fixture|$TK/FeatureSOAP/LegacySoapView.swift|1
AC-DF-011.2|G5|violations/G5-ink-key.swift.fixture|$TK/FeatureSOAP/G5Violation.swift|1
AC-DF-011.2|G5|violations/G5-native-ink-key.swift.fixture|$TC/SyncEngine/G5Violation.swift|1
AC-DF-011.2|G5|violations/G5-drawing-data-key.swift.fixture|$TK/FirebaseData/G5Violation.swift|1
AC-DF-011.2|G6|violations/G6-shared-true.swift.fixture|$TK/FeatureSOAP/G6Violation.swift|1
AC-DF-011.2|G7|violations/G7-tapback.swift.fixture|$TK/FeatureSOAP/G7Violation.swift|1
AC-DF-011.3|G8|violations/G8-firebase-data-print.swift.fixture|$TK/FirebaseData/G8Violation.swift|1
AC-DF-011.3|G8|violations/G8-sync-engine-debug-print.swift.fixture|$TC/SyncEngine/G8Violation.swift|1
AC-DF-011.4|G9|violations/G9-raw-collections.dart.fixture|lib/screens/g9_violation.dart|5
"
i=0
while IFS='|' read -r ac gid fixture dest count; do
  [ -n "$ac" ] || continue
  i=$((i + 1))
  name="$ac TC-DF011-01 $gid fails on $(basename "$fixture" .fixture) at $dest"
  t="$(new_tree "v$i")"
  place "$t" "$fixture" "$dest"
  run "$t"
  reported="$(printf '%s\n' "$OUT" | grep -E '^G[0-9]+ ' || true)"
  hits="$(printf '%s\n' "$reported" | grep -cE "^$gid $dest:" || true)"
  others="$(printf '%s\n' "$reported" | grep -vE "^$gid " | grep -c . || true)"
  if [ "$RC" -eq 1 ] && [ "$hits" -eq "$count" ] && [ "$others" -eq 0 ]; then ok "$name"
  else not_ok "$name (rc=$RC, $gid hits=$hits want $count, other guards=$others)" "$OUT"; fi
done <<EOF
$CASES
EOF

# Controls: look-alikes the card says must not be caught, and the frozen Runner.
CLEAN="
AC-DF-011.2|clean/drawing-data-declaration.swift.fixture|$TK/FeatureSOAP/Sketch.swift
AC-DF-011.1|clean/app-facade-import.swift.fixture|trainer_app/App/Composition/Bootstrap.swift
AC-DF-011.1|clean/firebase-data-sdk-import.swift.fixture|$TK/FirebaseData/Store.swift
AC-DF-011.2|clean/legacy-soap-view-keys.swift.fixture|$TK/FeatureSOAP/LegacySoapView.swift
AC-DF-011.3|clean/print-outside-data-sync.swift.fixture|$TK/FeatureSOAP/Preview.swift
AC-DF-011.4|clean/member-app-safe.dart.fixture|lib/screens/ios_profile_screen.dart
AC-DF-011.2|clean/runner-frozen.swift.fixture|ios/Runner/AppDelegate.swift
"
while IFS='|' read -r ac fixture dest; do
  [ -n "$ac" ] || continue
  i=$((i + 1))
  name="$ac TC-DF011-01 control passes: $(basename "$fixture" .fixture) at $dest"
  t="$(new_tree "c$i")"
  place "$t" "$fixture" "$dest"
  run "$t"
  if [ "$RC" -eq 0 ]; then ok "$name"; else not_ok "$name (rc=$RC)" "$OUT"; fi
done <<EOF
$CLEAN
EOF

# Baselines are per guard + file: a baselined G2 file still fails on a new G9 use.
t="$(new_tree baseline-scope)"
place "$t" violations/G2-dart-get-download-url.dart.fixture lib/services/community_service.dart
printf 'G2 lib/services/community_service.dart # test baseline\n' > "$t/allow"
run "$t"
if [ "$RC" -eq 0 ]; then ok "AC-DF-011.4 TC-DF011-02 baselined file passes"; else not_ok "AC-DF-011.4 TC-DF011-02 baselined file passes" "$OUT"; fi
cat "$FIX/violations/G9-raw-collections.dart.fixture" >> "$t/lib/services/community_service.dart"
run "$t"
if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qE '^G9 lib/services/community_service.dart:'; then
  ok "AC-DF-011.4 TC-DF011-02 baseline for G2 does not cover G9 in the same file"
else not_ok "AC-DF-011.4 TC-DF011-02 baseline for G2 does not cover G9 in the same file" "$OUT"; fi

# Git trees: ignored build output is skipped, untracked new files are scanned.
if command -v git >/dev/null 2>&1; then
  t="$(new_tree git)"
  git -C "$t" init -q
  printf 'trainer_app/.spm/\n' > "$t/.gitignore"
  place "$t" violations/G1-core-import.swift.fixture "trainer_app/.spm/checkouts/Dep/$TC/TrainerDomain/X.swift"
  place "$t" violations/G7-tapback.swift.fixture trainer_app/.spm/checkouts/Dep/Avatar.swift
  run "$t"
  if [ "$RC" -eq 0 ]; then ok "AC-DF-011.2 TC-DF011-01 git-ignored SwiftPM checkout is not scanned"
  else not_ok "AC-DF-011.2 TC-DF011-01 git-ignored SwiftPM checkout is not scanned" "$OUT"; fi
  place "$t" violations/G7-tapback.swift.fixture "$TK/FeatureSOAP/Avatar.swift"
  run "$t"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qE "^G7 $TK/FeatureSOAP/Avatar.swift:"; then
    ok "AC-DF-011.2 TC-DF011-01 untracked new file in a git tree is scanned"
  else not_ok "AC-DF-011.2 TC-DF011-01 untracked new file in a git tree is scanned" "$OUT"; fi
fi

# A missing scope root is an error, not a silent pass.
t="$(new_tree missing-scope)"
rm -rf "$t/$TC/SyncEngine"
run "$t"
if [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q 'scope directory missing'; then ok "TC-DF011-01 missing scope directory exits 2"
else not_ok "TC-DF011-01 missing scope directory exits 2 (rc=$RC)" "$OUT"; fi

# ---------------------------------------------------------------------------------------------------------------
# TC-DF011-02: the committed baseline passes on this repository and any edit to it fails.
run "$REPO" "$ALLOW"
if [ "$RC" -eq 0 ]; then ok "AC-DF-011.4 TC-DF011-02 repository passes with the committed baseline"
else not_ok "AC-DF-011.4 TC-DF011-02 repository passes with the committed baseline" "$OUT"; fi

for entry in 'G9 lib/services/firestore_service.dart ' 'G2 lib/screens/create_request_screen.dart ' 'G2 lib/services/community_service.dart '; do
  if grep -qF -e "$entry#" "$ALLOW"; then ok "AC-DF-011.4 TC-DF011-02 card baseline entry present: $entry"
  else not_ok "AC-DF-011.4 TC-DF011-02 card baseline entry present: $entry"; fi
done

n="$(grep -c . "$ALLOW")"
k=0
while [ "$k" -lt "$n" ]; do
  k=$((k + 1))
  line="$(sed -n "${k}p" "$ALLOW")"
  sed "${k}d" "$ALLOW" > "$TMP/allow.minus"
  run "$REPO" "$TMP/allow.minus"
  key="${line%% \#*}"; gid="${key%% *}"; path="${key#* }"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qE "^$gid $path:"; then ok "AC-DF-011.5 TC-DF011-02 deleting baseline line $k ($key) fails"
  else not_ok "AC-DF-011.5 TC-DF011-02 deleting baseline line $k ($key) fails (rc=$RC)" "$OUT"; fi
done

expect_bad_allow() { # expect_bad_allow NAME EXTRA_LINE MESSAGE_REGEX
  { cat "$ALLOW"; printf '%s\n' "$2"; } > "$TMP/allow.plus"
  run "$REPO" "$TMP/allow.plus"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qE -e "$3"; then ok "AC-DF-011.5 TC-DF011-02 $1"
  else not_ok "AC-DF-011.5 TC-DF011-02 $1 (rc=$RC)" "$OUT"; fi
}
expect_bad_allow "line without a reason fails" 'G2 lib/services/community_service.dart' 'malformed line'
expect_bad_allow "line with an empty reason fails" 'G9 lib/services/new_service.dart # ' 'malformed line'
expect_bad_allow "line with an unknown guard ID fails" 'G0 lib/services/new_service.dart # reason' 'malformed line'
expect_bad_allow "comment line fails" '# baseline notes' 'malformed line'
expect_bad_allow "line with a line number fails" 'G9 lib/services/firestore_service.dart:19 # reason' 'drop the line number'
expect_bad_allow "trainer_app entry fails" "G4 $TK/FeatureSOAP/FeatureSOAP.swift # reason" 'zero-tolerance'
expect_bad_allow "stale entry fails" 'G9 lib/services/does_not_exist.dart # reason' 'stale baseline entry'
expect_bad_allow "duplicate entry fails" "$(sed -n 1p "$ALLOW")" 'duplicate entry'

echo
echo "static-guards.test: $passed passed, $failed failed"
[ "$failed" -eq 0 ]

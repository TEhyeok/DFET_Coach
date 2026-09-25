#!/usr/bin/env bash
# Self-test for tool/lint/check-workflow-secrets.sh (DF-034: TC-DF034-01, TC-DF034-03; AC-DF-034.1, AC-DF-034.3).
# Copies the real .github/workflows/trainer-app.yml into a temp directory, breaks one condition per copy with sed or
# awk, and checks that the checker fails with that condition's ID. Every mutation must change the copy, so a workflow
# edit that makes a mutation a no-op fails here instead of passing silently. No GoogleService-Info.plist is created.
#
# Usage: bash tool/lint/test/check-workflow-secrets.test.sh      Exit: 0 all pass, 1 any failure.
# Also run by tool/lint/test/static-guards.test.sh (CI job static-guards).
set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
CHECK="$REPO/tool/lint/check-workflow-secrets.sh"
WF="$REPO/.github/workflows/trainer-app.yml"
PLIST="trainer_app/Config/GoogleService-Info.plist"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-workflow-secrets-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0
OUT=""
RC=0
ok() { passed=$((passed + 1)); echo "ok     $1"; [ -z "${VERBOSE:-}" ] || printf '%s\n' "$OUT" | sed 's/^/       : /'; }
not_ok() { failed=$((failed + 1)); echo "not ok $1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/       | /'; }
run() { RC=0; OUT="$(bash "$CHECK" "$@" 2>&1)" || RC=$?; }

# ---------------------------------------------------------------------------------------------------------------
# TC-DF034-01 (AC-DF-034.1): the plist path is ignored and untracked; the root .gitignore alone also ignores it.
if out="$(git -C "$REPO" check-ignore "$PLIST" 2>&1)" && [ "$out" = "$PLIST" ]; then
  ok "AC-DF-034.1 TC-DF034-01 git check-ignore prints $PLIST"
else not_ok "AC-DF-034.1 TC-DF034-01 git check-ignore prints $PLIST" "$out"; fi
if git -C "$REPO" ls-files --error-unmatch "$PLIST" >/dev/null 2>&1; then
  not_ok "AC-DF-034.1 TC-DF034-01 $PLIST is not tracked"
else ok "AC-DF-034.1 TC-DF034-01 $PLIST is not tracked"; fi
g="$TMP/root-gitignore"
git init -q "$g" && cp "$REPO/.gitignore" "$g/.gitignore"
if out="$(git -C "$g" check-ignore "$PLIST" 2>&1)" && [ "$out" = "$PLIST" ]; then
  ok "AC-DF-034.1 TC-DF034-01 root .gitignore ignores $PLIST without trainer_app/.gitignore"
else not_ok "AC-DF-034.1 TC-DF034-01 root .gitignore ignores $PLIST without trainer_app/.gitignore" "$out"; fi

# ---------------------------------------------------------------------------------------------------------------
# TC-DF034-03 (AC-DF-034.3): the committed workflow passes.
run "$WF"
if [ "$RC" -eq 0 ]; then ok "AC-DF-034.3 TC-DF034-03 committed trainer-app.yml passes"
else not_ok "AC-DF-034.3 TC-DF034-03 committed trainer-app.yml passes (rc=$RC)" "$OUT"; fi

run "$TMP/does-not-exist.yml"
if [ "$RC" -eq 2 ]; then ok "AC-DF-034.3 TC-DF034-03 missing workflow exits 2"
else not_ok "AC-DF-034.3 TC-DF034-03 missing workflow exits 2 (rc=$RC)" "$OUT"; fi

run "$REPO/.github/workflows/ci.yml"
if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^C1 '; then ok "AC-DF-034.3 TC-DF034-03 a workflow without an injection step fails C1"
else not_ok "AC-DF-034.3 TC-DF034-03 a workflow without an injection step fails C1 (rc=$RC)" "$OUT"; fi

# expect ID NAME PROGRAM...: PROGRAM reads the workflow on stdin and writes the broken copy to stdout.
i=0
expect() {
  local id="$1" name="$2" copy
  shift 2
  i=$((i + 1))
  copy="$TMP/broken.$i.yml"
  "$@" < "$WF" > "$copy"
  if cmp -s "$WF" "$copy"; then not_ok "AC-DF-034.3 TC-DF034-03 $id $name (mutation did not change the workflow; update this test)"; return; fi
  run "$copy"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q "^$id "; then ok "AC-DF-034.3 TC-DF034-03 $id $name"
  else not_ok "AC-DF-034.3 TC-DF034-03 $id $name (rc=$RC, want 1 with $id)" "$OUT"; fi
}
# after_line REGEX TEXT: insert TEXT (\n separated) after the first line matching REGEX.
after_line() { awk -v re="$1" -v add="$2" '{ print } !done && $0 ~ re { print add; done = 1 }'; }
drop_line() { awk -v re="$1" '!done && $0 ~ re { done = 1; next } { print }'; }

DECODE_LINE="base64 --decode > $PLIST"
INJECT_IF="if: [$][{][{] env[.]TRAINER_PLIST_CONFIGURED"

# The four broken copies the card names, one per AC-DF-034.3 condition.
expect C1 "injection 'if' that also allows pull_request fails" \
  sed -e "s/|| github.event_name == 'workflow_dispatch') }}/|| github.event_name == 'workflow_dispatch' || github.event_name == 'pull_request') }}/"
expect C2 "a step that cats the plist fails" \
  after_line "$DECODE_LINE" "          cat $PLIST"
expect C3 "upload-artifact without the pull_request condition fails" \
  sed -e "s/if: [$]{{ failure() && github.event_name == 'pull_request' }}/if: failure()/"
expect C4 "cleanup step without if: always() fails" \
  awk '/- name: Remove Firebase config/ { f = 1 } f && /^        if: always[(][)]$/ { f = 0; next } { print }'

# C1 variants
expect C1 "injection 'if' without the main ref fails" \
  sed -e "s/github.event_name == 'push' && github.ref == 'refs\\/heads\\/main'/github.event_name == 'push'/"
expect C1 "injection 'if' without the non-empty secret test fails" \
  sed -e "s/env.TRAINER_PLIST_CONFIGURED == 'true' && //"
expect C1 "injection step without 'if' fails" drop_line "$INJECT_IF"
expect C1 "secret value in the job env (inherited by every xcodebuild step) fails" \
  sed -e "s/TRAINER_PLIST_CONFIGURED: [$]{{ secrets.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64 != '' }}/PLIST_B64: \${{ secrets.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64 }}/"
expect C1 "secret in another step's env fails" \
  after_line "- name: Release build without plist" "        env:\n          LEAK: \${{ secrets.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64 }}"
expect C1 "a second step that writes the plist fails" \
  after_line "rm -f $PLIST" "          printf '%s' \"\$X\" | base64 --decode > $PLIST"

# C2 variants
expect C2 "missing set +x fails" drop_line '^          set [+]x$'
expect C2 "set -x anywhere fails" sed -e 's/set -o pipefail/set -xo pipefail/'
expect C2 "plutil -p on the plist fails" after_line "$DECODE_LINE" "          plutil -p $PLIST"
expect C2 "base64 encoding the plist fails" after_line "$DECODE_LINE" "          base64 -i $PLIST"
expect C2 "head on the plist fails" after_line "$DECODE_LINE" "          head -c 80 $PLIST"
expect C2 "tail on the plist fails" after_line "test -n \"[$]bundled\"" "          tail -n 3 $PLIST"
# shellcheck disable=SC2016 # the literal $PLIST_B64 is the mutation
expect C2 "echo of the secret in the injection step fails" after_line "$DECODE_LINE" '          echo "$PLIST_B64"'
expect C2 "decoding through tee fails" sed -e "s#base64 --decode > $PLIST#base64 --decode | tee $PLIST#"
# shellcheck disable=SC2016 # the literal $PLIST_B64 is the mutation
expect C2 "another step reading PLIST_B64 fails" \
  after_line "test ! -e $PLIST" '          test -n "$PLIST_B64"'

# C3 variants
expect C3 "upload-artifact 'if' joined with || fails" \
  sed -e "s/failure() && github.event_name == 'pull_request'/failure() || github.event_name == 'pull_request'/"
expect C3 "upload path with trainer_app/Config fails" after_line '^            build/[*][.]log$' '            trainer_app/Config/**'
expect C3 "second upload-artifact step without 'if' fails" \
  after_line '^            build/[*][.]log$' "      - uses: actions/upload-artifact@v4\n        with:\n          name: extra\n          path: build/*.log"

# C4 variants
expect C4 "cleanup step without rm -f fails" drop_line "^          rm -f $PLIST$"
expect C4 "xcodebuild after the cleanup step fails" \
  after_line "-path '[*][.]app/GoogleService-Info[.]plist' -type f -delete" \
  "      - name: Late build\n        run: xcodebuild build -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer"

echo
echo "check-workflow-secrets.test: $passed passed, $failed failed"
[ "$failed" -eq 0 ]

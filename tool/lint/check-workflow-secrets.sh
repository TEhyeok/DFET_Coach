#!/usr/bin/env bash
# check-workflow-secrets.sh: static check that a workflow injects the trainer Firebase config without leaking it.
# Story DF-034 (docs/v1/backlog/P0.md#df-034), AC-DF-034.3, TC-DF034-03, NFR-02, ADR-019.
#
# Usage:  bash tool/lint/check-workflow-secrets.sh [WORKFLOW]   (default: .github/workflows/trainer-app.yml)
# Exit:   0 clean · 1 violation · 2 usage error or unreadable file
#
# Checks (one ID per AC-DF-034.3 condition). The file is read with bash, grep -E and awk only; no YAML parser.
#   C1 injection gate  Exactly one step decodes the secret into trainer_app/Config/GoogleService-Info.plist. Its `if`
#                      is, after removing `${{ }}` and whitespace, exactly
#                        env.TRAINER_PLIST_CONFIGURED=='true'&&((github.event_name=='push'&&github.ref=='refs/heads/main')||github.event_name=='workflow_dispatch')
#                      so pull_request never injects and an empty secret never writes a file. The secret
#                      secrets.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64 appears only as the job-level boolean
#                      `TRAINER_PLIST_CONFIGURED: ${{ secrets.… != '' }}` and in the injection step's own `env`, so no
#                      other step (xcodebuild dumps its environment into script-phase logs) ever holds the value.
#   C2 no printing     The injection step runs `set +x` before a `base64 --decode` (or -d/-D) that redirects into the
#                      plist, without tee. No line in the file enables xtrace. No step line that names the plist, the
#                      trainer_app/Config directory or PLIST_B64 uses cat, echo, head, tail, less, more, tee, xxd, od,
#                      hexdump, strings, grep, sed, awk, diff, cmp, plutil (other than -lint) or base64 (other than
#                      decode). PLIST_B64 is not read by any other step.
#   C3 artifacts       Every actions/upload-artifact step has an `if` that requires github.event_name=='pull_request'
#                      (joined with && only, no ||, no negation), and no upload path names trainer_app/Config or the
#                      plist.
#   C4 cleanup         A step with `if: always()` removes trainer_app/Config/GoogleService-Info.plist with rm -f and
#                      comes after the injection step and after the last xcodebuild step.
#
# Step boundaries: every `steps:` list is split at its `- ` items; each item's top-level key (name, if, run, uses,
# with, env, id, …) labels the lines under it. Full-line comments are ignored.
set -euo pipefail
export LC_ALL=C

WF="${1:-.github/workflows/trainer-app.yml}"
case "$WF" in -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;; esac
if [ $# -gt 1 ]; then echo "check-workflow-secrets: expected at most one workflow path" >&2; exit 2; fi
if [ ! -f "$WF" ] || [ ! -r "$WF" ]; then echo "check-workflow-secrets: workflow not found: $WF" >&2; exit 2; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-workflow-secrets.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PLIST='trainer_app/Config/GoogleService-Info.plist'
PLIST_RE='trainer_app/Config/GoogleService-Info\.plist'
SECRET_RE='secrets\.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64'
GATE="env.TRAINER_PLIST_CONFIGURED=='true'&&((github.event_name=='push'&&github.ref=='refs/heads/main')||github.event_name=='workflow_dispatch')"
DECODE_RE='base64[[:space:]]+(--decode|-d|-D)([[:space:]]|$)'
# Commands that write file content (or the secret) to the log. `plutil -lint` and decoding base64 are allowed.
PRINT_RE='(^|[^A-Za-z0-9_./-])(cat|echo|head|tail|less|more|tee|xxd|od|hexdump|strings|grep|egrep|fgrep|sed|awk|diff|cmp)([^A-Za-z0-9_.-]|$)'
PLUTIL_RE='(^|[^A-Za-z0-9_./-])plutil([[:space:]]+(-[a-z]+))?'
B64_RE='(^|[^A-Za-z0-9_./-])base64([^A-Za-z0-9_.-]|$)'

# steps.tsv: <step#> TAB <line#> TAB <key> TAB <text>   (lines inside a `steps:` list)
# outside.tsv: <line#> TAB <text>                        (every other non-comment line)
awk -v steps="$TMP/steps.tsv" -v outside="$TMP/outside.tsv" '
function indent(s) { match(s, /^ */); return RLENGTH }
BEGIN { in_steps = 0; n = 0; item = -1; key = "" }
{
  line = $0
  sub(/\r$/, "", line)
  if (line ~ /^[ ]*#/ || line ~ /^[ ]*$/) next
  ind = indent(line)
  if (in_steps && ind <= steps_ind) in_steps = 0
  if (in_steps) {
    if (line ~ /^ *- / && (item < 0 || ind == item)) {
      n++; item = ind; key = ""
      line = substr(line, 1, ind) " " substr(line, ind + 2)
    }
    if (n == 0) next
    rest = substr(line, item + 3)
    if (indent(line) == item + 2 && match(rest, /^[A-Za-z_][A-Za-z0-9_-]*:/)) key = substr(rest, 1, RLENGTH - 1)
    printf "%d\t%d\t%s\t%s\n", n, NR, key, line > steps
    next
  }
  if (line ~ /^ *steps: *$/) { in_steps = 1; steps_ind = ind; item = -1; next }
  printf "%d\t%s\n", NR, line > outside
}' "$WF"
touch "$TMP/steps.tsv" "$TMP/outside.tsv"

nsteps="$(awk -F'\t' 'END { print ($1 == "" ? 0 : $1) }' "$TMP/steps.tsv")"
errors=0
fail() { # fail ID LINE MESSAGE
  errors=$((errors + 1))
  printf '%s %s:%s: %s\n' "$1" "$WF" "$2" "$3"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then printf '::error file=%s,line=%s,title=check-workflow-secrets %s::%s\n' "$WF" "$2" "$1" "$3"; fi
}
# has / has_fixed PATTERN: grep that reads all of stdin. `grep -q` can exit early and, under pipefail, turn a match
# into a SIGPIPE failure of the writer.
has() { grep -E -e "$1" >/dev/null; }
has_fixed() { grep -F -e "$1" >/dev/null; }
# lines STEP [KEY]: "<line#>\t<text>" for a step, optionally only under one top-level key.
lines() { awk -F'\t' -v s="$1" -v k="${2:-}" '$1 == s && (k == "" || $3 == k) { print $2 "\t" $4 }' "$TMP/steps.tsv"; }
first_line() { awk -F'\t' -v s="$1" '$1 == s { print $2; exit }' "$TMP/steps.tsv"; }
# expr STEP: the step `if`, without the key, `${{ }}`, trailing comments and whitespace.
expr_of() {
  lines "$1" if | cut -f2- | sed -E 's/^[[:space:]]*if:[[:space:]]*([|>][-+]?)?//; s/[[:space:]]#.*$//' |
    tr -d '\n' | sed -E 's/\$\{\{//g; s/\}\}//g' | tr -d ' \t'
}

# ---------------------------------------------------------------------------------------------------------------
# C1 injection gate
inject=""
s=1
while [ "$s" -le "$nsteps" ]; do
  if lines "$s" run | cut -f2- | has "$DECODE_RE" && lines "$s" run | cut -f2- | has "$PLIST_RE"; then
    inject="$inject $s"
  fi
  s=$((s + 1))
done
inject="${inject# }"
if [ -z "$inject" ]; then
  fail C1 1 "no step decodes the secret into $PLIST (expected one injection step, AC-DF-034.3)"
elif [ "$inject" != "${inject%% *}" ]; then
  fail C1 "$(first_line "${inject##* }")" "more than one step writes $PLIST (steps $inject); keep a single gated injection step"
  inject="${inject%% *}"
fi

if [ -n "$inject" ]; then
  il="$(first_line "$inject")"
  gate="$(expr_of "$inject")"
  if [ -z "$gate" ]; then
    fail C1 "$il" "injection step has no 'if'; it must run only on main push or workflow_dispatch with a non-empty secret"
  elif [ "$gate" != "$GATE" ]; then
    fail C1 "$il" "injection 'if' is '$gate'; expected exactly: \${{ $GATE }} (pull_request must never inject)"
  fi
  if ! lines "$inject" env | cut -f2- | has "^[[:space:]]+PLIST_B64:[[:space:]]*\\\$\\{\\{[[:space:]]*${SECRET_RE}[[:space:]]*\\}\\}[[:space:]]*$"; then
    fail C1 "$il" "injection step must read the secret through its own step env: PLIST_B64: \${{ secrets.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64 }}"
  fi
fi
# The job-level flag the gate reads. It must be a comparison, never the secret itself.
if ! cut -f2- "$TMP/outside.tsv" | has "^[[:space:]]+TRAINER_PLIST_CONFIGURED:[[:space:]]*\\\$\\{\\{[[:space:]]*${SECRET_RE}[[:space:]]*!=[[:space:]]*''[[:space:]]*\\}\\}[[:space:]]*$"; then
  fail C1 1 "missing job env TRAINER_PLIST_CONFIGURED: \${{ secrets.TRAINER_GOOGLE_SERVICE_INFO_PLIST_B64 != '' }} (the gate reads env, step env is not visible to its own 'if')"
fi
while IFS="$(printf '\t')" read -r ln text; do
  [ -n "$ln" ] || continue
  if printf '%s\n' "$text" | has "^[[:space:]]+TRAINER_PLIST_CONFIGURED:[[:space:]]*\\\$\\{\\{[[:space:]]*${SECRET_RE}[[:space:]]*!=[[:space:]]*''[[:space:]]*\\}\\}[[:space:]]*$"; then continue; fi
  fail C1 "$ln" "the secret is exposed outside the injection step (every step of the job would inherit it): $(printf '%s' "$text" | sed -E 's/^[[:space:]]+//')"
done <<EOF
$(grep -E "$SECRET_RE" "$TMP/outside.tsv" || true)
EOF
while IFS="$(printf '\t')" read -r s ln key text; do
  [ -n "$s" ] || continue
  if [ "$s" = "$inject" ] && [ "$key" = env ]; then continue; fi
  fail C1 "$ln" "the secret is referenced by a step other than the injection step's env"
done <<EOF
$(grep -E "$SECRET_RE" "$TMP/steps.tsv" || true)
EOF

# ---------------------------------------------------------------------------------------------------------------
# C2 no printing
while IFS="$(printf '\t')" read -r ln text; do
  [ -n "$ln" ] || continue
  fail C2 "$ln" "xtrace would echo the injected value; never enable it in this workflow"
done <<EOF
$( { cut -f2,4 "$TMP/steps.tsv"; cat "$TMP/outside.tsv"; } |
   grep -E '(^|[;&|[:space:]])set[[:space:]]+(-[A-Za-z]*x|-o[[:space:]]+xtrace)|bash[[:space:]]+(-[A-Za-z]*x)|shell:[^#]*[[:space:]]-[A-Za-z]*x' || true)
EOF
if [ -n "$inject" ]; then
  run_lines="$(lines "$inject" run)"
  plusx="$(printf '%s\n' "$run_lines" | grep -E '(^|[;&|[:space:]])set[[:space:]]+\+x([[:space:]]|;|$)' | head -n1 | cut -f1 || true)"
  decode="$(printf '%s\n' "$run_lines" | grep -E "$DECODE_RE" | grep -E ">[[:space:]]*\"?$PLIST_RE" | head -n1 | cut -f1 || true)"
  if [ -z "$decode" ]; then
    fail C2 "$il" "the injection step must create the file with 'base64 --decode > $PLIST'"
  elif [ -z "$plusx" ] || [ "$plusx" -gt "$decode" ]; then
    fail C2 "$decode" "run 'set +x' before decoding the secret"
  fi
fi
while IFS="$(printf '\t')" read -r s ln key text; do
  [ -n "$s" ] || continue
  case "$key" in name|if|uses) continue ;; esac
  if [ "$key" = env ] && [ "$s" = "$inject" ]; then continue; fi
  bad=""
  if printf '%s\n' "$text" | has "$PRINT_RE"; then bad="$(printf '%s\n' "$text" | grep -Eo "$PRINT_RE" | head -n1 | tr -cd 'A-Za-z0-9' || true)"; fi
  pl="$(printf '%s\n' "$text" | grep -Eo "$PLUTIL_RE" | head -n1 || true)"
  if [ -n "$pl" ] && ! printf '%s\n' "$pl" | has '-lint$'; then bad="plutil"; fi
  if printf '%s\n' "$text" | has "$B64_RE" && ! printf '%s\n' "$text" | has "$DECODE_RE"; then bad="base64 (encode)"; fi
  if [ -n "$bad" ]; then fail C2 "$ln" "'$bad' on a line that touches the Firebase config or its secret can print it to the log"; fi
  if [ "$s" != "$inject" ] && printf '%s\n' "$text" | has 'PLIST_B64'; then
    fail C2 "$ln" "only the injection step may read PLIST_B64"
  fi
done <<EOF
$(grep -E 'GoogleService-Info|trainer_app/Config([/"[:space:]]|$)|PLIST_B64' "$TMP/steps.tsv" | grep -v "$(printf '\t')TRAINER_PLIST_CONFIGURED:" || true)
EOF
if [ -n "$inject" ] && lines "$inject" run | cut -f2- | has '(^|[^A-Za-z0-9_-])tee([^A-Za-z0-9_-]|$)|>&2|/dev/stderr|/dev/stdout'; then
  fail C2 "$il" "the injection step must not copy the decoded file to the log (tee, stdout, stderr)"
fi

# ---------------------------------------------------------------------------------------------------------------
# C3 artifacts
s=1
while [ "$s" -le "$nsteps" ]; do
  if lines "$s" uses | cut -f2- | has 'uses:[[:space:]]*"?actions/upload-artifact@'; then
    ul="$(first_line "$s")"
    e="$(expr_of "$s")"
    if ! printf '%s\n' "$e" | has_fixed "github.event_name=='pull_request'" ||
       printf '%s\n' "$e" | has '\|\||!|github\.event_name!='; then
      fail C3 "$ul" "upload-artifact 'if' is '${e:-<none>}'; it must require github.event_name == 'pull_request' (joined with &&) so runs that inject never upload"
    fi
    if lines "$s" with | cut -f2- | has 'trainer_app/Config|GoogleService-Info|^[[:space:]]*(path:[[:space:]]*)?(-[[:space:]]+)?(\.|\./|\*|\*\*|\./\*\*|trainer_app/?|\$\{\{[[:space:]]*github\.workspace[[:space:]]*\}\})[[:space:]]*$'; then
      fail C3 "$ul" "upload-artifact path must not include trainer_app/Config, the plist or the whole workspace"
    fi
  fi
  s=$((s + 1))
done

# ---------------------------------------------------------------------------------------------------------------
# C4 cleanup
cleanup=""
s=1
while [ "$s" -le "$nsteps" ]; do
  if [ "$(expr_of "$s")" = "always()" ] &&
     lines "$s" run | cut -f2- | has "(^|[;&|[:space:]])rm[[:space:]]+(-[A-Za-z]*f[A-Za-z]*[[:space:]]+)+\"?$PLIST_RE\"?([[:space:]]|;|$)"; then
    cleanup="$s"
  fi
  s=$((s + 1))
done
if [ -z "$cleanup" ]; then
  fail C4 1 "no 'if: always()' step runs 'rm -f $PLIST' (the file must be removed even when the build fails)"
elif [ -n "$inject" ]; then
  last_build="$(awk -F'\t' '$4 ~ /xcodebuild[[:space:]]/ && $3 == "run" { s = $1 } END { print s + 0 }' "$TMP/steps.tsv")"
  if [ "$cleanup" -le "$inject" ] || [ "$cleanup" -le "$last_build" ]; then
    fail C4 "$(first_line "$cleanup")" "the 'if: always()' cleanup must come after the injection step and after the last xcodebuild step"
  fi
fi

if [ "$errors" -gt 0 ]; then
  echo "check-workflow-secrets: FAIL: $errors violation(s) in $WF (AC-DF-034.3, NFR-02)"
  exit 1
fi
echo "check-workflow-secrets: OK: $WF (C1 gate, C2 no printing, C3 PR-only artifacts, C4 always() cleanup; $nsteps steps)"

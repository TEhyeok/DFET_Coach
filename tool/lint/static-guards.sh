#!/usr/bin/env bash
# static-guards.sh: string-level invariants that the compile boundary (DF-008) cannot enforce.
# Story DF-011 (docs/v1/backlog/P0.md#df-011), test plan V1-10 §16.2, baseline rule ASM-01-15 / ASM-P0-25.
#
# Usage:  bash tool/lint/static-guards.sh [--root DIR] [--allow FILE]
#   --root   tree to scan (default: this repository)
#   --allow  baseline file (default: <root>/tool/lint/static-guards.allow)
# Exit:   0 clean · 1 violation, stale or malformed baseline · 2 usage error, missing scope or grep failure
#
# Guards (card DF-011 '구현 노트'). Patterns are POSIX ERE and run the same with GNU grep (CI) and BSD grep (macOS).
#   G1 Firebase import       `import Firebase*` in TrainerCore/Sources, TrainerKit/Sources except FirebaseData,
#                            and trainer_app/App (App may import only the FirebaseData facade, V1-04 ASM-04-03)   AC-DF-011.1
#   G2 download URL          `getDownloadURL` / `downloadURL(` in trainer_app/, lib/, admin_web/                AC-DF-011.2, .4
#   G3 member-UUID           "member-" + UUID or "member-\(UUID…)" in trainer_app/                               AC-DF-011.2
#   G4 native_ ID            "native_ in trainer_app/                                                            AC-DF-011.2
#   G5 inline ink            "nativeInkDataBase64" | "inkDataBase64" | "drawingData" (quoted keys) in trainer_app/,
#                            except the read-only key names in LegacySoapView.swift                              AC-DF-011.2
#   G6 isShared true         isSharedWithMember[^A-Za-z]*true in trainer_app/                                    AC-DF-011.2
#   G7 tapback               tapback.co in trainer_app/                                                          AC-DF-011.2
#   G8 print                 print( / debugPrint( in Sources/FirebaseData and Sources/SyncEngine                 AC-DF-011.3
#   G9 raw record collection 'soap_notes' 'postureAssessments' 'bodyCompositionRecords'
#                            'circumferenceMeasurements' 'bodyScans' as a string or path segment in lib/         AC-DF-011.4
#
# Baseline (tool/lint/static-guards.allow). Every line is `<GuardID> <path> # <reason>`, per guard + file, no line
# numbers (V1-10 §16.2). Findings must equal the baseline exactly: an unlisted finding fails, and an entry that no
# longer matches a finding fails too (delete the line in the PR that removes the code). trainer_app/ is zero-tolerance
# (AC-DF-011.1-.3), so an entry under trainer_app/ is rejected.
#
# Not scanned: ios/Runner/** (frozen; card excludes it from G3-G7, removed by MIG-09 / DF-387), *.md prose, git-ignored
# files (build output, SwiftPM checkouts, GoogleService-Info.plist). Only runner-default tools are used (bash, git,
# grep -E, find, sort, comm, sed). ripgrep is deliberately not used so that one regex dialect applies everywhere.
set -euo pipefail
export LC_ALL=C

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ALLOW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || usage; ROOT="$(cd "$2" && pwd)"; shift 2 ;;
    --allow) [ $# -ge 2 ] || usage; ALLOW="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "static-guards: unknown argument: $1" >&2; usage ;;
  esac
done
[ -n "$ALLOW" ] || ALLOW="$ROOT/tool/lint/static-guards.allow"
if [ ! -f "$ALLOW" ]; then echo "static-guards: baseline file not found: $ALLOW" >&2; exit 2; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/static-guards.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/findings"

TC="trainer_app/Packages/TrainerCore/Sources"
TK="trainer_app/Packages/TrainerKit/Sources"
# A renamed or moved scope would make a guard pass silently, so every scope root must exist.
for d in "$TC" "$TC/SyncEngine" "$TK" "$TK/FirebaseData" trainer_app/App lib; do
  if [ ! -d "$ROOT/$d" ]; then
    echo "static-guards: scope directory missing: $d (update the scopes in tool/lint/static-guards.sh)" >&2
    exit 2
  fi
done

USE_GIT=0
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then USE_GIT=1; fi

guard_name() {
  case "$1" in
    G1) echo "Firebase import outside FirebaseData" ;;
    G2) echo "download URL (PRD §9.5 link policy)" ;;
    G3) echo "member-UUID local member ID" ;;
    G4) echo "native_ document ID" ;;
    G5) echo "inline handwriting key" ;;
    G6) echo "isSharedWithMember true" ;;
    G7) echo "tapback.co avatar" ;;
    G8) echo "print in FirebaseData/SyncEngine" ;;
    G9) echo "member app raw record collection" ;;
  esac
}

# Files under the given scope paths, relative to ROOT: tracked plus untracked-not-ignored in a git tree, otherwise
# find(1) with the usual build and secret paths pruned.
list_files() {
  local p
  for p in "$@"; do
    [ -e "$ROOT/$p" ] || continue
    if [ "$USE_GIT" = 1 ]; then
      git -C "$ROOT" ls-files -co --exclude-standard -z -- "$p" | tr '\0' '\n'
    else
      (cd "$ROOT" && find "$p" \( -name .git -o -name DerivedData -o -name .spm -o -name .build -o -name build \
        -o -name .swiftpm -o -name node_modules -o -name .dart_tool \) -prune -o -type f -print)
    fi
  done | while IFS= read -r f; do
    if [ -f "$ROOT/$f" ]; then printf '%s\n' "$f"; fi
  done | grep -vE '(^|/)(GoogleService-Info\.plist|\.env[^/]*|[^/]*\.secret\.local)$|\.md$' | sort -u || true
}

# scan ID INCLUDE_PATH_RE EXCLUDE_PATH_RE LINE_RE EXCLUDE_LINE_RE SCOPE...
# Appends "ID path:line:text" to the findings file. Empty INCLUDE/EXCLUDE regexes mean "no filter".
scan() {
  local id="$1" inc="$2" exc="$3" re="$4" notre="$5" f out rc ln text
  shift 5
  list_files "$@" > "$TMP/files"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -n "$inc" ] && ! printf '%s\n' "$f" | grep -qE -e "$inc"; then continue; fi
    if [ -n "$exc" ] && printf '%s\n' "$f" | grep -qE -e "$exc"; then continue; fi
    rc=0
    out="$(grep -nIE -e "$re" -- "$ROOT/$f")" || rc=$?
    if [ "$rc" -gt 1 ]; then echo "static-guards: grep failed on $f (exit $rc)" >&2; exit 2; fi
    [ "$rc" -eq 0 ] || continue
    while IFS= read -r line; do
      ln="${line%%:*}"
      text="${line#*:}"
      if [ -n "$notre" ] && printf '%s\n' "$text" | grep -qE -e "$notre"; then continue; fi
      text="$(printf '%s' "$text" | sed -e 's/^[[:space:]]*//' | cut -c1-160)"
      printf '%s %s:%s:%s\n' "$id" "$f" "$ln" "$text" >> "$TMP/findings"
    done <<EOF
$out
EOF
  done < "$TMP/files"
}

SWIFT='\.swift$'
IMPORT_FIREBASE='^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?Firebase'

# G1 (AC-DF-011.1, NFR-03)
scan G1 "$SWIFT" "^$TK/FirebaseData/" "$IMPORT_FIREBASE" '' "$TC" "$TK"
scan G1 "$SWIFT" '' "$IMPORT_FIREBASE" 'import[[:space:]]+FirebaseData([^A-Za-z0-9_]|$)' trainer_app/App
# G2 (AC-DF-011.2, .4; PRD §9.5). Swift `downloadURL { … }` trailing closures count too.
scan G2 '' '' 'getDownloadURL|(^|[^A-Za-z0-9_])downloadURL[[:space:]]*[({]' '' trainer_app lib admin_web
# G3-G7 (AC-DF-011.2). ios/Runner is never passed as a scope.
scan G3 '' '' '"member-("[[:space:]]*\+|\\\()[^"]*(UUID|uuid)' '' trainer_app
scan G4 '' '' '"native_' '' trainer_app
scan G5 '' '(^|/)LegacySoapView\.swift$' '"(nativeInkDataBase64|inkDataBase64|drawingData)"' '' trainer_app
scan G6 '' '' 'isSharedWithMember[^A-Za-z]*true' '' trainer_app
scan G7 '' '' 'tapback\.co' '' trainer_app
# G8 (AC-DF-011.3, NFR-06). Logging goes through os.Logger with privacy: .private.
scan G8 "$SWIFT" '' '(^|[^A-Za-z0-9_])(print|debugPrint)[[:space:]]*\(' '' "$TK/FirebaseData" "$TC/SyncEngine"
# G9 (AC-DF-011.4, AC-VIZ-06.1)
scan G9 '' '' "['\"/](soap_notes|postureAssessments|bodyCompositionRecords|circumferenceMeasurements|bodyScans)['\"/]" '' lib

# Baseline parsing (AC-DF-011.5)
errors=0
: > "$TMP/allow_keys"
n=0
while IFS= read -r l || [ -n "$l" ]; do
  n=$((n + 1))
  if ! printf '%s\n' "$l" | grep -qE '^G[1-9] [^[:space:]#]+ # [^[:space:]].*$'; then
    echo "static-guards.allow:$n: malformed line (expected '<GuardID> <path> # <reason>'): $l"
    errors=$((errors + 1)); continue
  fi
  id="${l%% *}"; rest="${l#* }"; path="${rest%% *}"
  case "$path" in
    trainer_app/*)
      echo "static-guards.allow:$n: trainer_app/ is zero-tolerance and cannot be baselined (AC-DF-011.1-.3): $path"
      errors=$((errors + 1)); continue ;;
  esac
  if printf '%s\n' "$path" | grep -qE ':[0-9]+$'; then
    echo "static-guards.allow:$n: baseline entries are per file, drop the line number: $path"
    errors=$((errors + 1)); continue
  fi
  printf '%s %s\n' "$id" "$path" >> "$TMP/allow_keys"
done < "$ALLOW"

dups="$(sort "$TMP/allow_keys" | uniq -d)"
if [ -n "$dups" ]; then
  printf '%s\n' "$dups" | sed 's/^/static-guards.allow: duplicate entry: /'
  errors=$((errors + $(printf '%s\n' "$dups" | wc -l)))
fi
sort -u "$TMP/allow_keys" > "$TMP/allowed"
sed -E 's/^(G[0-9]+) ([^:]*):.*$/\1 \2/' "$TMP/findings" | sort -u > "$TMP/found"
comm -23 "$TMP/found" "$TMP/allowed" > "$TMP/unallowed"
comm -13 "$TMP/found" "$TMP/allowed" > "$TMP/stale"

violations=0
while IFS= read -r line; do
  key="$(printf '%s\n' "$line" | sed -E 's/^(G[0-9]+) ([^:]*):.*$/\1 \2/')"
  grep -qxF -e "$key" "$TMP/unallowed" || continue
  violations=$((violations + 1))
  id="${line%% *}"; loc="${line#* }"
  printf '%s %s  [%s]\n' "$id" "$loc" "$(guard_name "$id")"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    file="${loc%%:*}"; rest="${loc#*:}"; lno="${rest%%:*}"
    printf '::error file=%s,line=%s,title=static-guards %s::%s\n' "$file" "$lno" "$id" "$(guard_name "$id")"
  fi
done < "$TMP/findings"

stale=0
while IFS= read -r key; do
  [ -n "$key" ] || continue
  stale=$((stale + 1))
  echo "static-guards.allow: stale baseline entry, no finding left for '$key' (remove the line)"
done < "$TMP/stale"

baselined=$(( $(wc -l < "$TMP/findings") - violations ))
if [ "$violations" -gt 0 ] || [ "$stale" -gt 0 ] || [ "$errors" -gt 0 ]; then
  echo "static-guards: FAIL: $violations violation(s), $stale stale baseline entr(y/ies), $errors malformed baseline line(s)"
  [ "$violations" -eq 0 ] || echo "static-guards: fix the code; baseline entries are only for pre-existing uses with a removal story or owner decision (ASM-P0-25)"
  exit 1
fi
echo "static-guards: OK: 9 guards, 0 violations, $baselined baselined finding(s) in $(wc -l < "$TMP/allowed" | tr -d ' ') file(s)"

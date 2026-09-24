#!/usr/bin/env bash
# 백로그 도구 시나리오 테스트(가짜 gh). 네트워크에 접근하지 않는다.
# 1) dry-run은 gh를 한 번도 부르지 않는다(AC-DF-002.1)
# 2) --apply 두 번: 두 번째 실행의 생성 0건, --search 0건(AC-DF-002.2)
# 3) 링크 블록이 #번호로 다시 쓰인다(에픽 하위 항목, 의존)
# 4) 검증기 통과(--prd로 PRD 경로를 줄 수 있다: PRD=... bash run.sh)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool="$(cd "$here/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/dfet-backlog-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cp "$here/fake-gh.sh" "$work/bin/gh"; chmod +x "$work/bin/gh"
export FAKE_GH_LOG="$work/gh.log" FAKE_GH_STATE="$work/state"
: > "$FAKE_GH_LOG"
fail() { echo "FAIL: $*" >&2; exit 1; }

# 1) dry-run
PATH="$work/bin:$PATH" bash "$tool/create_github_issues.sh" > "$work/dry.txt"
[ ! -s "$FAKE_GH_LOG" ] || fail "dry-run called gh: $(head -1 "$FAKE_GH_LOG")"
grep -q 'plan: 230 issues' "$work/dry.txt" || fail "dry-run plan count"
bash "$tool/create_backlog.sh" --dry-run --offline > /dev/null || fail "wrapper dry-run"
echo "ok 1 dry-run makes no gh calls"

# 2) apply twice (선택: P0 + 소유자 행동, 제안 제외)
args=(--apply --delay 0 --phase P0 --owner-actions --exclude-proposals)
PATH="$work/bin:$PATH" PROJECT_NUMBER=7 bash "$tool/create_github_issues.sh" "${args[@]}" > "$work/apply1.txt"
c1=$(grep -c '^   created #' "$work/apply1.txt" || true)
[ "$c1" -eq 101 ] || fail "first apply created $c1 (expected 101 = 24 epics + 77 items)"
PATH="$work/bin:$PATH" PROJECT_NUMBER=7 bash "$tool/create_github_issues.sh" "${args[@]}" > "$work/apply2.txt"
c2=$(grep -c '^   created #' "$work/apply2.txt" || true)
[ "$c2" -eq 0 ] || fail "second apply created $c2"
! grep -q -- '--search' "$FAKE_GH_LOG" || fail "search API used"
dups=$(cut -f2 "$FAKE_GH_STATE/issues.tsv" | sort | uniq -d | wc -l | tr -d ' ')
[ "$dups" -eq 0 ] || fail "duplicate titles"
ms=$(wc -l < "$FAKE_GH_STATE/ms.tsv" | tr -d ' ')
[ "$ms" -eq 9 ] || fail "milestones $ms (expected 9)"
echo "ok 2 idempotent apply (created $c1 then 0, milestones $ms)"

# 3) links
ep=$(awk -F'\t' '$2 ~ /^\[EP-01\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
grep -q '^- \[ \] #[0-9]' "$FAKE_GH_STATE/bodies/$ep.md" || fail "epic children not linked"
n4=$(awk -F'\t' '$2 ~ /^\[DF-004\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
grep -q '^- #[0-9]* DF-003$' "$FAKE_GH_STATE/bodies/$n4.md" || fail "dependency not linked"
# 다음 단계(P1a) 추가 후 기존 에픽 EP-04의 하위 목록이 갱신되는가
PATH="$work/bin:$PATH" bash "$tool/create_github_issues.sh" --apply --delay 0 --only issues --phase P1a --exclude-proposals > "$work/apply3.txt"
e4=$(awk -F'\t' '$2 ~ /^\[EP-04\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
n101=$(awk -F'\t' '$2 ~ /^\[DF-101\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
grep -q "^- \[ \] #$n101\$" "$FAKE_GH_STATE/bodies/$e4.md" || fail "epic not relinked after later phase"
echo "ok 3 link blocks rewritten with issue numbers"

# 4) validator + build drift
if [ -n "${PRD:-}" ]; then node "$tool/validate_backlog.mjs" --prd "$PRD" > /dev/null || fail "validator"; echo "ok 4 validator"; fi
node "$tool/build_issues.mjs" --check > /dev/null || fail "issues.json stale"
echo "ok 5 issues.json up to date"
echo "PASS"

#!/usr/bin/env bash
# 백로그 도구 시나리오 테스트(가짜 gh). 네트워크에 접근하지 않는다. CI docs-and-backlog job이 부른다.
# 0) node:test(tool/backlog/test/*.test.mjs)와 shellcheck(로컬에서는 없으면 건너뛰고, CI=true면 없을 때 실패한다. AC-DF-002.5)
# 1) 인자 없는 dry-run은 gh를 한 번도 부르지 않고 계획(라벨·마일스톤·이슈 수)을 출력한다(AC-DF-002.1)
# 2) 기존 이슈 [DF-001]이 있는 상태에서 --apply 두 번: DF-001 생성 0건, 없는 키는 첫 실행에서 한 번만,
#    두 번째 실행 생성 0건, --search 0건(AC-DF-002.2)
# 3) 링크 블록이 #번호로 다시 쓰인다(에픽 하위 항목, 의존, 다음 단계 추가 뒤 기존 에픽)
# 4) 검증기 통과(PRD 경로: 환경 변수 PRD, 기본 docs/PRD_V1.md. CI=true면 PRD가 없을 때 실패), 5) issues.json 드리프트 없음
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool="$(cd "$here/.." && pwd)"
root="$(cd "$tool/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/dfet-backlog-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cp "$here/fake-gh.sh" "$work/bin/gh"; chmod +x "$work/bin/gh"
export FAKE_GH_LOG="$work/gh.log" FAKE_GH_STATE="$work/state"
: > "$FAKE_GH_LOG"
fail() { echo "FAIL: $*" >&2; exit 1; }
REPO="TEhyeok/DFET_Coach"
# GitHub에 무언가를 바꾸는 gh 호출(가짜 gh 기록의 한 줄 = 호출 인자)
MUTATING='^(label (create|edit|delete)|api -X (POST|PATCH|PUT|DELETE)|issue (create|edit|close|comment)|project (create|item-add|item-edit|field-create))'

# 0) node:test + shellcheck
node --test "$here"/*.test.mjs > "$work/node-test.txt" 2>&1 || { cat "$work/node-test.txt" >&2; fail "node --test tool/backlog/test"; }
echo "ok 0a node --test ($(grep -E '^# pass' "$work/node-test.txt" | tr -d '#' | xargs))"
if command -v shellcheck > /dev/null 2>&1; then
  shellcheck "$tool"/*.sh "$here"/*.sh || fail "shellcheck"
  echo "ok 0b shellcheck tool/backlog/*.sh tool/backlog/test/*.sh"
elif [ -n "${CI:-}" ]; then
  fail "shellcheck not installed (required in CI, AC-DF-002.5)"
else
  echo "skip 0b shellcheck not installed (local run only; CI fails here)"
fi

# 1) dry-run(기본값, 인자 없음). 가짜 gh를 PATH 맨 앞에 두고 호출 기록이 비어 있는지 본다
PATH="$work/bin:$PATH" bash "$tool/create_backlog.sh" > "$work/dry.txt"
PATH="$work/bin:$PATH" bash "$tool/create_backlog.sh" --dry-run --offline > "$work/dry-offline.txt"
mut=$(grep -cE "$MUTATING" "$FAKE_GH_LOG" || true)
[ "$mut" -eq 0 ] || fail "dry-run made $mut mutating gh calls"
[ ! -s "$FAKE_GH_LOG" ] || fail "dry-run called gh: $(head -1 "$FAKE_GH_LOG")"
grep -q '^== plan: labels 67, milestones 9, issues 230 ' "$work/dry.txt" || fail "dry-run plan summary"
cmp -s "$work/dry.txt" "$work/dry-offline.txt" || fail "--dry-run --offline differs from the default dry-run"
echo "ok 1 dry-run makes no gh calls and prints the plan (labels 67, milestones 9, issues 230)"

# 2) apply twice. 기존 이슈 #1 [DF-001]을 심어 둔다(가짜 gh issue list가 이를 돌려준다)
mkdir -p "$FAKE_GH_STATE"
printf '1\t[DF-001] 기존 이슈(시드)\n' > "$FAKE_GH_STATE/issues.tsv"
args=(--apply --repo "$REPO" --delay 0 --phase P0 --owner-actions --exclude-proposals)
PATH="$work/bin:$PATH" PROJECT_NUMBER=7 bash "$tool/create_backlog.sh" "${args[@]}" > "$work/apply1.txt"
c1=$(grep -c '^   created #' "$work/apply1.txt" || true)
[ "$c1" -eq 100 ] || fail "first apply created $c1 (expected 100 = 24 epics + 77 items - existing DF-001)"
grep -q '^   skip (exists #1): \[DF-001\] ' "$work/apply1.txt" || fail "existing DF-001 not skipped"
PATH="$work/bin:$PATH" PROJECT_NUMBER=7 bash "$tool/create_backlog.sh" "${args[@]}" > "$work/apply2.txt"
c2=$(grep -c '^   created #' "$work/apply2.txt" || true)
[ "$c2" -eq 0 ] || fail "second apply created $c2"
grep -q '^   result: created 0, skipped(existing) 101$' "$work/apply2.txt" || fail "second apply summary"
lists=$(grep -c "^issue list --repo $REPO --state all --limit 3000 --json number,title" "$FAKE_GH_LOG" || true)
[ "$lists" -eq 2 ] || fail "expected one full issue list per run, got $lists"
grep -oE '^issue create .*--title \[(DF-[0-9]{3}|EP-[0-9]{2})\]' "$FAKE_GH_LOG" | sed -E 's/.*--title \[//; s/\]$//' | sort > "$work/created-keys.txt"
! grep -qx 'DF-001' "$work/created-keys.txt" || fail "issue create called for existing DF-001"
[ -z "$(uniq -d "$work/created-keys.txt")" ] || fail "issue create called twice for: $(uniq -d "$work/created-keys.txt" | tr '\n' ' ')"
[ "$(wc -l < "$work/created-keys.txt" | tr -d ' ')" -eq 100 ] || fail "issue create calls != 100"
! grep -q -- '--search' "$FAKE_GH_LOG" || fail "search API used"
dups=$(cut -f2 "$FAKE_GH_STATE/issues.tsv" | sort | uniq -d | wc -l | tr -d ' ')
[ "$dups" -eq 0 ] || fail "duplicate titles"
ms=$(wc -l < "$FAKE_GH_STATE/ms.tsv" | tr -d ' ')
[ "$ms" -eq 9 ] || fail "milestones $ms (expected 9)"
echo "ok 2 idempotent apply (DF-001 existed: created 0; others $c1 then 0; --search 0; milestones $ms)"

# 3) links
ep=$(awk -F'\t' '$2 ~ /^\[EP-01\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
grep -q '^- \[ \] #1$' "$FAKE_GH_STATE/bodies/$ep.md" || fail "epic EP-01 does not link existing DF-001 (#1)"
grep -q '^- \[ \] #[0-9]' "$FAKE_GH_STATE/bodies/$ep.md" || fail "epic children not linked"
n4=$(awk -F'\t' '$2 ~ /^\[DF-004\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
grep -q '^- #[0-9]* DF-003$' "$FAKE_GH_STATE/bodies/$n4.md" || fail "dependency not linked"
# 다음 단계(P1a) 추가 후 기존 에픽 EP-04의 하위 목록이 갱신되는가
PATH="$work/bin:$PATH" bash "$tool/create_backlog.sh" --apply --repo "$REPO" --delay 0 --only issues --phase P1a --exclude-proposals > "$work/apply3.txt"
e4=$(awk -F'\t' '$2 ~ /^\[EP-04\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
n101=$(awk -F'\t' '$2 ~ /^\[DF-101\]/ {print $1}' "$FAKE_GH_STATE/issues.tsv")
grep -q "^- \[ \] #$n101\$" "$FAKE_GH_STATE/bodies/$e4.md" || fail "epic not relinked after later phase"
echo "ok 3 link blocks rewritten with issue numbers"

# 4) validator + 5) build drift
prd="${PRD:-$root/docs/PRD_V1.md}"
if [ -f "$prd" ]; then
  node "$tool/validate_backlog.mjs" --prd "$prd" > /dev/null || fail "validator"
  echo "ok 4 validator"
elif [ -n "${CI:-}" ]; then
  fail "PRD not found: $prd (required in CI)"
else
  echo "skip 4 validator (PRD not found: $prd; local run only, CI fails here)"
fi
node "$tool/build_issues.mjs" --check > /dev/null || fail "issues.json stale"
echo "ok 5 issues.json up to date"
echo "PASS"

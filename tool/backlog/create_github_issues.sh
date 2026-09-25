#!/usr/bin/env bash
# TL-11 create_github_issues.sh — D-FET Coach v1 백로그를 GitHub에 만든다(소유자 전용).
#
# 기본은 DRY-RUN이다. dry-run은 gh를 한 번도 호출하지 않고 네트워크에 접근하지 않는다.
# 실제 생성은 --apply를 줄 때만 한다. AI 에이전트는 --apply를 실행하지 않는다.
#
# 사용 예
#   bash tool/backlog/create_github_issues.sh                           # 전체 계획 출력(dry-run)
#   bash tool/backlog/create_github_issues.sh --apply --only labels,milestones
#   bash tool/backlog/create_github_issues.sh --apply --only project --create-project
#   PROJECT_NUMBER=3 bash tool/backlog/create_github_issues.sh --apply --only project
#   PROJECT_NUMBER=3 bash tool/backlog/create_github_issues.sh --apply --only issues --phase P0 --owner-actions
#   bash tool/backlog/create_github_issues.sh --apply --only relink       # 링크 블록만 다시 쓰기
#
# 단계(--only 생략 시 이 순서로 전부): labels → milestones → project → issues → relink
#   labels     : gh label create --force(있으면 색·설명 갱신, 멱등)
#   milestones : 제목으로 기존 마일스톤 조회, 없으면 POST, 목표일·설명이 다르면 PATCH(멱등)
#   project    : PROJECT_NUMBER가 있으면 필드 Points(NUMBER)·Sprint(TEXT)·Phase(SINGLE_SELECT)를 없을 때만 만든다.
#                --create-project면 보드 'D-FET Coach v1'을 만들고 번호를 출력한다.
#   issues     : 제목의 [KEY]로 기존 이슈를 찾아(검색 API 대신 전체 목록 1회 조회) 없는 것만 만든다.
#                PROJECT_NUMBER가 있으면 보드에 추가하고 Points·Sprint·Phase 필드를 채운다.
#                에픽을 먼저 만들고, 끝에 이번에 만든 이슈와 그 에픽의 링크 블록을 #번호로 다시 쓴다.
#   relink     : 선택된 기존 이슈 전부의 링크 블록(<!-- df-links:start -->~end)을 #번호로 다시 쓴다.
#                블록 밖 본문(소유자가 고친 내용)은 건드리지 않는다.
#
# 선택(합집합. 아무것도 주지 않으면 전체)
#   --phase P0,P1a      해당 단계 항목      --owner-actions   모든 소유자 행동(DF-9NN)
#   --sprint S01,S02    해당 스프린트 항목  --keys DF-001,DF-116
#   --exclude-proposals 추가 제안(채택 대기) 제외      --no-epics  에픽 이슈 제외
#
# 기타
#   --repo owner/name   기본 TEhyeok/DFET_Coach
#   --files <json>      기본 tool/backlog/issues.json
#   --project-owner <login>  기본은 repo의 owner.  PROJECT_NUMBER 환경 변수 또는 --project-number <n>
#   --skip-tracking-milestones  게이트 추적용 마일스톤(trackingOnly)을 만들지 않는다
#   --delay <초>        이슈 생성 사이 대기(기본 1, 보조 속도 제한 회피)
#   --offline           dry-run 전용 별칭(호환용). dry-run은 원래 오프라인이다
#
# 필요: bash 3.2+, jq. --apply일 때 gh(인증: repo 범위, 보드를 쓰면 project·read:project 범위)
#   gh auth refresh -s project,read:project
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="TEhyeok/DFET_Coach"
FILES="$here/issues.json"
LABELS_FILE="$here/labels.json"
MILESTONES_FILE="$here/milestones.json"
APPLY=0
OFFLINE=0
ONLY="labels,milestones,project,issues,relink"
PHASES=""; SPRINTS=""; KEYS=""; OWNER_ACTIONS=0; EXCLUDE_PROPOSALS=0; NO_EPICS=0
PROJECT_OWNER=""; PROJECT_NUMBER="${PROJECT_NUMBER:-}"; CREATE_PROJECT=0
SKIP_TRACKING=0; DELAY=1
PROJECT_TITLE="D-FET Coach v1"

die() { echo "error: $*" >&2; exit 1; }
usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) APPLY=0 ;;
    --apply) APPLY=1 ;;
    --offline) OFFLINE=1 ;;
    --repo) REPO="$2"; shift ;;
    --files) FILES="$2"; shift ;;
    --only) ONLY="$2"; shift ;;
    --phase) PHASES="$2"; shift ;;
    --sprint) SPRINTS="$2"; shift ;;
    --keys) KEYS="$2"; shift ;;
    --owner-actions) OWNER_ACTIONS=1 ;;
    --exclude-proposals) EXCLUDE_PROPOSALS=1 ;;
    --no-epics) NO_EPICS=1 ;;
    --project-owner) PROJECT_OWNER="$2"; shift ;;
    --project-number) PROJECT_NUMBER="$2"; shift ;;
    --create-project) CREATE_PROJECT=1 ;;
    --skip-tracking-milestones) SKIP_TRACKING=1 ;;
    --delay) DELAY="$2"; shift ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || die "jq is required"
[ -f "$FILES" ] || die "issues file not found: $FILES"
[ -f "$LABELS_FILE" ] || die "labels file not found: $LABELS_FILE"
[ -f "$MILESTONES_FILE" ] || die "milestones file not found: $MILESTONES_FILE"
[ "$OFFLINE" -eq 1 ] && [ "$APPLY" -eq 1 ] && die "--offline cannot be combined with --apply"
[ -z "$PROJECT_OWNER" ] && PROJECT_OWNER="${REPO%%/*}"
case "$DELAY" in ''|*[!0-9.]*) die "--delay must be a number" ;; esac
for s in $(echo "$ONLY" | tr ',' ' '); do
  case "$s" in labels|milestones|project|issues|relink) ;; *) die "unknown --only step: $s" ;; esac
done
step_on() { case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/dfet-backlog.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
MAP="$TMP/map.tsv"          # KEY<TAB>issue number
CREATED="$TMP/created.txt"  # keys created in this run
: > "$MAP"; : > "$CREATED"

mode="DRY-RUN(네트워크 호출 없음)"; [ "$APPLY" -eq 1 ] && mode="APPLY"
PLAN_LABELS="-"; PLAN_MILESTONES="-"; PLAN_ISSUES="-"   # dry-run 끝 요약(AC-DF-002.1). 건너뛴 단계는 '-'

echo "== create_github_issues.sh  mode=$mode  repo=$REPO  steps=$ONLY"

# gh 래퍼: dry-run에서는 절대 실행하지 않는다.
gh_run() {
  if [ "$APPLY" -ne 1 ]; then echo "  [dry-run] gh $*"; return 0; fi
  gh "$@"
}

if [ "$APPLY" -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || die "gh CLI is required for --apply"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated (gh auth login)"
  if step_on project || { step_on issues && [ -n "$PROJECT_NUMBER" ]; }; then
    if ! gh auth status 2>&1 | grep -q "'project'"; then
      echo "warn: token may lack 'project' scope. Run: gh auth refresh -s project,read:project" >&2
    fi
  fi
fi

# ---------- 선택 ----------
csv_json() { if [ -z "$1" ]; then echo '[]'; else echo "$1" | jq -Rc 'split(",") | map(select(length>0))'; fi; }
SEL="$TMP/selected.json"
jq --argjson phases "$(csv_json "$PHASES")" --argjson sprints "$(csv_json "$SPRINTS")" \
   --argjson keys "$(csv_json "$KEYS")" --argjson oa "$OWNER_ACTIONS" \
   --argjson xp "$EXCLUDE_PROPOSALS" --argjson ne "$NO_EPICS" '
  (.issues) as $all
  | (($phases|length)+($sprints|length)+($keys|length)+$oa) as $nfilters
  | [ $all[]
      | select(.kind != "epic")
      | select($xp == 0 or (.proposal|not))
      | select($nfilters == 0
          or (.phase as $p | $phases | index($p))
          or (.sprint as $s | $sprints | index($s))
          or (.key as $k | $keys | index($k))
          or ($oa == 1 and .ownerAction)) ] as $items
  | (if $ne == 1 then [] else [ $all[] | select(.kind == "epic") ] end) + $items
' "$FILES" > "$SEL"
n_sel=$(jq 'length' "$SEL")
n_epic=$(jq '[.[]|select(.kind=="epic")]|length' "$SEL")
echo "   selected: $n_sel issues ($n_epic epics, $((n_sel - n_epic)) items)"

# 키→제목, 제안 여부 맵(링크 블록 렌더링용)
TITLES="$TMP/titles.json"
jq '[.issues[] | {key: .key, value: {t: (.title | sub("^\\[[A-Z]+-[0-9]+\\] "; "")), p: .proposal}}] | from_entries' "$FILES" > "$TITLES"

map_json() { jq -Rn '[inputs | split("\t") | select(length==2) | {key: .[0], value: (.[1]|tonumber)}] | from_entries' < "$MAP"; }

# 링크 블록을 다시 써서 본문을 stdout으로 낸다. $1=issue JSON, $2=원본 본문 파일
render_body() {
  local issue_json="$1" body_file="$2"
  jq -jn --argjson it "$issue_json" --argjson map "$(map_json)" --slurpfile titles "$TITLES" --rawfile body "$body_file" '
    ($titles[0]) as $T
    | def line($k): if $map[$k] then "- #\($map[$k]) \($k)" else ("- \($k) \($T[$k].t // "")" | rtrimstr(" ")) end;
      def prop($k): if ($T[$k].p // false) then " (제안)" else "" end;
      def child($k): if $map[$k] then "- [ ] #\($map[$k])" else "- [ ] \($k) \($T[$k].t // "")\(prop($k))" end;
      def block:
        if $it.kind == "epic" then
          "**하위 항목**\n" + ($it.children | map(child(.)) | join("\n"))
        else
          "**에픽**: " + (if $it.epic and $map[$it.epic] then "#\($map[$it.epic]) \($it.epic)" else ($it.epic // "-") end) + "\n\n"
          + "**먼저 끝나야 하는 항목**: " + (if ($it.deps|length) > 0 then "" else "없음" end)
          + ($it.deps | map("\n" + line(.)) | join(""))
          + (if ($it.cardDeps|length) > 0 then
               "\n\n**카드가 더한 의존**(색인은 스파인 값 유지, 02 §10.3. 제안 항목은 채택될 때만 유효):"
               + ($it.cardDeps | map("\n" + line(.) + prop(.)) | join(""))
             else "" end)
        end;
      "<!-- df-links:start -->" as $S | "<!-- df-links:end -->" as $E
      | if ($body | contains($S)) and ($body | contains($E)) then
          ($body | split($S)) as $a | ($a[1] | split($E)) as $b
          | $a[0] + $S + "\n" + block + "\n" + $E + ($b[1:] | join($E))
        else $body + "\n\n" + $S + "\n" + block + "\n" + $E + "\n" end'
}

# ---------- labels ----------
if step_on labels; then
  n=$(jq '.labels|length' "$LABELS_FILE")
  PLAN_LABELS="$n"
  echo "-- labels: $n (gh label create --force, idempotent)"
  jq -r '.labels[] | [.name, .color, .description] | join("\u001f")' "$LABELS_FILE" |
  while IFS=$'\x1f' read -r name color desc; do
    if [ "$APPLY" -eq 1 ]; then
      gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force >/dev/null
      echo "   label ok: $name"
    else
      echo "  [dry-run] gh label create \"$name\" --repo $REPO --color $color --force"
    fi
  done
fi

# ---------- milestones ----------
if step_on milestones; then
  PLAN_MILESTONES=$(jq --argjson skip "$SKIP_TRACKING" '[.milestones[] | select($skip == 0 or (.trackingOnly|not))] | length' "$MILESTONES_FILE")
  echo "-- milestones: $PLAN_MILESTONES (create when the title is missing, update due date/description)"
  EXIST_MS="$TMP/ms.tsv"; : > "$EXIST_MS"
  if [ "$APPLY" -eq 1 ]; then
    gh api --paginate "repos/$REPO/milestones?state=all&per_page=100" \
      --jq '.[] | [.number, .title, ((.due_on // "")[0:10]), (.description // "")] | @tsv' > "$EXIST_MS"
  fi
  jq -r --argjson skip "$SKIP_TRACKING" '.milestones[] | select($skip == 0 or (.trackingOnly|not))
      | [.title, (.due_on // ""), .description] | join("\u001f")' "$MILESTONES_FILE" |
  while IFS=$'\x1f' read -r title due desc; do
    due_utc=""; [ -n "$due" ] && due_utc="${due}T14:59:59Z"   # 23:59:59 KST
    if [ "$APPLY" -ne 1 ]; then
      echo "  [dry-run] ensure milestone \"$title\" due=${due:-none}"
      continue
    fi
    row=$(awk -F'\t' -v t="$title" '$2==t {print; exit}' "$EXIST_MS")
    if [ -z "$row" ]; then
      if [ -n "$due_utc" ]; then
        gh api -X POST "repos/$REPO/milestones" -f title="$title" -f description="$desc" -f due_on="$due_utc" >/dev/null
      else
        gh api -X POST "repos/$REPO/milestones" -f title="$title" -f description="$desc" >/dev/null
      fi
      echo "   milestone created: $title"
    else
      num=$(printf '%s' "$row" | cut -f1); cur_due=$(printf '%s' "$row" | cut -f3); cur_desc=$(printf '%s' "$row" | cut -f4-)
      if [ "$cur_due" != "$due" ] || [ "$cur_desc" != "$desc" ]; then
        if [ -n "$due_utc" ]; then
          gh api -X PATCH "repos/$REPO/milestones/$num" -f description="$desc" -f due_on="$due_utc" >/dev/null
        else
          gh api -X PATCH "repos/$REPO/milestones/$num" -f description="$desc" >/dev/null
        fi
        echo "   milestone updated: $title"
      else
        echo "   milestone ok: $title"
      fi
    fi
  done
fi

# ---------- project ----------
FIELDS="$TMP/fields.json"; echo '{"fields":[]}' > "$FIELDS"
PROJECT_ID=""
load_project() {
  [ -n "$PROJECT_NUMBER" ] || return 0
  [ "$APPLY" -eq 1 ] || return 0
  PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json --jq '.id')
  gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json --limit 100 > "$FIELDS"
}
if step_on project; then
  echo "-- project (owner=$PROJECT_OWNER number=${PROJECT_NUMBER:-unset})"
  if [ -z "$PROJECT_NUMBER" ] && [ "$CREATE_PROJECT" -eq 1 ]; then
    if [ "$APPLY" -eq 1 ]; then
      PROJECT_NUMBER=$(gh project create --owner "$PROJECT_OWNER" --title "$PROJECT_TITLE" --format json --jq '.number')
      echo "   project created: #$PROJECT_NUMBER  (export PROJECT_NUMBER=$PROJECT_NUMBER)"
    else
      echo "  [dry-run] gh project create --owner $PROJECT_OWNER --title \"$PROJECT_TITLE\""
    fi
  fi
  if [ -z "$PROJECT_NUMBER" ]; then
    echo "   PROJECT_NUMBER not set: skip fields. (--create-project or export PROJECT_NUMBER=<n>)"
  else
    load_project
    for spec in "Points:NUMBER" "Sprint:TEXT" "Phase:SINGLE_SELECT"; do
      fname="${spec%%:*}"; ftype="${spec#*:}"
      has=$(jq --arg n "$fname" '[.fields[] | select(.name == $n)] | length' "$FIELDS")
      if [ "$has" -gt 0 ]; then echo "   field ok: $fname"; continue; fi
      if [ "$ftype" = "SINGLE_SELECT" ]; then
        gh_run project field-create "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --name "$fname" \
          --data-type SINGLE_SELECT --single-select-options "P0,P1a,P1b,P2,P3,V2" >/dev/null
      else
        gh_run project field-create "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --name "$fname" --data-type "$ftype" >/dev/null
      fi
      [ "$APPLY" -eq 1 ] && echo "   field created: $fname"
    done
    echo "   note: 1주 Iteration 필드는 gh CLI로 만들 수 없어 웹에서 만든다(01 Projects 필드). Sprint(TEXT)는 색인의 스프린트 값을 담는다."
  fi
fi

# 보드 추가와 필드 채우기
set_fields() { # $1=issue number $2=issue json
  [ -n "$PROJECT_NUMBER" ] || return 0
  local url="https://github.com/$REPO/issues/$1" item pts sprint phase
  if [ "$APPLY" -ne 1 ]; then echo "  [dry-run] gh project item-add $PROJECT_NUMBER --owner $PROJECT_OWNER --url $url"; return 0; fi
  [ -n "$PROJECT_ID" ] || load_project
  item=$(gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --url "$url" --format json --jq '.id')
  if [ "$(printf '%s\n' "$2" | jq -r '.kind')" = "epic" ]; then return 0; fi   # 에픽은 보드에만 추가
  pts=$(printf '%s\n' "$2" | jq -r '.points'); sprint=$(printf '%s\n' "$2" | jq -r '.sprint // empty'); phase=$(printf '%s\n' "$2" | jq -r '.phase')
  local fid ftype oid
  fid=$(jq -r '.fields[] | select(.name=="Points") | .id' "$FIELDS")
  [ -n "$fid" ] && gh project item-edit --id "$item" --project-id "$PROJECT_ID" --field-id "$fid" --number "$pts" >/dev/null
  if [ -n "$sprint" ]; then
    fid=$(jq -r '.fields[] | select(.name=="Sprint") | .id' "$FIELDS"); ftype=$(jq -r '.fields[] | select(.name=="Sprint") | .type' "$FIELDS")
    if [ -n "$fid" ] && [ "$ftype" = "ProjectV2Field" ]; then
      gh project item-edit --id "$item" --project-id "$PROJECT_ID" --field-id "$fid" --text "$sprint" >/dev/null
    elif [ -n "$fid" ] && [ "$ftype" = "ProjectV2SingleSelectField" ]; then
      oid=$(jq -r --arg v "$sprint" '.fields[] | select(.name=="Sprint") | .options[]? | select(.name==$v) | .id' "$FIELDS")
      [ -n "$oid" ] && gh project item-edit --id "$item" --project-id "$PROJECT_ID" --field-id "$fid" --single-select-option-id "$oid" >/dev/null
    fi
  fi
  fid=$(jq -r '.fields[] | select(.name=="Phase") | .id' "$FIELDS")
  if [ -n "$fid" ]; then
    oid=$(jq -r --arg v "$phase" '.fields[] | select(.name=="Phase") | .options[]? | select(.name==$v) | .id' "$FIELDS")
    [ -n "$oid" ] && gh project item-edit --id "$item" --project-id "$PROJECT_ID" --field-id "$fid" --single-select-option-id "$oid" >/dev/null
  fi
  return 0
}

# 기존 이슈 맵(제목의 [KEY]). 검색 API는 색인 지연과 대괄호 무시 때문에 쓰지 않는다.
load_existing() {
  [ "$APPLY" -eq 1 ] || return 0
  gh issue list --repo "$REPO" --state all --limit 3000 --json number,title \
    --jq '.[] | [.number, .title] | @tsv' > "$TMP/existing.tsv"
  local total; total=$(wc -l < "$TMP/existing.tsv" | tr -d ' ')
  [ "$total" -lt 3000 ] || die "3000 issues or more; refusing to guess duplicates"
  awk -F'\t' 'match($2, /^\[(DF-[0-9][0-9][0-9]|EP-[0-9][0-9])\]/) { print substr($2, 2, RLENGTH - 2) "\t" $1 }' \
    "$TMP/existing.tsv" > "$MAP"
}
lookup() { awk -F'\t' -v k="$1" '$1==k {print $2; exit}' "$MAP"; }

# ---------- issues ----------
if step_on issues; then
  echo "-- issues"
  load_existing
  [ "$APPLY" -eq 1 ] && [ -n "$PROJECT_NUMBER" ] && load_project
  created=0; skipped=0
  i=0
  while [ "$i" -lt "$n_sel" ]; do
    it=$(jq -c ".[$i]" "$SEL"); i=$((i + 1))
    key=$(printf '%s\n' "$it" | jq -r '.key'); title=$(printf '%s\n' "$it" | jq -r '.title')
    milestone=$(printf '%s\n' "$it" | jq -r '.milestone // empty')
    labels_csv=$(printf '%s\n' "$it" | jq -r '.labels | join(",")')
    num=$(lookup "$key")
    if [ -n "$num" ]; then
      echo "   skip (exists #$num): $title"; skipped=$((skipped + 1))
      [ -n "$PROJECT_NUMBER" ] && set_fields "$num" "$it"
      continue
    fi
    if [ "$APPLY" -ne 1 ]; then
      echo "  [dry-run] create $title | milestone=${milestone:-none} | labels=$labels_csv"
      created=$((created + 1)); continue
    fi
    printf '%s\n' "$it" | jq -j '.body' > "$TMP/raw.md"
    render_body "$it" "$TMP/raw.md" > "$TMP/body.md"
    set -- --repo "$REPO" --title "$title" --body-file "$TMP/body.md"
    for l in $(printf '%s\n' "$it" | jq -r '.labels[]'); do set -- "$@" --label "$l"; done
    [ -n "$milestone" ] && set -- "$@" --milestone "$milestone"
    url=$(gh issue create "$@")
    num="${url##*/}"
    printf '%s\t%s\n' "$key" "$num" >> "$MAP"
    echo "$key" >> "$CREATED"
    cp "$TMP/body.md" "$TMP/sent_$key.md"
    echo "   created #$num: $title"
    created=$((created + 1))
    set_fields "$num" "$it"
    [ "$DELAY" != "0" ] && sleep "$DELAY"
  done
  if [ "$APPLY" -eq 1 ]; then
    echo "   result: created $created, skipped(existing) $skipped"
  else
    echo "   plan: $created issues would be created unless a title with the same [KEY] already exists (checked only with --apply)"
    PLAN_ISSUES="$created"
  fi
fi

# ---------- relink ----------
relink_one() { # $1=key $2=fetch(1)|fresh(0)
  local key="$1" num it
  num=$(lookup "$key"); [ -n "$num" ] || return 0
  it=$(jq -c --arg k "$key" '.issues[] | select(.key == $k)' "$FILES")
  [ -n "$it" ] || return 0
  if [ "$2" = "1" ]; then
    gh issue view "$num" --repo "$REPO" --json body --jq '.body' > "$TMP/raw.md"
  else
    cp "$TMP/sent_$key.md" "$TMP/raw.md"   # 생성 때 보낸 본문과 비교해 바뀐 것만 고친다
  fi
  render_body "$it" "$TMP/raw.md" > "$TMP/body.md"
  if ! cmp -s "$TMP/raw.md" "$TMP/body.md"; then
    gh issue edit "$num" --repo "$REPO" --body-file "$TMP/body.md" >/dev/null
    echo "   relinked #$num $key"
  fi
}
if [ "$APPLY" -eq 1 ] && step_on issues && [ -s "$CREATED" ]; then
  echo "-- links (issues created in this run + their epics)"
  while read -r k; do relink_one "$k" 0; done < "$CREATED"
  jq -r --rawfile c "$CREATED" '($c | split("\n") | map(select(length>0))) as $keys
      | .issues[] | select(.kind == "epic") | select(any(.children[]; . as $x | $keys | index($x))) | .key' "$FILES" |
  while read -r e; do
    grep -qx "$e" "$CREATED" || relink_one "$e" 1
  done
fi
if step_on relink && ! step_on issues; then
  echo "-- relink (selected existing issues)"
  if [ "$APPLY" -ne 1 ]; then
    echo "  [dry-run] would rewrite the df-links block of $n_sel selected issues that already exist"
  else
    load_existing
    jq -r '.[].key' "$SEL" | while read -r k; do relink_one "$k" 1; done
  fi
fi

if [ "$APPLY" -ne 1 ]; then
  echo "== plan: labels $PLAN_LABELS, milestones $PLAN_MILESTONES, issues $PLAN_ISSUES (dry-run: gh was not called)"
fi
echo "== done ($mode)"

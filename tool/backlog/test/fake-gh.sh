#!/usr/bin/env bash
# 가짜 gh(테스트 전용). 네트워크에 접근하지 않는다.
# 모든 호출 인자를 $FAKE_GH_LOG에 한 줄로 남기고, $FAKE_GH_STATE 폴더에 이슈·마일스톤 상태를 흉내 낸다.
set -euo pipefail
: "${FAKE_GH_LOG:?}" "${FAKE_GH_STATE:?}"
mkdir -p "$FAKE_GH_STATE/bodies"
touch "$FAKE_GH_STATE/issues.tsv" "$FAKE_GH_STATE/ms.tsv"
printf '%s\n' "$*" >> "$FAKE_GH_LOG"
arg() { # 이름 있는 인자 값: arg --title "$@"
  local want="$1"; shift
  while [ $# -gt 0 ]; do [ "$1" = "$want" ] && { echo "$2"; return; }; shift; done
}
case "$1 ${2:-}" in
  "auth status") echo "  - Token scopes: 'gist', 'project', 'read:org', 'repo'" ;;
  "label create") : ;;
  "api --paginate") cat "$FAKE_GH_STATE/ms.tsv" ;;
  "api -X")
    if [ "$3" = "POST" ]; then
      n=$(( $(wc -l < "$FAKE_GH_STATE/ms.tsv") + 1 ))
      t=""; d=""; due=""
      shift 4
      while [ $# -gt 0 ]; do
        case "$2" in title=*) t="${2#title=}" ;; description=*) d="${2#description=}" ;; due_on=*) due="${2#due_on=}" ;; esac
        shift 2
      done
      printf '%s\t%s\t%s\t%s\n' "$n" "$t" "${due:0:10}" "$d" >> "$FAKE_GH_STATE/ms.tsv"
    fi ;;
  "issue list") cat "$FAKE_GH_STATE/issues.tsv" ;;
  "issue create")
    title=$(arg --title "$@"); bf=$(arg --body-file "$@")
    n=$(( $(wc -l < "$FAKE_GH_STATE/issues.tsv") + 1 ))
    printf '%s\t%s\n' "$n" "$title" >> "$FAKE_GH_STATE/issues.tsv"
    cp "$bf" "$FAKE_GH_STATE/bodies/$n.md"
    echo "https://github.com/TEhyeok/DFET_Coach/issues/$n" ;;
  "issue view") cat "$FAKE_GH_STATE/bodies/$3.md" ;;
  "issue edit") cp "$(arg --body-file "$@")" "$FAKE_GH_STATE/bodies/$3.md" ;;
  "project view") echo "PVT_fake" ;;
  "project field-list") echo '{"fields":[{"id":"F_pts","name":"Points","type":"ProjectV2Field"},{"id":"F_spr","name":"Sprint","type":"ProjectV2Field"},{"id":"F_ph","name":"Phase","type":"ProjectV2SingleSelectField","options":[{"id":"o_p0","name":"P0"},{"id":"o_p1a","name":"P1a"}]}]}' ;;
  "project item-add") echo "ITEM_$RANDOM" ;;
  "project item-edit"|"project field-create"|"project create") : ;;
  *) echo "fake-gh: unsupported: $*" >&2; exit 3 ;;
esac

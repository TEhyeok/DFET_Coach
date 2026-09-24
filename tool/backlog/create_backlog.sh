#!/usr/bin/env bash
# TL-11 호환 진입점. 문서(01·02·P0 DF-002·SPRINT_01)가 부르는 이름을 유지하려고 둔다.
# 실제 구현은 create_github_issues.sh다. 인자는 그대로 넘긴다.
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/create_github_issues.sh" "$@"

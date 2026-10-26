#!/bin/bash
# PostToolUse guardrail: after an edit under Sources/ or scripts/, run the layering, boundary and
# taste checks. Exit 2 returns the message to Claude so it fixes the edit; it cannot undo the edit, so
# the same script is a required CI check (`make check`) for changes that bypass Edit|Write.
set -uo pipefail
input=$(cat)
file=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' <<<"$input" 2>/dev/null)
case "$file" in
  */Sources/*|*/scripts/check-*) ;;
  *) exit 0 ;;
esac
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}" || exit 0
if ! out=$(python3 scripts/check-architecture.py 2>&1); then
  printf '%s\nFix the violation above (see ARCHITECTURE.md#boundaries), then continue.\n' "$out" >&2
  exit 2
fi
exit 0

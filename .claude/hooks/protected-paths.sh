#!/bin/bash
# PreToolUse approval gate: editing a protected path asks the person running the session first. The
# paths are the ones AGENTS.md lists under "Merge gate": credential handling, CI, security policy and
# this hook's own settings. Non-interactive runs cannot answer an ask, so Claude Code denies them.
# The gate reads only the tool call; the agent cannot approve its own edit.
input=$(cat)
read -r tool file < <(python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("tool_name", "") or "-", d.get("tool_input", {}).get("file_path", "") or "-")' <<<"$input" 2>/dev/null)

decide() {   # decide <allow|ask|deny> <reason>
  python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
  "permissionDecision": sys.argv[1], "permissionDecisionReason": sys.argv[2]}}))' "$1" "$2"
  exit 0
}

case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) decide deny "No gate rule for '$tool'. Add one to .claude/hooks/protected-paths.sh first." ;;
esac

case "$file" in
  */Sources/AgentConsumption/Keychain.swift|*/Sources/AgentConsumption/DesktopAuth.swift|\
  */Sources/AgentConsumption/ClaudeClient.swift|*/Sources/AgentConsumption/CodexClient.swift)
    decide ask "$file handles login tokens (credential-handling policy). Approve only if you own this change." ;;
  */.github/*|*/SECURITY.md|*/docs/SECURITY.md|*/.claude/*|*/scripts/check-*)
    decide ask "$file is a protected path (CI, security policy or the gates themselves). Approve only if you own this change." ;;
  *) exit 0 ;;
esac

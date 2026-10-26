#!/usr/bin/env python3
"""PreToolUse approval gate: editing a protected path asks the person running the session first.

The paths are the ones AGENTS.md lists under "Merge gate": credential handling, CI, the security
policy and this gate's own settings. Non-interactive runs cannot answer an ask, so Claude Code denies
them. The gate reads only the tool call; the agent cannot approve its own edit.

It covers the file-editing tools. A shell command that rewrites a protected file (sed -i, cp) does not
pass through it, so CODEOWNERS and the CI checks are the backstop (TD-10 in docs/tech-debt-tracker.md).
Fails closed: a tool it was not written for, or an edit with no path, is denied.
"""

import json
import os
import re
import sys

EDIT_TOOLS = {"Edit": "file_path", "Write": "file_path", "MultiEdit": "file_path", "NotebookEdit": "notebook_path"}

CREDENTIALS = re.compile(r"/sources/agentconsumption/(keychain|desktopauth|claudeclient|codexclient)\.swift$")
PROTECTED = re.compile(r"/\.github/|/security\.md$|/\.claude/|/scripts/check-[^/]*$")


def decide(decision: str, reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": decision,
                                              "permissionDecisionReason": reason}}))
    sys.exit(0)


def main() -> None:
    call = json.load(sys.stdin)
    tool = call.get("tool_name", "")
    if tool not in EDIT_TOOLS:
        decide("deny", f"No gate rule for '{tool}'. Add one to .claude/hooks/protected-paths.py first.")
    given = (call.get("tool_input") or {}).get(EDIT_TOOLS[tool], "")
    if not given:
        decide("deny", f"{tool} has no {EDIT_TOOLS[tool]}, so it cannot be checked against the protected paths.")

    root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    normalized = os.path.normpath(os.path.join(root, given))
    # Match the normalized path and where a symlink really points, folded to lower case because the
    # default macOS filesystem ignores case.
    candidates = {normalized.lower(), os.path.realpath(normalized).lower()}

    if any(CREDENTIALS.search(c) for c in candidates):
        decide("ask", f"{given} handles login tokens (credential-handling policy). Approve only if you own this change.")
    if any(PROTECTED.search(c) for c in candidates):
        decide("ask", f"{given} is a protected path (CI, security policy or the gates themselves). "
                      "Approve only if you own this change.")


if __name__ == "__main__":
    main()

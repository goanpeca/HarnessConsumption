#!/usr/bin/env python3
"""Behavior check for the Claude Code hooks in .claude/hooks (see AGENTS.md, "Merge gate").

Feeds sample tool calls to the protected-paths gate and checks the decision, including paths that
name a protected file indirectly (dot segments, relative paths, other case, a symlink). Stdlib only.
Exit 1 on any wrong decision.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GATE = ROOT / ".claude" / "hooks" / "protected-paths.py"


def decide(call: dict) -> str:
    run = subprocess.run(
        [sys.executable, str(GATE)], input=json.dumps(call), capture_output=True, text=True,
        env={**os.environ, "CLAUDE_PROJECT_DIR": str(ROOT)},
    )
    out = run.stdout.strip()
    return json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out else "allow"


def edit(path: str, tool: str = "Edit", key: str = "file_path") -> dict:
    return {"tool_name": tool, "tool_input": {key: path}}


def main() -> int:
    root = str(ROOT)
    keychain = "Sources/AgentConsumption/Keychain.swift"
    with tempfile.TemporaryDirectory() as tmp:
        link = Path(tmp) / "innocent.txt"
        link.symlink_to(ROOT / keychain)
        spaced = Path(tmp) / "a b" / keychain
        cases = [
            ("credential file", edit(f"{root}/{keychain}"), "ask"),
            ("dot segment", edit(f"{root}/Sources/AgentConsumption/./Keychain.swift"), "ask"),
            ("dot-dot segment", edit(f"{root}/Sources/ConsumptionKit/../AgentConsumption/Keychain.swift"), "ask"),
            ("check script via dot segment", edit(f"{root}/scripts/./check-docs.py", "Write"), "ask"),
            ("other case", edit(f"{root}/Sources/AgentConsumption/keychain.swift"), "ask"),
            ("symlink to a protected file", edit(str(link)), "ask"),
            ("relative path", edit(keychain), "ask"),
            ("notebook tool", edit(f"{root}/.github/x.ipynb", "NotebookEdit", "notebook_path"), "ask"),
            ("path with spaces", edit(str(spaced)), "ask"),
            ("workflow", edit(f"{root}/.github/workflows/ci.yml", "Write"), "ask"),
            ("security policy", edit(f"{root}/docs/SECURITY.md"), "ask"),
            ("the gate itself", edit(f"{root}/.claude/hooks/protected-paths.py"), "ask"),
            ("ordinary file", edit(f"{root}/README.md"), "allow"),
            ("ordinary source", edit(f"{root}/Sources/ConsumptionKit/Budget.swift"), "allow"),
            ("unknown tool", {"tool_name": "Bash", "tool_input": {}}, "deny"),
            ("edit with no path", {"tool_name": "Edit", "tool_input": {}}, "deny"),
        ]
        wrong = [(n, decide(c), want) for n, c, want in cases if decide(c) != want]
    if wrong:
        print("check-hooks: FAILED", file=sys.stderr)
        for name, got, want in wrong:
            print(f"  {name}: gate said '{got}', expected '{want}'. Fix .claude/hooks/protected-paths.py.", file=sys.stderr)
        return 1
    print(f"check-hooks: OK ({len(cases)} gate decisions)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

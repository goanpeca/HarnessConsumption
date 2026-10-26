#!/usr/bin/env python3
"""Quality ratchet: line coverage must not drop below the floors.

Runs `swift test --enable-code-coverage`, then reads SwiftPM's coverage JSON. Two groups are measured:
`ConsumptionKit` (the logic), and the logic and views of the app target. Four app files are left out
because they only run inside a real app (the entry point, notifications, window pinning and the
login item); see docs/QUALITY_SCORE.md. Raise the floors when coverage rises; never lower them to make
a change pass: add the missing test instead.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {
    # name: (path fragment, total floor %, per-file floor %)
    "ConsumptionKit": ("/Sources/ConsumptionKit/", 97.0, 90.0),
    "AgentConsumption": ("/Sources/AgentConsumption/", 92.0, 80.0),
}
NEEDS_A_REAL_APP = {"App.swift", "Notifier.swift", "PanelPinning.swift", "LaunchAtLogin.swift"}


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"error: `{' '.join(cmd)}` failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")
    return result.stdout


def main() -> int:
    run(["swift", "test", "--enable-code-coverage"])
    report = Path(run(["swift", "test", "--show-codecov-path"]).strip())
    data = json.loads(report.read_text(encoding="utf-8"))["data"][0]["files"]

    errors: list[str] = []
    summary: list[str] = []
    for name, (fragment, total_floor, file_floor) in GROUPS.items():
        rows = []
        covered = count = 0
        for entry in data:
            path = entry["filename"]
            if fragment not in path or path.rsplit("/", 1)[1] in NEEDS_A_REAL_APP:
                continue
            lines = entry["summary"]["lines"]
            covered += lines["covered"]
            count += lines["count"]
            rows.append((lines["percent"], path.split("/Sources/")[1]))
        if not count:
            sys.exit(f"check-coverage: no {name} coverage found. Did the test target build?")
        total = 100 * covered / count
        summary.append(f"{total:.1f}% of {name} lines, floor {total_floor:.0f}%")
        if total < total_floor:
            errors.append(
                f"{name} line coverage is {total:.1f}% (floor {total_floor:.0f}%). "
                f"Add tests for the least-covered files below; do not lower the floor."
            )
        for percent, file in sorted(rows):
            if percent < file_floor:
                errors.append(f"{file} is at {percent:.1f}% (file floor {file_floor:.0f}%). Test its untested branches.")
            if total < total_floor:
                errors.append(f"    {percent:5.1f}%  {file}")

    if errors:
        print("check-coverage: FAILED", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    print(f"check-coverage: OK ({'; '.join(summary)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

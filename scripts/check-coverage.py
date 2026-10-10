#!/usr/bin/env python3
"""Quality ratchet: line coverage of ConsumptionKit must not drop below the floors.

Runs `swift test --enable-code-coverage`, then reads SwiftPM's coverage JSON. The app target is
not counted: it is UI and I/O glue (see docs/QUALITY_SCORE.md). Raise the floors when coverage
rises; never lower them to make a change pass: add the missing test instead.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOTAL_FLOOR = 90.0  # percent of lines across ConsumptionKit
FILE_FLOOR = 75.0  # percent of lines for any single file


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"error: `{' '.join(cmd)}` failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")
    return result.stdout


def main() -> int:
    run(["swift", "test", "--enable-code-coverage"])
    report = Path(run(["swift", "test", "--show-codecov-path"]).strip())
    data = json.loads(report.read_text(encoding="utf-8"))["data"][0]["files"]

    rows = []
    covered = count = 0
    for entry in data:
        name = entry["filename"]
        if "/Sources/ConsumptionKit/" not in name:
            continue
        lines = entry["summary"]["lines"]
        covered += lines["covered"]
        count += lines["count"]
        rows.append((lines["percent"], name.split("/Sources/")[1]))

    if not count:
        sys.exit("check-coverage: no ConsumptionKit coverage found. Did the test target build?")
    total = 100 * covered / count
    errors = []
    if total < TOTAL_FLOOR:
        errors.append(
            f"ConsumptionKit line coverage is {total:.1f}% (floor {TOTAL_FLOOR:.0f}%). "
            f"Add tests for the least-covered files below; do not lower the floor."
        )
    for percent, name in sorted(rows):
        if percent < FILE_FLOOR:
            errors.append(f"{name} is at {percent:.1f}% (file floor {FILE_FLOOR:.0f}%). Test its untested branches.")

    if errors:
        print("check-coverage: FAILED", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        for percent, name in sorted(rows):
            print(f"    {percent:5.1f}%  {name}", file=sys.stderr)
        return 1
    print(f"check-coverage: OK ({total:.1f}% of ConsumptionKit lines, floor {TOTAL_FLOOR:.0f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

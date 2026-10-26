#!/usr/bin/env python3
"""Mutation testing for ConsumptionKit.

Applies one small change at a time (a flipped comparison, a shifted constant, a swapped branch) to a
temporary copy of the repo and runs the test suite. A mutant that makes the suite fail is killed; one
that doesn't (a survivor) is behavior no test pins down. Exit 1 on any survivor or on a mutation whose
pattern no longer matches the code. See docs/references/mutation-testing.md. Stdlib only.

    python3 scripts/mutation.py            # all mutants
    python3 scripts/mutation.py --check    # only verify every pattern still matches
    python3 scripts/mutation.py --only Pacing
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KIT = "Sources/ConsumptionKit/"
TIMEOUT = 900

# (file, original text, mutated text): each original must appear in the file.
MUTANTS = [
    ("Pacing.swift", "elapsed + countsToday", "elapsed"),
    ("Pacing.swift", "usedPercent > targetUsedByEndOfToday + 0.5", "usedPercent > targetUsedByEndOfToday - 0.5"),
    ("Pacing.swift", "window.remainingPercent / Double(max(left, 1))", "window.remainingPercent / Double(max(left, 0) + 1)"),
    ("Pacing.swift", "total == 0 ? 100", "total == 0 ? 0"),
    ("Pacing.swift", "calendar.isWorkDay(now) && left > 0", "calendar.isWorkDay(now) || left > 0"),
    ("UsageLevel.swift", "criticalRemaining = 10.0", "criticalRemaining = 11.0"),
    ("UsageLevel.swift", "watchRemaining = 25.0", "watchRemaining = 26.0"),
    ("UsageLevel.swift", "criticalOverPace = 10.0", "criticalOverPace = 11.0"),
    ("UsageLevel.swift", "if over > UsageLevel.criticalOverPace", "if over >= UsageLevel.criticalOverPace"),
    ("UsageLevel.swift", "if remainingPercent < UsageLevel.criticalRemaining { return .critical }", "if remainingPercent <= UsageLevel.criticalRemaining { return .critical }"),
    ("Budget.swift", "used / total * 100", "used / total"),
    ("Budget.swift", "max(totalUSD - spentUSD, 0)", "min(totalUSD - spentUSD, 0)"),
    ("Budget.swift", "reading.limit > 0 ?", "reading.limit >= 0 ?"),
    ("Budget.swift", "guard total > 0 else", "guard total >= 0 else"),
    ("Budget.swift", ".min { ($0.resetsAt ?? .distantFuture) < ($1.resetsAt ?? .distantFuture) }", ".max { ($0.resetsAt ?? .distantFuture) < ($1.resetsAt ?? .distantFuture) }"),
    ("Budget.swift", "case .codex: codexLimitUSD", "case .codex: claudeUSD"),
    ("Budget.swift", "max(pace.workDaysLeft, 1)", "max(pace.workDaysLeft, 0) + 1"),
    ("UsageParsing.swift", 'extra.currency == "USD"', 'extra.currency != "USD"'),
    ("UsageParsing.swift", "used / scale, limit: limit / scale", "used / scale, limit: limit"),
    ("UsageParsing.swift", "byAdding: .month, value: 1, to: start", "byAdding: .month, value: 2, to: start"),
    ("UsageParsing.swift", "byAdding: .month, value: -1, to: reset", "byAdding: .month, value: -2, to: reset"),
    ("UsageParsing.swift", "extra.decimal_places ?? 2", "extra.decimal_places ?? 3"),
    ("UsageParsing.swift", "windows.isEmpty, let used", "!windows.isEmpty, let used"),
    ("UsageModels.swift", "length > 86_400 ? .weekly : .session", "length > 86_400 ? .session : .weekly"),
    ("UsageModels.swift", "case .monthly: 30 * 86_400", "case .monthly: 7 * 86_400"),
    ("UsageModels.swift", "weekly ?? monthly", "monthly ?? weekly"),
    ("UsageModels.swift", "min(max(usedPercent, 0), 100)", "max(usedPercent, 0)"),
    ("AlertPlanner.swift", "nearlyOutThreshold: Double = 10", "nearlyOutThreshold: Double = 20"),
    ("AlertPlanner.swift", "sessionResetMinimumUsed: Double = 50", "sessionResetMinimumUsed: Double = 0"),
    ("AlertPlanner.swift", "window.remainingPercent < nearlyOutThreshold", "window.remainingPercent <= nearlyOutThreshold"),
    ("AlertPlanner.swift", "reset.timeIntervalSince(previous) > 300", "reset.timeIntervalSince(previous) > 0"),
    ("WorkSettings.swift", "forKey: .isConfigured) ?? true", "forKey: .isConfigured) ?? false"),
    ("WorkSettings.swift", "Self(countryCode: regionCode, isConfigured: false)", "Self(countryCode: regionCode, isConfigured: true)"),
    ("WorkSettings.swift", "countryCode != nil && skipHolidays", "countryCode != nil || skipHolidays"),
]


def swift_test(cwd: Path) -> tuple[bool, bool]:
    """(tests ran, tests passed)."""
    try:
        run = subprocess.run(["swift", "test"], cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return True, False  # a mutant that hangs the suite is detected
    output = run.stdout + run.stderr
    return "Test run with" in output, run.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="only verify that every pattern still matches")
    parser.add_argument("--only", help="run only mutants whose file name contains this text")
    args = parser.parse_args()

    stale = [f"{f}: {a!r}" for f, a, _ in MUTANTS if a not in (ROOT / KIT / f).read_text(encoding="utf-8")]
    if stale:
        print("mutation: these patterns no longer match the code. Update MUTANTS in scripts/mutation.py:")
        print("\n".join(f"  {s}" for s in stale))
        return 1
    if args.check:
        print(f"mutation: OK ({len(MUTANTS)} patterns match)")
        return 0

    mutants = [m for m in MUTANTS if not args.only or args.only in m[0]]
    with tempfile.TemporaryDirectory(prefix="mutation-") as tmp:
        work = Path(tmp) / "repo"
        shutil.copytree(ROOT, work, ignore=shutil.ignore_patterns(".build", "build", ".git", "*.profraw"))
        print("mutation: baseline test run...", flush=True)
        ran, passed = swift_test(work)
        if not (ran and passed):
            print("mutation: the unmutated suite does not pass; fix the tests first.")
            return 2

        survivors: list[str] = []
        invalid: list[str] = []
        for file, original, mutated in mutants:
            path = work / KIT / file
            source = path.read_text(encoding="utf-8")
            path.write_text(source.replace(original, mutated, 1), encoding="utf-8")
            try:
                ran, passed = swift_test(work)
            finally:
                path.write_text(source, encoding="utf-8")
            label = f"{file}: {original}  =>  {mutated}"
            if not ran:
                invalid.append(label)
                print(f"INVALID   {label}", flush=True)
            elif passed:
                survivors.append(label)
                print(f"SURVIVED  {label}", flush=True)
            else:
                print(f"killed    {label}", flush=True)

    killed = len(mutants) - len(survivors) - len(invalid)
    print(f"\nmutation: {killed}/{len(mutants)} killed")
    if survivors:
        print("Survivors are behavior no test pins down. Add a test that fails for each:")
        print("\n".join(f"  {s}" for s in survivors))
    if invalid:
        print("These mutants did not compile. Fix the mutation in scripts/mutation.py:")
        print("\n".join(f"  {s}" for s in invalid))
    return 1 if survivors or invalid else 0


if __name__ == "__main__":
    sys.exit(main())

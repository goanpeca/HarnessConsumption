# Quality score

Grades per module, A (solid) to D (risky), with the gaps that hold each back. Re-grade when you
change an area; `make coverage` enforces the floors below.

| Module / area | Grade | Evidence | Gaps |
|---|---|---|---|
| `ConsumptionKit`: calendar, settings, pacing | A | 98% line coverage; real 2026 Colombian holidays as fixtures; DST, month and year edges; seeded invariants (shares add up, work days are additive) | |
| `ConsumptionKit`: parsers | A | Real response shapes; every truncation and single-character mutation of a valid payload; random bytes never crash | Endpoints are undocumented; re-verify [usage-endpoints.md](references/usage-endpoints.md) when readings look wrong |
| `ConsumptionKit`: `AlertPlanner`, budgets, levels | A | Once-only, reset, pace, summaries; budget bounds and level monotonicity as invariants; mutants killed | |
| `ConsumptionKit`: `HolidayStore` | A | Cache, offline, validation, and the download path against a stubbed session | |
| App: clients, `DesktopAuth`, `Keychain` | A | Stubbed `URLSession`, a golden safeStorage vector made outside this code base, fake `security` scripts; mutants killed | Never run against the live accounts in CI; verify by hand with `--dump` after endpoint changes |
| App: store and settings persistence | A | Injected fetchers, notifier, defaults and directory; failure keeps the last reading; alerts fire once, across restarts | Timer cadence is not asserted |
| App: views | B | Every screen rendered headlessly in each state; VoiceOver text asserted | No pixel snapshots (no dependency); layout is checked by eye |
| App: `App`, `Notifier`, `PanelPinning`, `LaunchAtLogin` | C | Run only inside a real app | Not measured; [TD-11](tech-debt-tracker.md) |
| Harness: scripts, CI, security | A | Negative-tested checks; zizmor `--pedantic`, actionlint, shellcheck, gitleaks clean | Branch protection is a repo setting ([TD-2](tech-debt-tracker.md)) |

## Floors

- Mutation testing: every mutant in `scripts/mutation.py` is killed, in `ConsumptionKit` and the app's
  logic (`make mutation`; the mutation workflow runs on logic changes and weekly). The list grows with
  the code.
- `ConsumptionKit` line coverage: 97% total, 90% per file; the app target's logic and views: 92% total,
  80% per file, leaving out the four files in the last table row (`scripts/check-coverage.py`).
- Stability: the suite passes five runs in a row (`make stability`, weekly in the mutation workflow).
- Swift files: 300 lines (`scripts/check-file-size.sh`); SwiftLint `--strict`; swift-format `--strict`.
- Builds with `-warnings-as-errors`.

## How tests are written

- Swift Testing, failing test first; no XCTest, no third-party packages.
- Tests never touch real logins, the Keychain, `UserDefaults.standard`, Application Support or the
  network. They use `Sandbox` (temporary directory and defaults suite), `StubSession` (a `URLSession`
  that answers from a closure) and a fake `security` script. `TestSafetyTests` fails if a test file
  names a real one, and calls that would silently fall back to the real login.
- Deterministic: fixed clocks, fixed time zones, pinned locales, and seeded randomness
  (`SeededGenerator`; a failing round prints its seed). No sleeps; the suite passes in any order.
- Production code gets a seam (an injected session, file, defaults or notifier) rather than a global
  switch, with defaults that equal the real behavior.

## Process indicators

One leading and one lagging measure per play, read from git history (the playbook's way to tell whether
a play is working). Baselines are not taken yet: [TD-9](tech-debt-tracker.md).

| Play | Leading | Lagging |
|---|---|---|
| `intent.md` | Time from first conversation to the committed `intent.md` | Share accepted into design; edits to `intent.md` after the first `spec.md` commit |
| `spec.md` | Time from the `intent.md` commit to the `spec.md` commit | `spec.md` commits dated after the first `plan.md` commit for the same change |
| `plan.md` | Share of changes that merge from the first implementation pass | Rework cycles per change; how often the merged diff still matches `plan.md` |
| Hooks and gates | Share of protected-path edits that hit the gate | Protected-path changes merged without a human code-owner approval (target 0) |
| Drift scan | Open drift issues | Weeks a drift issue stays open |


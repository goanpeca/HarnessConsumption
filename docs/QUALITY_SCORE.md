# Quality score

Grades per module, A (solid) to D (risky), with the gaps that hold each back. Re-grade when you
change an area; `make coverage` enforces the floors below.

| Module / area | Grade | Evidence | Gaps |
|---|---|---|---|
| `ConsumptionKit`: calendar, settings, pacing | A | 100% pacing, 93% total line coverage, real 2026 Colombian holidays as fixtures | |
| `ConsumptionKit`: parsers | A | Real response shapes as tests, rejection of empty payloads | Endpoints are undocumented; re-verify [usage-endpoints.md](references/usage-endpoints.md) when readings look wrong |
| `ConsumptionKit`: `AlertPlanner` | A | Once-only, reset, pace, summary covered | |
| `ConsumptionKit`: `HolidayStore` | B | Cache, offline, validation covered | Network fetch path is only exercised by hand |
| App: clients, Keychain | C | Verified by hand against live endpoints | No automated tests; [TD-3](tech-debt-tracker.md) |
| App: store, notifier | C | `--dump` exercises the store | Timer and notification delivery untested |
| App: views | B | Fixed-size panel, native chrome (SDK stamp), previews by hand | No UI tests |
| Harness: scripts, CI, security | A | Negative-tested checks; zizmor `--pedantic`, actionlint, shellcheck, gitleaks clean | Branch protection is a repo setting ([TD-2](tech-debt-tracker.md)) |

## Floors

- Mutation testing: every mutant in `scripts/mutation.py` is killed (`make mutation`; the mutation
  workflow runs on logic changes and weekly). The list grows with the logic.
- `ConsumptionKit` line coverage: 90% total, 75% per file (`scripts/check-coverage.py`).
- Swift files: 300 lines (`scripts/check-file-size.sh`); SwiftLint `--strict`; swift-format `--strict`.
- Builds with `-warnings-as-errors`.

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


# Quality score

Grades per module, A (solid) to D (risky), with the gaps that hold each back. Re-grade when you
change an area; `make coverage` enforces the floors below.

| Module / area | Grade | Evidence | Gaps |
|---|---|---|---|
| `ConsumptionKit`: calendar, settings, pacing | A | 100% pacing, 93% total line coverage, real 2026 Colombian holidays as fixtures | |
| `ConsumptionKit`: parsers | A | Real response shapes as tests, rejection of empty payloads | Endpoints are undocumented; re-verify [usage-endpoints.md](references/usage-endpoints.md) when readings look wrong |
| `ConsumptionKit`: `AlertPlanner` | A | Once-only, reset, pace, summary covered | |
| `ConsumptionKit`: `HolidayStore` | B | Cache, offline, validation covered | Network fetch path is only exercised by hand |
| App: clients, Keychain | C | Verified by hand against live endpoints | No automated tests; [TD-3](exec-plans/tech-debt-tracker.md) |
| App: store, notifier | C | `--dump` exercises the store | Timer and notification delivery untested |
| App: views | B | Fixed-size panel, native chrome (SDK stamp), previews by hand | No UI tests |
| Harness: scripts, CI, security | A | Negative-tested checks; zizmor `--pedantic`, actionlint, shellcheck, gitleaks clean | Branch protection is a repo setting ([TD-2](exec-plans/tech-debt-tracker.md)) |

## Floors

- `ConsumptionKit` line coverage: 90% total, 75% per file (`scripts/check-coverage.py`).
- Swift files: 300 lines (`scripts/check-file-size.sh`); SwiftLint `--strict`; swift-format `--strict`.
- Builds with `-warnings-as-errors`.

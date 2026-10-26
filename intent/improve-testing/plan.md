# Plan: Test the whole app, not only the logic (from intent.md and spec.md)

Status: in progress.

## Files that change

New: `Tests/AgentConsumptionTests/` (test support, tests per file). Seams only in `Sources/AgentConsumption/`: `DesktopAuth.swift`, `ClaudeClient.swift`, `CodexClient.swift`, `UsageStore.swift`, `Notifier.swift`, `*+Defaults.swift`. `Package.swift` (test target). `Tests/ConsumptionKitTests/` (more tests). `scripts/check-coverage.py`, `scripts/mutation.py`. Docs: `docs/QUALITY_SCORE.md`, `docs/tech-debt-tracker.md`.

## Order of work

- [ ] 1. Add the `AgentConsumptionTests` target and test support (stub session, temp dirs, defaults suite, fixed clock, the guard against real access) (R1, R8, R10).
- [ ] 2. Seams for `DesktopAuth`, then its tests (R2).
- [ ] 3. Seams for the two clients, then their tests (R3).
- [ ] 4. Seams for `UsageStore` and the notifier, then store and persistence tests (R4, R5).
- [ ] 5. `ConsumptionKit` gaps: holiday download path, calendar edges, malformed payloads (R6).
- [ ] 6. Seeded invariant and no-crash tests (R7).
- [ ] 7. Coverage gate for the app target, raise the Kit floors, extend the mutation list, update docs and close TD-3 (R9).

## Risks

- A seam that changes production behavior by accident; the existing suite and `--dump` before and after guard it.
- Testing the Swift 6 `@MainActor` store with async fetchers can produce flaky ordering; use awaited calls only, no sleeps (R10, concern 1).
- `@testable import` of an executable target needs a recent toolchain; confirmed first in step 1 (concern 1).
- Touching protected paths (`scripts/check-*`, `scripts/mutation.py`) needs owner approval (concern 3).

## Proof

- R1: `swift test` runs the new target. R2 to R5: the new tests, each shown to fail first. R6, R7: new Kit tests.
- R8: the guard test fails if code reads the real Keychain, defaults or support directory; verified by deliberately triggering it once.
- R9: `make coverage` reports the app floor; `make mutation` kills every listed app mutant.
- R10: the suite passes repeatedly and in parallel (run three times in CI-equivalent conditions before hand-off).
- Whole change: `make ci` green.

## Decision log

- 2026-10-26: Work is on branch `test/max-testing`, in phases that each leave `make ci` green.

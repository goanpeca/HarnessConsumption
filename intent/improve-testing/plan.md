# Plan: Test the whole app, not only the logic (from intent.md and spec.md)

Status: in progress (steps 1 to 6 done, step 7 in review).

## Files that change

New: `Tests/AgentConsumptionTests/` (test support, tests per file). Seams only in `Sources/AgentConsumption/`: `DesktopAuth.swift`, `ClaudeClient.swift`, `CodexClient.swift`, `UsageStore.swift`, `Notifier.swift`, `*+Defaults.swift`. `Package.swift` (test target). `Tests/ConsumptionKitTests/` (more tests). `scripts/check-coverage.py`, `scripts/mutation.py`. Docs: `docs/QUALITY_SCORE.md`, `docs/tech-debt-tracker.md`.

## Order of work

- [x] 1. Add the `AgentConsumptionTests` target and test support (stub session, temp dirs, defaults suite, fixed clock, the guard against real access) (R1, R8, R10).
- [x] 2. Seams for `DesktopAuth`, then its tests (R2).
- [x] 3. Seams for the two clients, then their tests (R3).
- [x] 4. Seams for `UsageStore` and the notifier, then store and persistence tests (R4, R5).
- [x] 5. `ConsumptionKit` gaps: holiday download path, calendar edges, malformed payloads (R6).
- [x] 6. Seeded invariant and no-crash tests (R7).
- [x] 7. Coverage gate for the app target, raise the Kit floors, extend the mutation list, update docs and close TD-3 (R9).

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
- 2026-10-26: `@testable import` of the executable target works on this toolchain (concern 1 in Risks): confirmed in step 1.
- 2026-10-26: Seams added, all defaulting to today's behavior: `DesktopAuth.claudeToken(configFile:secret:)` and `configFile(home:)`, `ClaudeClient.token`, `CodexClient.authFile` and `authFile(environment:home:)`, `Keychain.readPassword(tool:)`, `UsageStore.init(defaults:supportDirectory:holidaySession:fetchers:)`, `AlertDelivering`, `dollars(_:locale:)`.
- 2026-10-26: Tests pin the locale (`en_US`) and time zones: `dollars()` followed the machine's locale (`US$ 1.234` on this Mac), which made a first test machine-dependent (R10).
- 2026-10-26: Bug found by a test: `DesktopAuth.decrypt` accepted ciphertext that is not a whole number of AES blocks and returned garbage instead of throwing. Now throws.
- 2026-10-26: Bug found by a test: `dollars()` rounded halves to even (`$1,234.50` showed `$1,234`). Now rounds half away from zero.
- 2026-10-26: Bug found by a property test: `Day(iso:)` accepted dates that do not exist (`2026-13-45`, `2026-02-30`). Now rejects them, so a bad holiday entry from the API is dropped.
- 2026-10-26: Bug found by the stability run: alert ids included the reset time rounded to the minute, so a reset time that wobbles by seconds (Codex derives it from "seconds left") could repeat an alert already sent. The planner now identifies a window by its first-seen reset time within the 5-minute tolerance it already used for reset detection.
- 2026-10-26: Coverage floors set just under what was reached: `ConsumptionKit` 97% total and 90% per file; the app's logic and views 92% and 80%. `App`, `Notifier`, `PanelPinning` and `LaunchAtLogin` are excluded because they only run in a real app (TD-11). Answers the intent's first open question.
- 2026-10-26: SwiftUI views are tested by headless rendering plus asserting the VoiceOver text, not by pixels: no snapshot dependency. Answers the intent's second open question.
- 2026-10-26: TD-3 is resolved and removed from the tracker.

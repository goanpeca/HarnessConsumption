# Spec: Test the whole app, not only the logic

From: [intent.md](intent.md) (goanpeca). Status: drafted for product owner review.
Skills applied: `credential-handling` (tests must not weaken or bypass it).

## Requirements

- R1. The app target has a test target that imports it, so its logic runs under `swift test` and `make ci`.
- R2. `DesktopAuth` is tested without a real Keychain or config file: decryption of the safeStorage format (known vector and round trip, wrong key, wrong prefix, corrupt data) and choosing the token (skip expired, prefer the longest-lived, none when the cache is empty or malformed).
- R3. `ClaudeClient` and `CodexClient` are tested against a stubbed `URLSession`: request headers, success, 401 and 403 mapped to "open the app", other statuses surfaced with the body, malformed payloads, a missing or unreadable login, and that no token appears in any error text.
- R4. `UsageStore` is tested with injected fetchers, notifier, defaults and holiday store: a successful refresh, a failed refresh keeping the last reading with the error, menu bar title in every state (loading, error, setup, shared, separate), budget pools, setup completion, settings and interval persistence, and that alerts are delivered once.
- R5. The settings persistence helpers round-trip and tolerate corrupt or missing stored data.
- R6. The `ConsumptionKit` gaps are closed: the holiday download path (success, HTTP error, offline, bad JSON, cache hit) against a stubbed session; calendar edges (month and year boundaries, DST zones, single-day windows); parsers on malformed, truncated and unexpected payloads.
- R7. Seeded randomized tests check invariants that example tests can't: pacing shares add up to what remains, budget percentages stay within bounds, and no parser input crashes (it succeeds or throws).
- R8. No test touches real credentials, the network, real defaults or the real support directory; a guard in the test support fails loudly if one tries.
- R9. The coverage gate also measures the app target's logic files with its own floor, the `ConsumptionKit` floors are raised to what is reached, and the mutation list covers the app's decision logic.
- R10. Tests are deterministic: fixed clocks and seeds, no sleeps, and they pass in any order and in parallel.

## Design

Seams, no behavior change: `ClaudeClient` takes a token provider; `CodexClient` takes the auth file location; `UsageStore` takes its fetchers, a notifier protocol, a `UserDefaults` and a support directory, defaulting to today's values; `DesktopAuth` takes the config file and a secret provider. Test support provides a `URLProtocol` stub, temporary directories, an in-memory defaults suite and a fixed clock. Views stay untested except their pure formatting helpers.

## How each constraint in the intent is met

| Constraint | Met by |
| :---- | :---- |
| Never touch real credentials, network, defaults or support dir | R8: injected seams, stubbed session, temp directories, a guard in test support |
| No new dependencies | Swift Testing and `URLProtocol` only (R3, R6) |
| Production behavior unchanged | Seams default to current behavior; the existing suite and `--dump` output stay identical |
| Failing test first | The plan orders each phase test-first |
| Out of scope: snapshots, real notification center | R4 uses a notifier protocol; views excluded from R1 to R10 |

## Open questions from the intent

- App coverage floor: decided from the measured result, recorded in the plan's decision log (concern 1).
- View testing: out of scope here; revisit if views grow logic.

## Areas of concern

1. A floor set too high makes the gate brittle; too low, it lets coverage rot. Owner: goanpeca.
2. Testing `DesktopAuth` means handling real-looking encrypted data; fixtures must be synthetic, never copied from the user's Mac. Policy owner: goanpeca (`credential-handling`).
3. Editing `scripts/check-coverage.py` and `scripts/mutation.py` touches protected paths and needs the owner's approval. Owner: goanpeca.

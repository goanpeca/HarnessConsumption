# Intent: Test the whole app, not only the logic
Author: goanpeca (asked to start 2026-10-26). Status: drafted from the request; awaiting owner acceptance.

## Problem
Only `ConsumptionKit` is tested (94% of its lines, 34 mutants killed). The app target (the Claude and Codex clients, the Desktop token decryption, the store that turns readings into the menu bar and budgets, settings persistence) has no tests at all, so the code that touches the user's logins and decides what number is shown is verified only by hand ([TD-3](../../docs/tech-debt-tracker.md)). Parts of the logic are thin too: the holiday download path, calendar edges and parser robustness.

## Proposed outcome
Every behavior that can be checked without a screen or a live account is checked automatically, and a regression in any of it fails `make ci`. The coverage and mutation gates cover the app's logic as well as the package's.

## Affected users and systems
The maintainer, and anyone changing the clients, the store or the settings. The test suite, `make ci`, the coverage and mutation gates, and (read-only) the real Keychain and the desktop apps' files, which tests must never touch.

## Constraints
- Tests never read the user's real credentials, Keychain items or `~/.codex/auth.json`, never hit the network, and never write to the real `UserDefaults` or Application Support.
- No new dependencies: Swift Testing and the platform only.
- Production behavior does not change; the only edits to app code are seams that make it testable (injected session, file locations, defaults, notifier).
- Failing test first, as in the repo's rules; every check's failure says how to fix it.
- Out of scope: UI snapshot tests, and anything that needs a real notification center or a signed-in desktop app.

## Open questions
- What floor should the app target's coverage gate use once the logic is covered? Owner: goanpeca.
- Are SwiftUI views worth testing beyond their pure helpers, without a snapshot library?

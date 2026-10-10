# AGENTS.md

The map for agents working in this repo. Keep it ~100 lines; detail lives in `docs/`.

## What this is

**Agent Consumption** is a macOS 14+ menu bar app (SwiftUI, Swift 6) that shows how much of your
**Claude** and **Codex** plan limits is left, paced over the work days remaining. Work days follow
settings: country holidays (or none), counted weekdays, check interval. It reuses the logins Claude
Code and Codex already keep on the Mac and reads two **undocumented** endpoints, so it is a
personal tool and must degrade visibly, never silently. Spec:
[menu bar usage](docs/product-specs/menu-bar-usage.md).

## Repo layout

```text
Sources/ConsumptionKit/      Pure logic: models, parsers, calendar, pacing, alerts. Foundation only
Sources/AgentConsumption/    Runtime + UI: clients, Keychain, store, notifier, SwiftUI views
Tests/ConsumptionKitTests/   Swift Testing, runs on any macOS host in seconds
scripts/                     Harness checks (check-*.py/sh), bundler
docs/                        System of record: specs, plans, references, quality
.github/                     CI, security scans, dependabot, scheduled drift scan
Makefile                     Task runner; the source of truth for what each gate runs
```

## Commands

| Command | Does |
|---|---|
| `make bootstrap` | Install the dev tools (SwiftLint, zizmor, gitleaks, actionlint, shellcheck) and git hooks |
| `make test` | Package tests |
| `make coverage` | Tests with coverage; fails below the floor in `scripts/check-coverage.py` |
| `make check` | Harness checks: architecture, docs, file size |
| `make lint` | swift-format (strict) + SwiftLint (strict) |
| `make security` | zizmor, actionlint, shellcheck, gitleaks |
| `make app` / `make run` | Build `build/Agent Consumption.app` / build and launch it |
| `make ci` | Full gate, exactly what CI runs. Must be green before you hand off |

Debug a reading without the UI: `.build/debug/AgentConsumption --dump` (after `make build`).
Logs: `make logs` (subsystem `com.goanpeca.agentconsumption`).

## Golden rules

1. **Layering.** `ConsumptionKit` imports only Foundation; the app depends on it, never the reverse.
   See [ARCHITECTURE.md](ARCHITECTURE.md). Enforced by `scripts/check-architecture.py`.
2. **Parse at the boundary.** Decode API responses in `UsageParsing.swift` into typed values;
   inner code trusts types. Never probe JSON ad hoc.
3. **Never log or print credentials.** Tokens are read and written only in `Keychain.swift` and
   the two clients. See [SECURITY.md](docs/SECURITY.md).
4. **Codex is read-only.** Never refresh or rewrite Codex's token. Claude's rotated token must be
   written back or Claude Code is signed out. See [RELIABILITY.md](docs/RELIABILITY.md).
5. **Failures are visible.** A failed fetch keeps the last reading and shows the error; missing
   holidays show a warning. Never show a stale number as current.
6. **Swift files <= 300 lines.** Split by responsibility.
7. **TDD with Swift Testing.** Failing `@Test` first. No XCTest.
8. **Workflows are pinned and least-privilege.** `make security` (zizmor) must pass.

## Where to look

| Need | Doc |
|---|---|
| Layers, allowed edges, runtime flow, boundaries | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Operating principles | [core-beliefs.md](docs/design-docs/core-beliefs.md) |
| Design docs catalog + status | [design-docs/index.md](docs/design-docs/index.md) |
| Product spec | [menu-bar-usage.md](docs/product-specs/menu-bar-usage.md) |
| Who it is for, priorities | [PRODUCT_SENSE.md](docs/PRODUCT_SENSE.md) |
| Visual and UI conventions | [DESIGN.md](docs/DESIGN.md), [FRONTEND.md](docs/FRONTEND.md) |
| Failure modes, token handling | [RELIABILITY.md](docs/RELIABILITY.md) |
| Threat model, secrets, CI hardening | [SECURITY.md](docs/SECURITY.md) |
| Grades per module and gaps | [QUALITY_SCORE.md](docs/QUALITY_SCORE.md) |
| How exec plans work | [PLANS.md](docs/PLANS.md) |
| Known deferred work | [tech-debt-tracker.md](docs/exec-plans/tech-debt-tracker.md) |
| Endpoint shapes and quirks | [usage-endpoints.md](docs/references/usage-endpoints.md) |
| Why this harness exists | [harness-engineering.md](docs/references/harness-engineering.md) |

## Workflow

- Small change: test first, implement, `make ci`. Multi-step work: an exec plan in
  `docs/exec-plans/active/`, ticked as you go, moved to `completed/` when done.
- Deferring something? Add a row to the tech-debt tracker.
- Code and docs disagree? Fix one of them in the same change; mark design docs `stale` if you can't.
- Stuck or repeating a mistake? Do not try harder: add the missing doc, check or tool, and prefer
  promoting a rule into a script with a remediation message.
- Commits: one line, Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`,
  `chore:`, `ci:`...), under 72 characters, no body, no AI attribution or co-author trailers.

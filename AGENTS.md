# AGENTS.md

The map for agents working in this repo. Keep it ~100 lines; detail lives in `docs/`.

## What this is

**Agent Consumption** is a macOS 14+ menu bar app (SwiftUI, Swift 6) that shows how much of your
**Claude** and **Codex** plan limits is left, paced over the work days remaining. Work days follow
settings: country holidays (or none), counted weekdays, check interval. It reuses the logins the Claude
Desktop and ChatGPT/Codex desktop apps already keep on the Mac and reads two **undocumented** endpoints, so it is a
personal tool and must degrade visibly, never silently. Spec:
[menu bar usage](intent/menu-bar-usage/intent.md).

## Repo layout

```text
Sources/ConsumptionKit/      Pure logic: models, parsers, calendar, pacing, alerts. Foundation only
Sources/AgentConsumption/    Runtime + UI: clients, Keychain, store, notifier, SwiftUI views
Tests/ConsumptionKitTests/   Swift Testing, runs on any macOS host in seconds
scripts/                     Harness checks (check-*.py/sh), bundler
intent/                      One folder per change: intent.md, spec.md, plan.md (humans approve each hand-off)
docs/                        System of record: principles, references, quality, reliability, security
.claude/                     Project settings, hooks (architecture check, protected-path gate), policy skills
.github/                     CI, security scans, dependabot, scheduled drift scan
Makefile                     Task runner; the source of truth for what each gate runs
```

## Commands

| Command | Does |
|---|---|
| `make bootstrap` | Install the dev tools (SwiftLint, zizmor, gitleaks, actionlint, shellcheck) and git hooks |
| `make test` | Package tests |
| `make coverage` | Tests with coverage; fails below the floor in `scripts/check-coverage.py` |
| `make check` | Harness checks: architecture, docs, hook gate, file size, mutation patterns |
| `make mutation` | Mutation testing of `ConsumptionKit` (slow; see [mutation-testing.md](docs/references/mutation-testing.md)) |
| `make lint` | swift-format (strict) + SwiftLint (strict) |
| `make security` | zizmor, actionlint, shellcheck, gitleaks |
| `make app` / `make run` | Build `build/Agent Consumption.app` / build and launch it |
| `make ci` | Full gate, exactly what CI runs. Must be green before you hand off |

Debug a reading without the UI: `.build/debug/AgentConsumption --dump` (after `make build`).
Logs: `make logs` (subsystem `com.goanpeca.agentconsumption`).

## Verifying your work

Run `make ci` before reporting any task complete and paste its result; it is exactly what CI runs
and ends with `app` building and signing `build/Agent Consumption.app`. If a test fails, fix the code,
not the test. Never skip or delete a failing test or a check.

## Merge gate

Posture: **middle** (decided 2026-10-20 by goanpeca, who owns change management here).

- Routine changes under an accepted spec with a green `make ci` can be merged by the agent.
- A human code owner approves anything touching the **protected paths**: `Keychain.swift`,
  `DesktopAuth.swift`, `ClaudeClient.swift`, `CodexClient.swift`, `.github/`, `SECURITY.md`,
  `docs/SECURITY.md`, `.claude/`, `scripts/check-*`. The `protected-paths` hook asks before the editing
  tools touch them; a shell command that rewrites one skips it, so CODEOWNERS and CI are the backstop.
- Never force-push, and never mark an `intent.md`, `spec.md` or `plan.md` approved on a human's behalf.
- Enforcing this on the PR (not only locally) is [TD-10](docs/tech-debt-tracker.md).

## Golden rules

1. **Layering.** `ConsumptionKit` imports only Foundation; the app depends on it, never the reverse.
   See [ARCHITECTURE.md](ARCHITECTURE.md). Enforced by `scripts/check-architecture.py`.
2. **Parse at the boundary.** Decode API responses in `UsageParsing.swift` into typed values;
   inner code trusts types. Never probe JSON ad hoc.
3. **Never log or print credentials.** Tokens are read only in `Keychain.swift`, `DesktopAuth.swift` and
   the two clients. See [SECURITY.md](docs/SECURITY.md).
4. **Desktop apps only, read-only.** Use the Claude Desktop and ChatGPT/Codex desktop logins, never
   the CLIs'. Never refresh or rewrite either token: the desktop apps own rotation. See [RELIABILITY.md](docs/RELIABILITY.md).
5. **Failures are visible.** A failed fetch keeps the last reading and shows the error; missing
   holidays show a warning. Never show a stale number as current.
6. **Swift files <= 300 lines.** Split by responsibility.
7. **TDD with Swift Testing.** Failing `@Test` first. No XCTest.
8. **Workflows are pinned and least-privilege.** `make security` (zizmor) must pass.

## Where to look

| Need | Doc |
|---|---|
| Layers, allowed edges, runtime flow, boundaries | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Operating principles | [core-beliefs.md](docs/core-beliefs.md) |
| Changes: intent, spec, plan | [intent/README.md](intent/README.md) |
| What the app does, requirements | [menu-bar-usage spec](intent/menu-bar-usage/spec.md) |
| Review passes for a PR | [REVIEW.md](REVIEW.md) |
| Who it is for, priorities | [PRODUCT_SENSE.md](docs/PRODUCT_SENSE.md) |
| Visual and UI conventions | [DESIGN.md](docs/DESIGN.md), [FRONTEND.md](docs/FRONTEND.md) |
| Failure modes, token handling | [RELIABILITY.md](docs/RELIABILITY.md) |
| Threat model, secrets, CI hardening | [SECURITY.md](docs/SECURITY.md) |
| Grades per module and gaps | [QUALITY_SCORE.md](docs/QUALITY_SCORE.md) |
| How changes move through the chain | [PLANS.md](docs/PLANS.md) |
| Known deferred work | [tech-debt-tracker.md](docs/tech-debt-tracker.md) |
| Endpoint shapes and quirks | [usage-endpoints.md](docs/references/usage-endpoints.md) |
| Mutation testing, why not Muter | [mutation-testing.md](docs/references/mutation-testing.md) |
| Why this harness exists | [harness-engineering.md](docs/references/harness-engineering.md) |

## Workflow

- Small change: test first, implement, `make ci`. Anything bigger: `intent/<slug>/` with `intent.md`,
  then `spec.md`, then `plan.md` (in plan mode), each approved by a human before the next; see
  [PLANS.md](docs/PLANS.md). Build against the plan's requirement numbers (R1...).
- Deferring something? Add a row to the tech-debt tracker.
- Code and docs disagree? Fix one of them in the same change; update the spec if the requirement moved.
- Same mistake twice? Do not try harder: add the missing doc, check, hook or tool, and prefer
  promoting a rule into a script with a remediation message.
- Commits: one line, Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`,
  `chore:`, `ci:`...), under 72 characters, no body, no AI attribution or co-author trailers.

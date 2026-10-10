# Plans

Plans are versioned artifacts so any agent can pick up work with no outside context.

- **Small change** (one concern, a few files): no plan file. State the intent in the PR.
- **Multi-step work**: an exec plan at `exec-plans/active/YYYY-MM-DD-<slug>.md`.
- **Design choice with trade-offs**: a design doc at `design-docs/YYYY-MM-DD-<slug>.md`,
  listed in [design-docs/index.md](design-docs/index.md) with status and verified date.

## Exec plan shape

1. Header: goal, link to the design doc, link to [ARCHITECTURE.md](../ARCHITECTURE.md).
2. Global constraints the tasks must respect.
3. `## Tasks`: checkboxes, each small enough for one PR, with the tests it needs.
4. `## Decision log`: dated one-line entries for every non-obvious choice or deviation.
   Required; `scripts/check-docs.py` fails without it.

Example: [harness upgrade](exec-plans/completed/2026-10-10-harness-upgrade.md).

## Lifecycle

- Tick tasks and append to the decision log in the same change that does the work.
- Done: move the file to `exec-plans/completed/`; fix links that pointed to it.
- Anything deferred becomes a row in the [tech-debt tracker](exec-plans/tech-debt-tracker.md).
- If a plan reveals the design doc is wrong, update the design doc (or mark it `stale`).

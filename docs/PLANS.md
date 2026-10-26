# Plans

Every change that is more than a small fix leaves committed Markdown that the next stage reads, so any
agent can pick the work up with no outside context. The folder is `intent/<change-slug>/` (kebab-case),
listed in [intent/README.md](../intent/README.md).

| Artifact | Written by | Approved by | When |
|---|---|---|---|
| `intent.md` | Originator and Claude | Product owner | The problem, outcome, constraints and open questions. No design, no file names |
| `spec.md` | Claude, from the intent | Product owner; policy owners for flagged concerns | Numbered requirements (R1, R2...), design, a table showing how each constraint is met, concerns |
| `plan.md` | Claude in plan mode | Engineer (a second look for higher-risk changes) | Files that change, order of work citing R-numbers, risks, proof, and a decision log |

Approvers are all [@goanpeca](https://github.com/goanpeca) today (sole maintainer). Claude never marks
an artifact approved; a human changes the status line.

- **Small change** (one concern, a few files): no folder. State the intent in the PR.
- **Anything bigger or with trade-offs**: start with `intent.md`; follow the chain.

## Plan shape

1. Header: `From: intent.md and spec.md`, status.
2. `## Files that change`, `## Order of work` (checkboxes, each step citing requirement numbers),
   `## Risks`, `## Proof` (the tests or checks that cover each requirement).
3. `## Decision log`: dated one-line entries for every non-obvious choice or deviation.

Example: [harness upgrade](../intent/harness-upgrade/plan.md).

## Lifecycle

- Tick steps and append to the decision log in the same change that does the work.
- When implementation departs from the plan, update `plan.md` in the same commit.
- Anything deferred becomes a row in the [tech-debt tracker](tech-debt-tracker.md); a row that matters
  becomes a new `intent.md`.
- If a plan reveals the spec is wrong, fix the spec and note it in the decision log.
- Incidents and breached reliability bands become a new `intent.md` (see [RELIABILITY.md](RELIABILITY.md)).

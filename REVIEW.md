# Review

> TODO (owner: goanpeca): this is a stub drafted from the repo's own rules. Edit it until it matches
> how you want PRs reviewed, then remove this note.

Run these passes on every PR, in order. Each cites the file that defines the rule; report findings
with file and line, and say plainly when a pass found nothing.

1. **Spec match.** Does the diff satisfy the requirements (R-numbers) of the change's `spec.md`, and
   does `plan.md` still match what was built? Flag requirements the diff doesn't cover and code the
   spec doesn't ask for. Small fixes with no `intent/` folder: check the PR description instead.
2. **Credentials.** Apply the `credential-handling` skill: only the desktop logins, read-only, nothing
   logged or sent to a new host. Any diff touching a protected path (see `AGENTS.md`, "Merge gate")
   needs a human code-owner approval.
3. **Architecture.** `ConsumptionKit` stays Foundation-only; UI and Keychain code stay in
   `AgentConsumption` ([ARCHITECTURE.md](ARCHITECTURE.md)); parse at the boundary.
4. **Tests.** A failing test came first; behavior with a boundary or a constant has a test that fails
   if it changes. New logic gets mutants in `scripts/mutation.py`.
5. **Accessibility and UI.** Color is never the only signal; VoiceOver reads each row
   ([docs/DESIGN.md](docs/DESIGN.md)).
6. **Docs and context.** `AGENTS.md`, `docs/` and the spec are updated in the same change; flag edits
   that make `AGENTS.md` or a skill outdated.
7. **Gate.** `make ci` is green and quoted in the PR. Never accept "skipped" or a deleted check.

# Core beliefs

Agent-first operating principles for this repo. Short on purpose.

1. **Humans steer, agents execute.** When an agent struggles, add the missing doc, check or tool;
   never "try harder".
2. **The repo is the system of record.** If an agent can't read it in-repo, it doesn't exist.
   [AGENTS.md](../AGENTS.md) is a map; detail lives in `docs/`.
3. **Enforce invariants, not implementations.** Layers, boundaries and taste rules are scripts whose
   error messages say how to fix the violation.
4. **When docs fall short, promote the rule into code.**
5. **Parse at the boundary.** Undocumented endpoints change; decode once into types and fail loudly.
6. **Failures are visible.** A wrong number shown as right is worse than an error banner.
7. **Never risk the user's logins.** Claude Code and Codex stay signed in; credentials never reach
   logs, URLs or notifications.
8. **Boring tech.** Foundation, SwiftUI, `URLSession`. No dependencies unless one removes real risk.
9. **Small PRs, fast gates, continuous cleanup.** Pay tech debt down in small increments; the weekly
   drift scan keeps docs and gates honest.
10. **Concise docs.** Context is scarce. Say it once, link instead of repeating.

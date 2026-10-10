# Tech-debt tracker

Log every deferral here so it surfaces instead of rotting.

| ID | Item | Severity | Added |
|---|---|---|---|
| TD-1 | CodeQL and dependency review need GitHub Advanced Security on private repos; enable if the repo goes public or GHAS is bought | low | 2026-10-10 |
| TD-2 | Branch protection (required `CI` and `Security` checks, no force-push) is a repo setting, not code; set it in GitHub | medium | 2026-10-10 |
| TD-3 | Client code (`ClaudeClient`, `CodexClient`, `Keychain`) has no tests; needs an injectable `URLSession` and credential source | medium | 2026-10-10 |
| TD-4 | Regional holidays and personal days off are not supported | low | 2026-10-10 |
| TD-5 | App is ad-hoc signed; no notarization, so it isn't distributable | low | 2026-10-10 |
| TD-6 | No iOS widget yet; `ConsumptionKit` is ready to be reused | low | 2026-10-10 |

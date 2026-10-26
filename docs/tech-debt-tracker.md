# Tech-debt tracker

Log every deferral here so it surfaces instead of rotting.

| ID | Item | Severity | Owner | Added |
|---|---|---|---|---|
| TD-1 | CodeQL and dependency review need GitHub Advanced Security on private repos; enable if the repo goes public or GHAS is bought | low | goanpeca | 2026-10-10 |
| TD-2 | Branch protection (required `CI` and `Security` checks, no force-push) is a repo setting, not code; set it in GitHub | medium | goanpeca | 2026-10-10 |
| TD-4 | Regional holidays and personal days off are not supported | low | goanpeca | 2026-10-10 |
| TD-5 | App is ad-hoc signed; no notarization, so it isn't distributable | low | goanpeca | 2026-10-10 |
| TD-6 | No iOS widget yet; `ConsumptionKit` is ready to be reused | low | goanpeca | 2026-10-10 |
| TD-7 | TODO (owner to decide): config evals, regression tests for `AGENTS.md`, the policy skill and the hooks (playbook `sdlc-evals`); none exist yet | medium | goanpeca | 2026-10-20 |
| TD-8 | TODO (owner to decide): managed settings and sandbox for Claude Code on this repo; today only project `.claude/settings.json` hooks apply | low | goanpeca | 2026-10-20 |
| TD-9 | TODO (owner to decide): baseline the per-play indicators in [QUALITY_SCORE.md](QUALITY_SCORE.md#process-indicators) from git history | low | goanpeca | 2026-10-20 |
| TD-10 | The middle merge-gate posture needs protected paths enforced on the PR (a ruleset requiring code-owner review for them); CODEOWNERS alone covers everything or nothing. Same GitHub setting as TD-2 | medium | goanpeca | 2026-10-20 |
| TD-11 | `App`, `Notifier`, `PanelPinning` and `LaunchAtLogin` are untested because they need a real app (UserNotifications, an `NSWindow`, `SMAppService`); put each behind a small protocol with a fake, or test them in a UI run | low | goanpeca | 2026-10-26 |

# Spec: Menu bar view of Claude and Codex usage

From: [intent.md](intent.md) (goanpeca). Status: migrated from the harness layout (was `docs/design-docs/2026-10-10-menu-bar-usage-design.md` and `docs/product-specs/menu-bar-usage.md`); awaiting product owner review. Design verified against the code 2026-10-10 (D1 to D9); requirements R7 to R11 added since and verified by tests.
Skills applied: `credential-handling`.

## Requirements

- R1. The menu bar shows the weekly quota left for Claude and Codex (`✳︎ 94%  ◎ 100%`); `–` while loading, `?` after a failed or incomplete check; plans without weekly windows show the monthly limit instead.
- R2. When Claude and Codex share one budget (Settings), the menu bar shows one percentage of that pool left (`◔ 62%`, `?` when a provider's spend is missing or stale). When each has its own budget it shows `✳︎ 62%  ◎ 96%`, each against its own. A budget of 0 hides that budget.
- R3. The usage tab opens with a Shared budget card (or one card per provider): percent left, a bar with an even-pace tick, dollars left, dollars per work day. Each provider also shows what it spent and its share of the pool. Claude reports dollars; Codex reports credits, converted as `used / limit x "Codex limit is worth (USD)"`.
- R4. Per provider the usage tab shows the plan, then each window (5-hour, weekly, monthly) with a bar, percent left, reset time and a status symbol and word. Weekly and monthly rows add "Today: X% · N days left".
- R5. A month section shows work days left, quota left this month in weeks, the per-day share and the active day rules.
- R6. Errors appear inline in orange with the fix (for example "open Claude Desktop"); a failed fetch keeps the last reading. Footer: updated time, Refresh, Quit.
- R7. Settings: country (any Nager.Date supports, or none), treat public holidays as days off (off when no country), days that count (Mon to Sun, default Mon to Fri, at least one stays on), check interval (5, 15, 30 minutes, 1 or 2 hours; default 1 hour), shared or separate budgets and their amounts, open at login. Reset to defaults: Mon to Fri, the Mac's region as the country, holidays off, hourly.
- R8. First launch assumes no country: a Setup screen replaces the tabs, the menu bar reads "Set up", it suggests the Mac's region (or none), and Continue confirms it. Settings saved by earlier versions count as confirmed.
- R9. Each notification fires once per condition: over the weekly pace; a limit under 10% left; a limit reset (a 5-hour reset only when the last window was at least half used); a morning summary on counted days after 08:00.
- R10. Only the Claude Desktop and ChatGPT/Codex desktop logins are used, read-only; no token is refreshed, rewritten, logged or sent anywhere except the two usage endpoints.
- R11. Color is never the only signal: each level has its own symbol and a status word, the bar has an even-pace tick, and each usage row is one VoiceOver element with a spoken summary.

## Design

### Decisions

| # | Decision | Why |
|---|---|---|
| D1 | macOS menu bar app, not an iOS widget | iOS has no menu bar widget; the Mac already holds both logins. Logic is a separate package so an iOS widget can reuse it |
| D2 | Reuse the Claude Desktop and ChatGPT/Codex desktop logins (never the CLIs') | No login UI to build, Google sign-in already done there. Only subscription quota is exposed through these tokens |
| D3 | Both read-only, never refresh | The desktop apps own rotation; refreshing here could sign them out. A stale token shows "open the app" |
| D4 | Keychain via `/usr/bin/security`; Desktop token decrypted with `Claude Safe Storage` | Electron safeStorage; approval attaches to the system tool, so rebuilding this ad-hoc-signed app doesn't re-prompt |
| D5 | Holidays from Nager.Date, cached per country and year | No mature Swift holiday library; the API covers ~100 countries and the cache makes it work offline |
| D6 | `WorkSettings`: weekdays, country or none, skip-holidays | Covers "weekends only", "Saturdays but not Sundays or holidays", and everything between |
| D7 | Pacing per weekly window plus a month outlook | Limits reset weekly, but the month is how the user plans |
| D8 | Fixed-height tabbed panel, top pinned under the menu bar | macOS keeps a window's bottom edge on resize, which detached the panel from the bar |
| D9 | Alerts decided in the package, delivered by the app | The decision logic is testable without notifications |

### Pacing

- Weekly: `remaining% ÷ counted days from today to the reset day` = today's share. Over pace when
  used% exceeds the even-pace target for the end of today.
- Month: quota still available before month end (current window plus the in-month fraction of each
  upcoming window) ÷ counted days left.

Endpoint shapes: [usage-endpoints.md](../../docs/references/usage-endpoints.md).

## How each constraint in the intent is met

| Constraint | Met by |
| :---- | :---- |
| Never risk the user's logins | R10, D2, D3, D4 |
| Credentials never reach logs, URLs or notifications | R10; `scripts/check-architecture.py` flags log lines that mention tokens |
| Failures are visible, never a stale number shown as current | R1, R6 |
| Endpoints are undocumented, so parse at the boundary | `UsageParsing.swift` decodes into typed values; unparsable responses are failed fetches (R6); concern 1 |
| No new runtime dependencies | D1; Foundation, SwiftUI and `URLSession` only |
| Works anywhere, no assumed country | R7, R8 |
| Out of scope: regional or personal days off, API-key usage, iOS widget, App Store distribution | Not specified here; tracked as TD-4, TD-5, TD-6 in [the tech-debt tracker](../../docs/tech-debt-tracker.md) |

## Open questions from the intent

- Do the undocumented endpoints stay stable? Carried forward as concern 1.
- What is a Codex credit worth in dollars? Answered by the setting in R3; carried forward as concern 2.
- When does Claude's monthly spend limit reset? The payload has no date; assumed the 1st, UTC (concern 3).

## Areas of concern

1. The Claude and Codex usage endpoints are undocumented and may change without notice. Owner: goanpeca.
2. Codex reports credits, so the dollar total depends on the user's "Codex limit is worth" setting being right. Owner: goanpeca.
3. Claude's monthly reset date is assumed to be the 1st, UTC. Owner: goanpeca.
4. Reading Claude Desktop's token needs the `Claude Safe Storage` Keychain key, which decrypts everything Desktop seals; the prompt should be approved once, not "Always Allow". Policy owner: goanpeca (see [SECURITY.md](../../docs/SECURITY.md)).

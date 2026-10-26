# Menu bar usage

## Goal

See at a glance how much of the Claude and Codex plan limits is left, and how much to use today so
the quota lasts through the remaining work days.

## Menu bar

`✳︎ 94%  ◎ 100%`: weekly quota left for Claude and Codex. `–` while loading, `?` after a failed check.

## Usage tab

Shared budget: when both providers draw from one dollar pool (Settings > Shared budget, default
$4,000 per month), the menu bar shows a single `◔ 62%` (percent of that pool left, `?` when a
provider's spend is missing or stale) and the panel opens with a Shared budget card: percent left,
a bar with the even-pace tick, dollars left, dollars per work day. Each provider also shows what it
spent and its share of the pool. Claude reports dollars; Codex reports credits, converted as
`used / limit x "Codex limit is worth (USD)"`. Budget 0 turns it off and the menu bar goes back to
one percentage per provider.

Per provider: plan, then each window (5-hour, weekly) with a bar, percent left, reset time.
Weekly rows add "Today: X% · N days left" (orange when over pace). A month section shows days left,
quota left this month in weeks, per-day share, and the active day rules. Errors appear inline in
orange with the fix (for example "open Claude Desktop"). Footer: updated time, Refresh, Quit.

## Settings tab

- **Country**: any country Nager.Date supports, or none (no holidays).
- **Treat public holidays as days off**: off when no country.
- **Days that count**: Mon–Sun toggles (default Mon–Fri); at least one stays on.
- **Check usage**: every 5, 15, 30 minutes, 1 or 2 hours (default 1 hour).
- **Reset to defaults**: Mon–Fri, Colombia, holidays off days, hourly.

Defaults: Colombia, Mon–Fri, holidays skipped, hourly.

## Notifications

Each fires once per condition: over the weekly pace; a limit under 10% left; a limit reset (a
5-hour reset only when the last window was at least half used); a morning summary on counted days
after 08:00.

## Out of scope

Regional or personal days off, API-key (pay-as-you-go) usage, iOS widget (the logic is reusable),
App Store distribution.

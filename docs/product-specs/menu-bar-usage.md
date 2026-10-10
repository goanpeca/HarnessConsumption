# Menu bar usage

## Goal

See at a glance how much of the Claude and Codex plan limits is left, and how much to use today so
the quota lasts through the remaining work days.

## Menu bar

`✳︎ 94%  ◎ 100%`: weekly quota left for Claude and Codex. `–` while loading, `?` after a failed check.

## Usage tab

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

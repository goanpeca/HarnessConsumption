# Agent Consumption

[![CI](https://github.com/goanpeca/HarnessConsumption/actions/workflows/ci.yml/badge.svg)](https://github.com/goanpeca/HarnessConsumption/actions/workflows/ci.yml)
[![Security](https://github.com/goanpeca/HarnessConsumption/actions/workflows/security.yml/badge.svg)](https://github.com/goanpeca/HarnessConsumption/actions/workflows/security.yml)
[![Mutation testing](https://github.com/goanpeca/HarnessConsumption/actions/workflows/mutation.yml/badge.svg)](https://github.com/goanpeca/HarnessConsumption/actions/workflows/mutation.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey.svg)

A macOS menu bar app that shows how much of your **Claude** and **Codex** plan limits is left, paced
over the work days that remain in the period. You choose the country whose public holidays count as
days off, and which weekdays you work.

```
◔ 62%        ← one budget shared by Claude and Codex (or ✳︎ 62%  ◎ 96% when each has its own)
```

Click it for each budget and limit, reset times, what you can use per work day, and the month outlook.
It checks every hour by default (5 minutes to 2 hours in Settings) and notifies when you're over pace,
a limit is almost used up (<10%), a limit resets, and with a morning summary on work days (after
08:00 local time).

## First launch

Nothing is assumed about where you are. The first time you open it, a Setup screen asks you to
confirm the country (it suggests your Mac's region) whose public holidays are days off, or none to
count weekdays only. Until you continue, the menu bar reads "Set up". Change it later in Settings.

## Run

```bash
make run        # build build/Agent Consumption.app and launch it
make install    # copy to /Applications (then turn on "Open at login" in Settings)
make bootstrap  # install dev tools and git hooks (once)
make test       # logic tests
make mutation   # mutation testing of the logic (slow; see below)
make lint       # swift-format + SwiftLint, both strict
make security   # zizmor, actionlint, shellcheck, gitleaks
make ci         # everything GitHub Actions runs; the pre-push hook runs it too
.build/debug/AgentConsumption --dump   # print the current readings and exit (after `make build`)
```

## How it gets the data

No separate login: it reuses the Claude Desktop and ChatGPT/Codex desktop app sessions on this Mac.
The CLIs' logins are not used.

| Provider | Credentials | Endpoint |
|---|---|---|
| Claude | Claude Desktop's `config.json` token cache, decrypted with the `Claude Safe Storage` Keychain key (one-time prompt) | `api.anthropic.com/api/oauth/usage` |
| Codex | `~/.codex/auth.json` (the ChatGPT/Codex desktop app's login) | `chatgpt.com/backend-api/wham/usage` |

Both endpoints are **undocumented** (they back Claude Code's `/usage` and Codex's `/status`) and may
change, so treat the readings as best effort. The app shows an error and keeps the last reading when
a fetch fails rather than presenting a stale number as current.

- **Both read-only.** The desktop apps own token refresh. If a token has expired, open the app and
  press Refresh.
- Enterprise and business plans report a monthly spend limit instead of 5-hour/weekly windows; it
  shows as "Monthly" (Claude's reset is assumed to be the 1st, UTC).

## Budgets

If Claude and Codex draw from one dollar pool, turn on **Claude and Codex share one budget** in
Settings and enter the monthly amount: the menu bar shows one percentage and the panel opens with a
Shared budget card (percent left, dollars left, dollars per work day). If each has its own budget,
turn it off and set one per provider. Claude reports dollars; Codex reports credits, so Settings
asks what its limit is worth in dollars.

## Pacing

- **Work days:** the weekdays you choose minus your country's public holidays from
  [Nager.Date](https://date.nager.at), cached per year in
  `~/Library/Application Support/AgentConsumption/`.
- **Weekly:** remaining % ÷ work days from today until the reset day = today's share. Over pace means
  used % is above the even-pace target for the end of today.
- **Month:** weekly quota still available before month end (current window plus the in-month part
  of each upcoming window), ÷ work days left in the month.
- **Colors:** green at or under the even pace, orange slightly over, red well over or nearly out.
  Each level also has its own symbol and a status word, so color is never the only signal.

Layout: `Sources/ConsumptionKit` is pure logic (tested, reusable for an iOS widget later);
`Sources/AgentConsumption` is the app (clients, Keychain, SwiftUI `MenuBarExtra`, notifications).

## Settings

The **Settings** tab sets the country (or none), whether public holidays are days off, which weekdays
count, the budget, whether the app opens at login, and how often usage is checked. They apply to
today's share, the over-pace check, the month outlook and the morning summary.

## Testing

`ConsumptionKit` is covered by Swift Testing tests with a coverage floor, and by mutation testing:
`make mutation` changes the logic one small step at a time (a flipped comparison, a shifted
constant) and requires a test to fail for each change. The mutation workflow runs on logic changes
and weekly. Why this runner and not Muter: [mutation-testing.md](docs/references/mutation-testing.md).

## Development

Start at [AGENTS.md](AGENTS.md): layout, commands, rules, and where each doc lives. CI is hardened
(least-privilege tokens, SHA-pinned actions, zizmor, gitleaks); details in
[docs/SECURITY.md](docs/SECURITY.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 Gonzalo Peña-Castellanos

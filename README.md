# Agent Consumption

macOS menu bar app showing how much of your **Claude** and **Codex** plan limits is left, paced over
the **Colombian work days** remaining.

```
✳︎ 94%  ◎ 100%        ← weekly quota left: Claude · Codex
```

Click it for the 5-hour and weekly windows, reset times, today's share, and the month outlook.
It checks every hour and notifies when you're over pace, a limit is almost used up (<10%), a limit
resets, and with a morning summary on work days (after 08:00 Bogotá).

## Run

```bash
make run        # build build/Agent Consumption.app and launch it
make install    # copy to /Applications (add it to Login Items to start at login)
make test       # logic tests
make lint       # swift-format lint (strict)
make ci         # lint + tests + app bundle, exactly what GitHub Actions runs
.build/debug/AgentConsumption --dump   # print the current readings and exit (after `make build`)
```

## How it gets the data

No separate login: it reuses the sessions already on this Mac.

| Provider | Credentials | Endpoint |
|---|---|---|
| Claude | Claude Code's Keychain item `Claude Code-credentials` | `api.anthropic.com/api/oauth/usage` |
| Codex | `~/.codex/auth.json` (ChatGPT login) | `chatgpt.com/backend-api/wham/usage` |

Both endpoints are **undocumented** (they back Claude Code's `/usage` and Codex's `/status`) and may
change. This is a personal tool, not something to distribute.

- **Claude:** access tokens expire after a few hours and Claude Code only refreshes them while it
  runs, so the app refreshes an expired token and writes the new tokens back to the same Keychain
  item. If that write ever fails, run `claude` and `/login`.
- **Codex:** read-only. If the token expires, run `codex` once.

## Pacing

- **Work days:** Monday–Friday minus Colombian public holidays from
  [Nager.Date](https://date.nager.at), cached per year in
  `~/Library/Application Support/AgentConsumption/`.
- **Weekly:** remaining % ÷ work days from today until the reset day = today's share. Over pace means
  used % is above the even-pace target for the end of today.
- **Month:** weekly quota still available before month end (current window plus the in-month part
  of each upcoming window), ÷ work days left in the month.

Layout: `Sources/ConsumptionKit` is pure logic (tested, reusable for an iOS widget later);
`Sources/AgentConsumption` is the app (clients, Keychain, SwiftUI `MenuBarExtra`, notifications).

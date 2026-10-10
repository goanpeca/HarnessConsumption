# Architecture

Top-level map. Enforced by `scripts/check-architecture.py`; change this file and `LAYERS` there
together.

## Layers

Dependencies point downward only.

| Layer | Module | May import | Holds |
|---|---|---|---|
| Logic | `ConsumptionKit` | Foundation | Models, response parsers, `WorkCalendar`, `WorkSettings`, pacing, `AlertPlanner`, `HolidayStore`, `RefreshInterval` |
| Runtime and UI | `AgentConsumption` | `ConsumptionKit`, Foundation, Observation, os, UserNotifications; SwiftUI/AppKit in view files only | Keychain, Claude/Codex clients, `UsageStore`, `Notifier`, views |

`ConsumptionKit` has no UI, logging, Keychain or notification code, so its tests run on any host.
It returns plain values (`UsageAlert`, `WindowPace`, `MonthOutlook`) that the app presents.

## Boundaries

Each rule exists because a mistake there is costly. Enforced mechanically.

- **Credentials** are touched only in `Keychain.swift` (via `/usr/bin/security`, so Claude Code's
  Keychain access list applies) and read by `ClaudeClient` / `CodexClient`.
- **Notifications** go through `Notifier.swift` only; the planner decides, the notifier delivers.
- **UI frameworks** (SwiftUI, AppKit) appear only in `*View.swift`, `App.swift`, `PanelPinning.swift`.
- **No secrets in logs**, no `print` outside `App.swift` (`--dump`).

## Runtime flow

```text
Timer (RefreshInterval) ─▶ UsageStore.refresh
   ├─ HolidayStore ─▶ WorkSettings.calendar ─▶ WorkCalendar
   ├─ ClaudeClient (Keychain, refresh + write back) ─▶ ClaudeUsageParser ─┐
   ├─ CodexClient  (auth.json, read-only)           ─▶ CodexUsageParser  ─┼▶ ProviderUsage
   └─ AlertPlanner(usages, calendar, AlertState) ─▶ [UsageAlert] ─▶ Notifier
MenuView ◀─ UsageStore (WindowPace, MonthOutlook per provider)
```

## Invariants

- Day arithmetic happens in one `Calendar` (the Mac's time zone); a window covers
  `[start day, reset day)`.
- A fetch failure keeps the last reading and sets an error; the UI marks it.
- `AlertState` makes every alert fire once per condition (ids include reset time or day).
- The panel's size is fixed, and its top is pinned below the menu bar (see
  [FRONTEND.md](docs/FRONTEND.md)).

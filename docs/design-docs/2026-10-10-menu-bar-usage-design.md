# Menu bar usage: design

Status and verification: see [index](index.md). Product intent: [spec](../product-specs/menu-bar-usage.md).

## Decisions

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

## Pacing

- Weekly: `remaining% ÷ counted days from today to the reset day` = today's share. Over pace when
  used% exceeds the even-pace target for the end of today.
- Month: quota still available before month end (current window plus the in-month fraction of each
  upcoming window) ÷ counted days left.

Endpoint shapes: [usage-endpoints.md](../references/usage-endpoints.md).

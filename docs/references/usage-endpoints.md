# Usage endpoints

Both are **undocumented**: they back Claude Code's `/usage` and Codex's `/status`. Verified
2026-10-10. If one breaks, fix the parser in `UsageParsing.swift` and add the new payload as a test.

## Claude

`GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <accessToken>` and
`anthropic-beta: oauth-2025-04-20`.

```json
{"five_hour": {"utilization": 37.0, "resets_at": "2026-10-07T18:00:00.123456+00:00"},
 "seven_day": {"utilization": 62.5, "resets_at": "2026-10-10T03:00:00Z"}}
```

`utilization` is percent used; `resets_at` is null while a window is idle. Credentials: Keychain
item `Claude Code-credentials`, JSON `claudeAiOauth.{accessToken, refreshToken, expiresAt (ms),
subscriptionType}`. Refresh: `POST` JSON `{grant_type: refresh_token, refresh_token, client_id}` to
`console.anthropic.com/v1/oauth/token` (fallback `platform.claude.com`).

## Codex

`GET https://chatgpt.com/backend-api/wham/usage` with `Authorization: Bearer <access_token>` and
`chatgpt-account-id`. Credentials: `~/.codex/auth.json` → `tokens.{access_token, account_id}`.

```json
{"plan_type": "pro", "rate_limit": {
  "primary_window": {"used_percent": 12, "limit_window_seconds": 604800,
                     "reset_at": 1791985929, "reset_after_seconds": 602641},
  "secondary_window": null}}
```

A window longer than a day is "weekly", otherwise "5-hour".

## Holidays

`GET https://date.nager.at/api/v3/PublicHolidays/{year}/{CC}` and `/api/v3/AvailableCountries`
(public, no key). National holidays only.

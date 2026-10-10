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

`utilization` is percent used; `resets_at` is null while a window is idle. Enterprise returns both
as null plus `extra_usage.{is_enabled, utilization, monthly_limit, used_credits}`, a monthly spend
limit with no reset date (treated as the 1st, UTC).

Credentials: Claude Desktop's `~/Library/Application Support/Claude/config.json`, key
`oauth:tokenCacheV2`: base64 of `v10` + AES-128-CBC (PBKDF2-SHA1, salt `saltysalt`, 1003 rounds, IV
16 spaces; password is the `Claude Safe Storage` Keychain item). It decrypts to a map of entries
`{token, expiresAt (ms), subscriptionType, ...}`. Never refreshed here.

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

Some plans (seen on enterprise) return `"rate_limit": null` and report a monthly spend limit instead:
`spend_control.individual_limit.{used_percent, reset_at, reset_after_seconds}`. It shows as a
"Monthly" window with no pacing.

## Holidays

`GET https://date.nager.at/api/v3/PublicHolidays/{year}/{CC}` and `/api/v3/AvailableCountries`
(public, no key). National holidays only.

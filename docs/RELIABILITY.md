# Reliability

The risk is not a missed number; it is breaking the user's Claude Code or Codex login.

| Situation | Behavior |
|---|---|
| Claude access token expired | Refresh with the stored refresh token, then **write the rotated pair back** to the same Keychain item. If the write fails, show "run `claude` and /login": the old refresh token is spent |
| Claude refresh rejected (400/401) | Stop; do not try other hosts. Show the sign-in message |
| Codex token expired (401/403) | Show "run `codex` once". Never refresh it: rotating it could sign Codex out |
| Endpoint changed or unreachable | Keep the last reading, mark it with the error, menu bar shows `?` |
| Holidays can't load | Warn in the UI; days are counted without holidays |
| Unparsable response | `UsageParseError`; treated as a failed fetch, never partial data |
| Alerts | Ids make each fire once; state is persisted so a relaunch doesn't repeat them |

Checks run on a timer ([RefreshInterval](../Sources/ConsumptionKit/RefreshInterval.swift), min 5
minutes) to stay gentle on undocumented endpoints. Every fetch outcome is logged without secrets
(`make logs`).

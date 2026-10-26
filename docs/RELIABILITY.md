# Reliability

The risk is not a missed number; it is breaking the user's Claude Desktop or Codex login.

| Situation | Behavior |
|---|---|
| Claude token expired or rejected (401/403) | Show "open Claude Desktop". Never refresh it: Desktop owns rotation and rotating it could sign Desktop out |
| Keychain read of `Claude Safe Storage` denied | Show the error inline; nothing is cached |
| Codex token expired (401/403) | Show "open the ChatGPT/Codex desktop app". Never refresh it: rotating it could sign Codex out |
| Endpoint changed or unreachable | Keep the last reading, mark it with the error, menu bar shows `?` |
| Holidays can't load | Warn in the UI; days are counted without holidays |
| Unparsable response | `UsageParseError`; treated as a failed fetch, never partial data |
| Alerts | Ids make each fire once; state is persisted so a relaunch doesn't repeat them |

Checks run on a timer ([RefreshInterval](../Sources/ConsumptionKit/RefreshInterval.swift), min 5
minutes) to stay gentle on undocumented endpoints. Every fetch outcome is logged without secrets
(`make logs`).

## Control bands

The weekly [drift scan](../.github/workflows/drift.yml) is this repo's control band: docs, layering and file
sizes must match the code, and a breach opens one issue. A breach, a failed release or a wrong reading
in the field becomes a new `intent/<slug>/intent.md` (see [PLANS.md](PLANS.md)), written by the agent
that found it and reviewed by the owner.


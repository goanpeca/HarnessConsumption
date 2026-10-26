# Intent: Menu bar view of Claude and Codex usage
Author: goanpeca. Status: migrated from `docs/product-specs/menu-bar-usage.md`; awaiting product owner acceptance.

## Problem
The Claude and Codex plan limits (5-hour, weekly, and on business and enterprise plans a monthly spend limit) are only visible by opening each app. There is no quick way to tell how much to use today so the quota lasts through the remaining work days, or, when both providers draw from one dollar budget, how much of that budget is left.

## Proposed outcome
See at a glance, from the macOS menu bar, how much of the Claude and Codex plan limits is left, and how much to use today so the quota lasts through the remaining work days.

## Affected users and systems
A person with Claude and Codex plans on a Mac. The Claude Desktop and ChatGPT/Codex desktop apps (their logins), two undocumented usage endpoints, and Nager.Date for public holidays.

## Constraints
- Never risk the user's logins: read-only use of the desktop apps' sessions, no token refreshed or rewritten, credentials never reach logs, URLs or notifications.
- Failures are visible: a failed fetch keeps the last reading and shows the error; a stale number is never shown as current.
- The endpoints are undocumented and may change, so responses are parsed once at the boundary into typed values.
- Boring tech: no runtime dependencies beyond the platform.
- Works for anyone: nothing assumes a country; holidays and counted weekdays are the user's choice.
- Out of scope: regional or personal days off, API-key (pay-as-you-go) usage, an iOS widget (the logic is reusable), App Store distribution.

## Open questions
- Will the undocumented endpoints stay stable? Nobody outside Anthropic and OpenAI knows.
- What is a Codex credit worth in dollars, for a budget shared with Claude?
- When does Claude's monthly spend limit reset?

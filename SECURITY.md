# Security policy

Agent Consumption is an open-source project (MIT licensed) maintained on a best-effort basis. Security
reports are taken seriously because the app handles login tokens.

## Supported versions

Only the latest commit on `main` is supported. There are no release branches.

## Reporting a vulnerability

Please report privately, not in a public issue or pull request:

- Email **goanpeca@gmail.com** with "Agent Consumption security" in the subject, or
- Open a private security advisory on GitHub (Security → Report a vulnerability).

Include what you found, how to reproduce it, and what you think the impact is. Do not include real
tokens or credentials in a report; redact them.

You can expect an acknowledgement within a few days and a fix or a decision on a best-effort basis.
Please give me a reasonable chance to fix the problem before disclosing it publicly.

## What is in scope

- Anything that exposes, logs, sends elsewhere, or modifies the Claude or Codex login tokens the app
  reads (Claude Desktop's token cache, `~/.codex/auth.json`, the `Claude Safe Storage` Keychain item).
- Requests to hosts other than the ones documented in [docs/SECURITY.md](docs/SECURITY.md).
- Weaknesses in the CI workflows that could leak secrets or run untrusted code.

## What is out of scope

- The undocumented usage endpoints themselves changing or being rate limited.
- Issues that need an attacker who already controls your Mac account or has read your Keychain.

How credentials, logs and CI are handled: [docs/SECURITY.md](docs/SECURITY.md).

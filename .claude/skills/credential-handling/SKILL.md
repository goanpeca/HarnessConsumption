---
name: credential-handling
description: Rules for any code that touches the Claude or Codex login tokens in this repo (Keychain, Claude Desktop's token cache, ~/.codex/auth.json, the usage clients, logging, notifications). Use when editing Keychain.swift, DesktopAuth.swift, ClaudeClient.swift, CodexClient.swift, UsageStore logging, or when asked to add a provider, refresh a token, log a request, or send data to a new host.
---

# Credential handling

Policy owner: goanpeca. Sources of truth: [docs/SECURITY.md](../../../docs/SECURITY.md) and golden rules 3 and 4 in [AGENTS.md](../../../AGENTS.md). The app reads the user's real logins, so a mistake can sign them out or leak a token.

## Rules

1. Only the desktop apps' logins are used: Claude Desktop's token cache and the ChatGPT/Codex desktop app's `~/.codex/auth.json`. Never the CLIs' (`Claude Code-credentials`, `codex login`). (AGENTS rule 4, docs/SECURITY.md "Credentials")
2. Read-only. Never refresh, rotate, write back or delete either token; the desktop apps own rotation. If a token is expired, show "open the app" and keep the last reading. (AGENTS rule 4, docs/RELIABILITY.md)
3. Tokens are read only in `Keychain.swift`, `DesktopAuth.swift` and the two clients, and held in memory only for a request. (AGENTS rule 3)
4. Never log, print, put in a URL, a notification, an error message or a crash message: not a token, not an `Authorization` header, not a decrypted cache. Log the status code or host instead. (docs/SECURITY.md)
5. Requests go only to `api.anthropic.com`, `chatgpt.com` and `date.nager.at` (a country code and a year, nothing else). A new host needs a change to docs/SECURITY.md approved by the owner first.
6. Approve the `Claude Safe Storage` Keychain prompt once, never "Always Allow": that key decrypts everything Claude Desktop seals. Do not cache the key or the decrypted token on disk. (docs/SECURITY.md)
7. Country codes are validated (`^[A-Z]{2}$`) before they reach a file name or URL.

## Before you finish

- Run `python3 scripts/check-architecture.py` and `make ci`; quote the result in your summary. The same check runs as a hook after each edit and as a required CI check.
- If the change needs a rule above to bend, stop and ask the owner. Do not decide it yourself.
- Update `docs/SECURITY.md` in the same change when what is read, where it goes or who may read it changes.

## Backstops

Advisory: this skill. Deterministic: `scripts/check-architecture.py` (layers, who may touch the Keychain, no tokens in log lines), the `architecture-check` hook, the `protected-paths` approval gate, and the CI `make check` step.

# Security

Policy for reporting issues: [SECURITY.md](../SECURITY.md).

## Credentials

- Claude: Claude Desktop's `oauth:tokenCacheV2` in `config.json`, decrypted in `DesktopAuth.swift`
  with the `Claude Safe Storage` Keychain key (read through `/usr/bin/security` in `Keychain.swift`).
  That key decrypts everything Claude Desktop seals, so prefer approving it once ("Allow") over
  "Always Allow". Read-only; nothing is written back.
- Codex: `~/.codex/auth.json` (shared with the ChatGPT/Codex desktop app), read-only.
- Tokens are held in memory only for a request. Never logged, printed, put in a URL, a notification
  or a crash message. `check-architecture.py` flags log lines that mention tokens.
- Nothing is sent anywhere except `api.anthropic.com`,
  `chatgpt.com` and `date.nager.at` (public holidays; sends only a country code and a year).
- Country codes are validated (`^[A-Z]{2}$`) before they reach a file name or URL.

## Supply chain

No third-party Swift dependencies. Dev tools are installed by `make bootstrap`.

## CI hardening

- Every workflow has `permissions: {}` at the top and the minimum per job; no `pull_request_target`.
- Actions are pinned to full commit SHAs with the version in a comment; Dependabot bumps them with
  a cooldown. Checkout uses `persist-credentials: false`.
- `zizmor` (workflow audit), `actionlint`, `shellcheck` and `gitleaks` (secrets, full history) run
  on every push and PR, locally with `make security`, and in the pre-push hook.
- Not enabled: CodeQL and dependency review need GitHub Advanced Security on private repos;
  tracked in the [tech-debt tracker](tech-debt-tracker.md).

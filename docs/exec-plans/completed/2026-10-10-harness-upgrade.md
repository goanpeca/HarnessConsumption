# Harness upgrade

Goal: bring the repo in line with [harness-engineering.md](../../references/harness-engineering.md)
and harden tooling and CI. Architecture: [ARCHITECTURE.md](../../../ARCHITECTURE.md).

## Constraints

- One-line Conventional Commits; no AI attribution.
- Every check's failure message says how to fix it.
- No new runtime dependencies.

## Tasks

- [x] `AGENTS.md` as a ~100-line map; `CLAUDE.md` imports it
- [x] `docs/` system of record: design docs index, core beliefs, specs, quality, reliability, security, plans, references
- [x] `scripts/check-architecture.py` (layers, boundaries, taste), negative-tested
- [x] `scripts/check-docs.py` and `scripts/check-file-size.sh`
- [x] SwiftLint strict config; fix what it found (force unwraps, long function)
- [x] Coverage floors (`scripts/check-coverage.py`)
- [x] Workflows: least-privilege, SHA-pinned, `persist-credentials: false`; zizmor, actionlint, shellcheck, gitleaks
- [x] Dependabot for actions, CODEOWNERS, PR template, SECURITY.md
- [x] Git hooks: pre-commit fast checks, pre-push full gate
- [x] Weekly drift scan that opens an issue
- [x] Fix native look: re-stamp SDK version in the bundle

## Decision log

- 2026-10-10: Two workflows (macOS gate, Ubuntu security) so security tools are pinned and cheap; `make ci` runs both sets locally.
- 2026-10-10: gitleaks installed from a checksum-verified release in CI instead of a marketplace action (fewer third-party actions to pin).
- 2026-10-10: CodeQL and dependency review skipped: they need GitHub Advanced Security on private repos (TD-1).
- 2026-10-10: Disabled SwiftLint `optional_data_string_conversion`, `multiline_parameters`, `identifier_name`: lossy decoding is intended for diagnostics, swift-format owns layout, JSON keys are snake_case.
- 2026-10-10: Panel looked non-native because SwiftPM's build system stamps `sdk 14.0`; `vtool` re-stamps the real SDK in `scripts/bundle.sh`.

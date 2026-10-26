#!/usr/bin/env python3
"""Doc-drift gate for the knowledge base (see docs/core-beliefs.md).

Checks: AGENTS.md stays a short map; required docs exist; relative links
resolve; every intent/<slug>/ folder is indexed and its intent, spec and plan
follow the playbook shape (numbered requirements, proof, decision log).
Stdlib only. Exit 1 on any violation.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAX_AGENTS_LINES = 110
REQUIRED = [
    "AGENTS.md",
    "CLAUDE.md",
    "ARCHITECTURE.md",
    "REVIEW.md",
    "SECURITY.md",
    "intent/README.md",
    "intent/menu-bar-usage/intent.md",
    "intent/menu-bar-usage/spec.md",
    "docs/core-beliefs.md",
    "docs/tech-debt-tracker.md",
    "docs/DESIGN.md",
    "docs/FRONTEND.md",
    "docs/PLANS.md",
    "docs/PRODUCT_SENSE.md",
    "docs/QUALITY_SCORE.md",
    "docs/RELIABILITY.md",
    "docs/SECURITY.md",
    "docs/references/usage-endpoints.md",
    "docs/references/harness-engineering.md",
    ".claude/settings.json",
    ".claude/hooks/architecture-check.sh",
    ".claude/hooks/protected-paths.py",
    ".claude/skills/credential-handling/SKILL.md",
]
FENCE_RE = re.compile(r"^(```|~~~).*?^\1", re.M | re.S)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
INLINE_LINK_RE = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
REF_LINK_RE = re.compile(r"^\s*\[[^\]]+\]:\s*<?(\S+?)>?(?:\s+\"[^\"]*\")?\s*$", re.M)


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def doc_files() -> list[Path]:
    files = [ROOT / n for n in ("AGENTS.md", "ARCHITECTURE.md", "README.md", "REVIEW.md", "SECURITY.md")]
    for folder in ("docs", "intent"):
        files += sorted((ROOT / folder).rglob("*.md")) if (ROOT / folder).is_dir() else []
    return [f for f in files if f.is_file()]


def links(text: str) -> list[str]:
    text = INLINE_CODE_RE.sub("", FENCE_RE.sub("", text))
    return INLINE_LINK_RE.findall(text) + REF_LINK_RE.findall(text)


def check_agents(errors: list[str]) -> None:
    agents = ROOT / "AGENTS.md"
    if not agents.is_file():
        return
    count = len(agents.read_text(encoding="utf-8").splitlines())
    if count > MAX_AGENTS_LINES:
        errors.append(
            f"AGENTS.md has {count} lines (max {MAX_AGENTS_LINES}). It is a map, not a manual: "
            f"move the detail into the right docs/ file and leave a one-line pointer."
        )
    claude = ROOT / "CLAUDE.md"
    if claude.is_file() and "@AGENTS.md" not in claude.read_text(encoding="utf-8"):
        errors.append("CLAUDE.md must import @AGENTS.md (AGENTS.md is canonical); put rules there, not here.")


def check_required(errors: list[str]) -> None:
    for name in REQUIRED:
        if not (ROOT / name).exists():
            errors.append(
                f"{name} is missing. Restore it (see the 'Where to look' table in AGENTS.md); "
                f"if it was intentionally removed, update REQUIRED in scripts/check-docs.py "
                f"and the links that point to it."
            )


def check_links(errors: list[str]) -> None:
    for doc in doc_files():
        for target in links(doc.read_text(encoding="utf-8")):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
                continue  # external (http, mailto, ...) or same-file anchor
            path = target.split("#", 1)[0].split("?", 1)[0]
            if not path:
                continue
            resolved = (ROOT / path.lstrip("/")) if path.startswith("/") else (doc.parent / path)
            if not resolved.exists():
                errors.append(
                    f"{rel(doc)} links to {target}, which does not exist. Fix the path "
                    f"(links are relative to the linking file), or remove the link if the "
                    f"target was deleted."
                )


def check_intents(errors: list[str]) -> None:
    folder = ROOT / "intent"
    index = folder / "README.md"
    if not index.is_file():
        return
    indexed = {t.split("#", 1)[0].split("/")[0] for t in links(index.read_text(encoding="utf-8"))}
    for change in sorted(p for p in folder.iterdir() if p.is_dir()):
        name = change.name
        if name not in indexed:
            errors.append(
                f"intent/{name}/ is not listed in intent/README.md. Add a row linking its artifacts "
                f"with stage and status. See docs/PLANS.md."
            )
        has = {f.name for f in change.glob("*.md")}
        if not has & {"intent.md", "plan.md"}:
            errors.append(
                f"intent/{name}/ has no intent.md. Every change starts with one; write it (or, for work "
                f"that predates the chain, a plan.md that says so). See docs/PLANS.md."
            )
        spec = change / "spec.md"
        if spec.is_file() and not re.search(r"^- R1\.", spec.read_text(encoding="utf-8"), re.M):
            errors.append(
                f"{rel(spec)} has no numbered requirements. List them as '- R1. <testable statement>' "
                f"so the plan and the review can cite them. See docs/PLANS.md."
            )
        plan = change / "plan.md"
        if plan.is_file():
            text = plan.read_text(encoding="utf-8")
            for heading in ("## Proof", "## Decision log"):
                if not re.search(rf"^{re.escape(heading)}\s*$", text, re.M):
                    errors.append(
                        f"{rel(plan)} has no '{heading}' section. Add it: Proof names the checks that "
                        f"cover each requirement; the decision log gets a dated line per non-obvious "
                        f"choice. See docs/PLANS.md."
                    )


def main() -> int:
    errors: list[str] = []
    check_agents(errors)
    check_required(errors)
    check_links(errors)
    check_intents(errors)
    if errors:
        print("check-docs: FAILED", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    print(f"check-docs: OK ({len(doc_files())} docs, links resolve)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

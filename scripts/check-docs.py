#!/usr/bin/env python3
"""Doc-drift gate for the knowledge base (see docs/design-docs/core-beliefs.md).

Checks: AGENTS.md stays a short map; required docs exist; relative links
resolve; the design-doc index lists every design doc with a valid status;
active exec plans keep a decision log. Stdlib only. Exit 1 on any violation.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAX_AGENTS_LINES = 110
STATUSES = {"current", "stale", "superseded"}
REQUIRED = [
    "AGENTS.md",
    "CLAUDE.md",
    "ARCHITECTURE.md",
    "SECURITY.md",
    "docs/design-docs/index.md",
    "docs/design-docs/core-beliefs.md",
    "docs/exec-plans/tech-debt-tracker.md",
    "docs/exec-plans/completed/.gitkeep",
    "docs/exec-plans/active/.gitkeep",
    "docs/product-specs/index.md",
    "docs/product-specs/menu-bar-usage.md",
    "docs/DESIGN.md",
    "docs/FRONTEND.md",
    "docs/PLANS.md",
    "docs/PRODUCT_SENSE.md",
    "docs/QUALITY_SCORE.md",
    "docs/RELIABILITY.md",
    "docs/SECURITY.md",
    "docs/references/usage-endpoints.md",
    "docs/references/harness-engineering.md",
]
FENCE_RE = re.compile(r"^(```|~~~).*?^\1", re.M | re.S)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
INLINE_LINK_RE = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
REF_LINK_RE = re.compile(r"^\s*\[[^\]]+\]:\s*<?(\S+?)>?(?:\s+\"[^\"]*\")?\s*$", re.M)


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def doc_files() -> list[Path]:
    files = [ROOT / "AGENTS.md", ROOT / "ARCHITECTURE.md", ROOT / "README.md", ROOT / "SECURITY.md"]
    files += sorted((ROOT / "docs").rglob("*.md")) if (ROOT / "docs").is_dir() else []
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


def check_design_index(errors: list[str]) -> None:
    folder = ROOT / "docs" / "design-docs"
    index = folder / "index.md"
    if not index.is_file():
        return
    text = index.read_text(encoding="utf-8")
    rows = [line for line in text.splitlines() if line.lstrip().startswith("|")]
    header = [cell.strip().lower() for cell in rows[0].strip().strip("|").split("|")] if rows else []
    if "status" not in header:
        errors.append(
            "docs/design-docs/index.md needs a table with a Status column "
            f"({'/'.join(sorted(STATUSES))}). See docs/PLANS.md."
        )
        return
    col = header.index("status")
    for row in rows[2:]:
        cells = [cell.strip() for cell in row.strip().strip("|").split("|")]
        status = re.sub(r"[*_`]", "", cells[col]).strip().lower() if col < len(cells) else ""
        if status not in STATUSES:
            errors.append(
                f"docs/design-docs/index.md row '{row.strip()}' has status '{status}'. "
                f"Use one of {sorted(STATUSES)}."
            )
    listed = {Path(t.split("#", 1)[0]).name for t in links(text)}
    for doc in sorted(folder.glob("*.md")):
        if doc.name in {"index.md", "core-beliefs.md"}:
            continue
        if doc.name not in listed:
            errors.append(
                f"{rel(doc)} is not listed in docs/design-docs/index.md. Add a row linking it "
                f"with status, verified date and a one-line summary."
            )


def check_exec_plans(errors: list[str]) -> None:
    for plan in sorted((ROOT / "docs" / "exec-plans" / "active").glob("*.md")):
        text = plan.read_text(encoding="utf-8")
        if not re.search(r"^## Decision log\s*$", text, re.M):
            errors.append(
                f"{rel(plan)} has no '## Decision log' section. Add one and append dated "
                f"entries for every non-obvious choice. See docs/PLANS.md."
            )
        done = re.findall(r"^\s*- \[x\]", text, re.M | re.I)
        open_tasks = re.findall(r"^\s*- \[ \]", text, re.M)
        if done and not open_tasks:
            errors.append(
                f"{rel(plan)} has every task ticked but is still active. `git mv` it to "
                f"docs/exec-plans/completed/ and update links to it. See docs/PLANS.md#lifecycle."
            )


def main() -> int:
    errors: list[str] = []
    check_agents(errors)
    check_required(errors)
    check_links(errors)
    check_design_index(errors)
    check_exec_plans(errors)
    if errors:
        print("check-docs: FAILED", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    print(f"check-docs: OK ({len(doc_files())} docs, links resolve)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

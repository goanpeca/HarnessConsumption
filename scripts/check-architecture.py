#!/usr/bin/env python3
"""Enforce the layer model in ARCHITECTURE.md (#layers, #boundaries).

Checks:
  1. Package.swift: each target's dependencies are a subset of the allowed edges.
  2. `import X` lines only name modules allowed for that module.
  3. App boundaries: UI frameworks only in view files; UserNotifications only in
     Notifier.swift; Keychain access only in Keychain.swift.
  4. Taste invariants: no print() outside App.swift; secrets are never logged.

Stdlib only. Exit 1 on any violation; every message says how to fix it.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = "See ARCHITECTURE.md#layers"

# Source of truth is ARCHITECTURE.md#layers. Change both together.
# module -> (layer, package deps, system frameworks it may import)
LAYERS: dict[str, tuple[str, set[str], set[str]]] = {
    "ConsumptionKit": ("Logic", set(), {"Foundation"}),
    "AgentConsumption": (
        "Runtime and UI",
        {"ConsumptionKit"},
        {"Foundation", "SwiftUI", "AppKit", "Observation", "UserNotifications", "os"},
    ),
}
# Never allowed in the pure logic layer: these belong to the app target.
FORBIDDEN_IN_KIT = {"SwiftUI", "AppKit", "UIKit", "UserNotifications", "Observation", "os", "Security"}
TEST_FRAMEWORKS = {"Testing"}
ALWAYS = {"Swift"}

# Only these app files may import a UI framework; everything else is logic the views call into.
UI_FRAMEWORKS = {"SwiftUI", "AppKit"}
UI_FILES = {"App.swift", "PanelPinning.swift"}  # plus any *View.swift
SINGLE_OWNER = {"UserNotifications": "Notifier.swift"}
KEYCHAIN_OWNER = "Keychain.swift"
KEYCHAIN_MARKERS = ("/usr/bin/security", "SecItem", "kSecClass")
SECRET_WORDS = re.compile(r"access_?token|refresh_?token|accessToken|refreshToken|bearer", re.I)
LOG_CALL = re.compile(r"\blog\.(notice|info|error|debug|warning|fault)\b|\bLogger\b|\bprint\(")

IMPORT_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:(?:public|package|internal|fileprivate|private)\s+)?"
    r"import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?"
    r"([A-Za-z_]\w*)"
)


def fmt(names: set[str]) -> str:
    return "[" + ", ".join(sorted(names - ALWAYS)) + "]"


def allowed_imports(module: str) -> set[str]:
    _, deps, frameworks = LAYERS[module]
    return deps | frameworks | ALWAYS


def imports(path: Path):
    """Yield (line_number, module) for each import, skipping comments."""
    in_block = False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw
        if in_block:
            if "*/" not in line:
                continue
            line, in_block = line.split("*/", 1)[1], False
        if "/*" in line and "*/" not in line.split("/*", 1)[1]:
            line, in_block = line.split("/*", 1)[0], True
        line = line.split("//", 1)[0]
        match = IMPORT_RE.match(line)
        if match:
            yield number, match.group(1)


def dump_package() -> dict:
    cmd = ["swift", "package", "dump-package", "--package-path", str(ROOT)]
    try:
        out = subprocess.run(cmd, check=True, capture_output=True, text=True).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        detail = getattr(error, "stderr", "") or str(error)
        sys.exit(f"error: `{' '.join(cmd)}` failed:\n{detail}\nFix Package.swift so it parses, then rerun.")
    return json.loads(out)


def dependency_names(target: dict) -> list[str]:
    names = []
    for dep in target.get("dependencies", []):
        for kind in ("byName", "target", "product"):
            if kind in dep:
                names.append(dep[kind][0])
    return names


def tested_module(test_target: str) -> str | None:
    base = test_target.removesuffix("Tests")
    return base if base in LAYERS else None


def unknown_module(name: str) -> str:
    return (
        f"Module {name} is not in the layer table. Add it to ARCHITECTURE.md#layers and "
        f"LAYERS in scripts/check-architecture.py (pick its layer; deps must point downward)."
    )


def check_manifest(errors: list[str]) -> None:
    for target in dump_package()["targets"]:
        name, kind = target["name"], target["type"]
        if kind == "test":
            module = tested_module(name)
            if module is None:
                errors.append(
                    f"Package.swift: test target {name} has no matching module. "
                    f"Name test targets <Module>Tests for a module in LAYERS. {DOC}"
                )
                continue
            allowed = {module} | LAYERS[module][1]
        elif name in LAYERS:
            allowed = LAYERS[name][1]
        else:
            errors.append(unknown_module(name))
            continue
        for dep in dependency_names(target):
            if dep not in allowed:
                errors.append(
                    f"Package.swift: {name} depends on {dep}; allowed: {fmt(allowed)}. "
                    f"Remove the dependency and move shared code down into ConsumptionKit. {DOC}"
                )


def module_violation(rel: str, number: int, name: str, module: str, imported: str, allowed: set[str]) -> str:
    layer = LAYERS[module][0]
    if module == "ConsumptionKit" and imported in FORBIDDEN_IN_KIT:
        fix = (
            "ConsumptionKit is pure logic that must stay testable on any host. Move UI, "
            "notifications, logging and Keychain code to Sources/AgentConsumption and return "
            "plain values (see UsageAlert, WindowPace) for the app to present."
        )
    elif imported == "XCTest":
        fix = "Write tests with Swift Testing (`import Testing`, @Test, #expect)."
    else:
        fix = (
            f"If {imported} is truly needed, add it to ARCHITECTURE.md#layers and LAYERS in "
            f"scripts/check-architecture.py in the same change; otherwise remove the import."
        )
    who = f"{name} is the {layer} layer" if name == module else f"{name} tests the {layer} layer"
    return f"{rel}:{number} imports {imported} — {who} and may import only {fmt(allowed)}. {fix} {DOC}"


def swift_files(directory: Path):
    return sorted(directory.rglob("*.swift"))


def check_sources(errors: list[str]) -> None:
    for kind in ("Sources", "Tests"):
        base = ROOT / kind
        if not base.is_dir():
            continue
        for directory in sorted(p for p in base.iterdir() if p.is_dir()):
            name = directory.name
            module = name if kind == "Sources" else tested_module(name)
            if module not in LAYERS:
                if kind == "Sources":
                    errors.append(unknown_module(name))
                continue  # test dirs are reported by check_manifest
            allowed = allowed_imports(module)
            if kind == "Tests":
                allowed = {module} | allowed | TEST_FRAMEWORKS
            for path in swift_files(directory):
                rel = path.relative_to(ROOT).as_posix()
                for number, imported in imports(path):
                    if imported not in allowed:
                        errors.append(module_violation(rel, number, name, module, imported, allowed))


def is_ui_file(path: Path) -> bool:
    return path.name.endswith("View.swift") or path.name in UI_FILES


def check_app_boundaries(errors: list[str]) -> None:
    base = ROOT / "Sources" / "AgentConsumption"
    for path in swift_files(base):
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        for number, imported in imports(path):
            if imported in UI_FRAMEWORKS and not is_ui_file(path):
                errors.append(
                    f"{rel}:{number} imports {imported} — only view files (*View.swift, "
                    f"{', '.join(sorted(UI_FILES))}) may. Keep clients, stores and notifiers "
                    f"UI-free: expose plain values and let a view present them. "
                    f"See ARCHITECTURE.md#boundaries"
                )
            owner = SINGLE_OWNER.get(imported)
            if owner and path.name != owner:
                errors.append(
                    f"{rel}:{number} imports {imported} — only {owner} may. Add a method to "
                    f"it and call that instead. See ARCHITECTURE.md#boundaries"
                )
        if path.name != KEYCHAIN_OWNER:
            for marker in KEYCHAIN_MARKERS:
                if marker in text:
                    errors.append(
                        f"{rel} uses {marker} — credentials are read and written only in "
                        f"{KEYCHAIN_OWNER}. Add a function there and call it. "
                        f"See ARCHITECTURE.md#boundaries"
                    )


def check_taste(errors: list[str]) -> None:
    for base in (ROOT / "Sources", ROOT / "Tests"):
        for path in swift_files(base):
            rel = path.relative_to(ROOT).as_posix()
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                code = line.split("//", 1)[0]
                if "print(" in code and path.name != "App.swift" and "Tests" not in rel.split("/")[0]:
                    errors.append(
                        f"{rel}:{number} calls print() — use the os Logger (subsystem "
                        f"com.goanpeca.agentconsumption). Only App.swift prints, for --dump."
                    )
                if LOG_CALL.search(code) and SECRET_WORDS.search(code):
                    errors.append(
                        f"{rel}:{number} logs something that looks like a token. Never log "
                        f"credentials or Authorization headers; log the status or host instead. "
                        f"See docs/SECURITY.md"
                    )


def main() -> int:
    errors: list[str] = []
    check_manifest(errors)
    check_sources(errors)
    check_app_boundaries(errors)
    check_taste(errors)
    if errors:
        print("check-architecture: FAILED", file=sys.stderr)
        for error in dict.fromkeys(errors):
            print(f"  {error}", file=sys.stderr)
        return 1
    print(f"check-architecture: OK ({len(LAYERS)} modules, layering and boundaries respected)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

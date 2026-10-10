#!/usr/bin/env bash
# Taste invariant: Swift files stay <= MAX_LINES so each file has one job and
# fits in an agent's context. See AGENTS.md#golden-rules.
set -euo pipefail

MAX_LINES=300
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

failed=0
count=0
while IFS= read -r -d '' file; do
  count=$((count + 1))
  lines=$(wc -l <"$file" | tr -d ' ')
  if ((lines > MAX_LINES)); then
    if ((failed == 0)); then echo "check-file-size: FAILED" >&2; fi
    failed=1
    echo "  $file has $lines lines (max $MAX_LINES). Split it by responsibility:" \
      "move each type or extension with its own job into its own file (e.g. Foo+Codable.swift," \
      "FooRow.swift); do not just delete blank lines or comments." >&2
  fi
done < <(find Sources Tests -type f -name '*.swift' -print0)

if ((failed)); then exit 1; fi
echo "check-file-size: OK ($count Swift files <= $MAX_LINES lines)"

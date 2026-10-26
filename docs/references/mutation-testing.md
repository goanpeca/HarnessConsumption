# Mutation testing

Coverage says a line ran; mutation testing says a test would notice if the line were wrong. It changes
the code one small step at a time (a flipped comparison, a shifted constant, a swapped branch) and
runs the suite. A change the suite doesn't catch (a survivor) is behavior nobody pinned down.

## How it runs here

`make mutation` runs [`scripts/mutation.py`](../../scripts/mutation.py): it copies the repo to a
temporary directory (your working tree is never touched), checks the unmutated suite passes, then
applies each entry of `MUTANTS` and runs `swift test`. It fails on any survivor, and on any pattern
that no longer matches the code or no longer compiles. `make check` runs `--check`, which only
verifies the patterns still match, so a refactor can't silently turn the list stale. The
[mutation workflow](../../.github/workflows/mutation.yml) runs the full thing on changes to the logic
or its tests, weekly, and on demand.

Scope is `ConsumptionKit`, the pure logic. The app target has no tests to measure against.

## Adding a mutant

Pick a behavior with a boundary, a constant or a branch, and add `(file, original, mutated)` to
`MUTANTS`. If it survives, write the test that fails for it first. When you add logic, add a few
mutants for it.

## Why not Muter

[Muter](https://github.com/muter-mutation-testing/muter) is the established Swift mutation tool and
was tried first (v16, the latest release). It rewrites every mutant into the code at once, and that
step doesn't understand modern Swift: it could not build `AlertPlanner.swift`, `Budget.swift` or
`RefreshInterval.swift`, which are most of the logic and all of the newest code. On the files it could
build it scored 71 to 100%. A gate that skips half the code would give false comfort, so the in-repo
runner is the gate. Revisit Muter when it supports current Swift; it needs `muter.conf.yml` with
`executable: /usr/bin/swift`, `arguments: [test]` and `exclude: [Sources/AgentConsumption]`.

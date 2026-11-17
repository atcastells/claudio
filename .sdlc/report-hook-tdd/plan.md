# Plan: Red evidence in implementer reports (B1–B3)

- **Derived from**: `../delegation-hardening/spec.md` (requirements B1–B3,
  decisions D1, D8)
- **Status**: APPROVED BY ENGINEER (2026-11-16, "Apruebo los planes")
- **Nothing is implemented until this file is approved.**

## Done means

`bash evals/run.sh` FAIL 0; an implementer report without a `Red:` or
`Mutation:` line carrying literal output after `→` is sent back, and so is one
that says "not seen", "none" or "n/a" there; a `TASK: x/A1` line gets a message
saying IDs are `T<n>`.

## Stop and ask if

- Any existing case changes its expected exit code (only report text in
  fixtures may change).
- The task needs to open windows or apps on the developer's screen.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | `subagent-report-check.sh`, implementer branch: require a line starting with `Red:` or `Mutation:` that has non-blank text after `→` and reject "not seen", "none", "n/a" after the arrow (case-insensitive, macOS grep). Bad `TASK:` message names `T<n>` and says phases go in the Task cell. New scenarios first, red; then update the report text of existing fixtures that lack the line. | `hooks/subagent-report-check.sh`, `evals/scripts/report-check-test.sh`, `evals/cases/82h-report-implementer-ok.json`, `evals/cases/119a-report-red-evidence.json` | `119a` scenarios: `Red:` with output passes; `Mutation:` with output passes; missing blocked; `Red: x → not seen` blocked; `TASK: d/A1` blocked with the `T<n>` hint. `82h`, `82l` green with fixture text only changed | B1, B3 | implementer | — | 3m/200k | done (main added scenario j red first: a `RESULT: blocked` report needs no Red line) |
| T2 | `agents/implementer.md`: step 1 and the report format use `Red: <command> → <literal failing line>` or `Mutation: <what was broken> → <literal failing line>`; a test that passes before the change is reported as such, not as red. `skills/sdlc/templates/plan.md`: task IDs are `T<n>` (optional letter); phases go in the Task cell. | `agents/implementer.md`, `skills/sdlc/templates/plan.md`, `evals/cases/119b*.json` | `119b1` (Red/Mutation format), `119b2` (pass-before rule), `119b3` (template IDs) red first | B2, B3 | main | — | 3m/1.2M | done (cause: none; 119b1–b3 red then green, suite 302/0) |

Estimates from `calibrate.sh` (2026-11-16): repo medians implementer
2.0m/156k, main 3.1m/1.2M.

## Replaced tests

| Case | Before | After | Why |
|------|--------|-------|-----|
| `82h` and the `good` report in `report-check-test.sh` | report without a `Red:` line | same report plus `Red: … → <failing line>` | B1 makes the line mandatory; expected exit codes unchanged |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1, T2 | 3m | `bash evals/run.sh` |

- **Estimated wall-clock**: ~3m (+ main check)
- **Sequential sum**: 6m
- **Estimated tokens**: ~1.4M

Files are disjoint from `agent-turn-budgets` except `agents/implementer.md`
(that plan's T4): run this plan's T2 after it, never in the same wave.

## Test strategy

Red first. The report check is a hook: scenario script with exit codes and
stderr text. Fixture text updates are listed above, expectations never.

## Verification commands

```
bash -n hooks/subagent-report-check.sh
bash evals/run.sh
```

## Implementation risks

- `→` is multibyte: the hook already runs under the profile's locale; the
  eval must run under `LC_ALL=C` too (case `98f` pattern).
- Real implementers launched with the old prompt will be sent back once
  after install; the hook blocks at most once per agent, so no loop.

## Outside this plan

Release, verification and review: `plan-template-gates` T6–T10.

## Review

Covered by the review of all four slugs: see `../plan-template-gates/plan.md`, *Review*.

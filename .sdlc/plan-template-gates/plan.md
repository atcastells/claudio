# Plan: Plan template gates, and the release of all four slugs (D1r–D3r, X1)

- **Derived from**: `../delegation-hardening/spec.md` (requirements D1r–D3r,
  X1, decisions D5, D10–D12)
- **Status**: APPROVED BY ENGINEER (2026-11-16, "Apruebo los planes")
- **Nothing is implemented until this file is approved.**

This plan also closes the other three (`agent-turn-budgets`,
`report-hook-tdd`, `permission-friction`): one release, one verification,
one review of the whole change.

## Done means

- The plan template has the task-size note, `seam:` tasks, the windows line
  in *Stop and ask if*, and a *Review* section; the `sdlc` skill says a plan
  is not closed with *Review* empty, tells to track orchestration on `main`
  rows, and carries the "no figure without a run that could fail" line.
- 3.1.0 released: `VERSION`, `CHANGELOG.md`, `migrations/3.1.0.md`.
- `bash evals/run.sh` FAIL 0, with the developer's profile too;
  `check-public.sh` adds no hit; clean install green; verifier green or
  amber with nits; three reviewer passes with 0 important.

## Stop and ask if

- Any of the other three plans is not `done` when T6 starts.
- The real install (`./install.sh` into `~/.claude`): always ask first.
- The task needs to open windows or apps on the developer's screen.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | Plan template *Tasks* note: a delegated task covers at most 3 plan rows and leaves the tree building with its tests green; a task crossing layers that do not build apart starts its Task cell with `seam:` and why. *Stop and ask if* default line: the task needs to open windows or apps on the developer's screen. | `skills/sdlc/templates/plan.md`, `evals/cases/121a*.json` | `121a1` (size), `121a2` (`seam:`), `121a3` (windows) red first | D1r | main | report-hook-tdd T2 | 3m/1.2M | done (cause: T1–T3 done in one pass, same two files; 121* 7 red then green, suite 318/0; SKILL.md at 160/160 after merging Stage 5 lines) |
| T2 | Plan template *Review* section (three verdicts, or `Waiver: <reason> (<who>, <date>)`); `sdlc` Stage 5: a plan is not closed with it empty. | `skills/sdlc/templates/plan.md`, `skills/sdlc/SKILL.md`, `evals/cases/121b*.json` | `121b1` (template), `121b2` (skill) red first | D2r | main | T1 | 2m/1.2M | done (cause: measured inside T1) |
| T3 | `sdlc` Stage 3: orchestration on `main` rows so `task-actuals` measures it; and "no figure reaches the user without a run in which the measurement could have failed". | `skills/sdlc/SKILL.md`, `evals/cases/121c*.json` | `121c1`, `121c2` red first | D3r | main | T2 | 2m/1.2M | done (cause: measured inside T1) |
| T4 | `/repo-setup` check: no change needed to the check itself; confirm `check.sh` still passes with the new template (it copies `REVIEW.md` and reads templates). | — | `bash skills/repo-setup/check.sh` on a scratch copy of a configured repo: no new failure | D2r | scout | T2 | 1.2m/380k | done (cause: run on main, one grep: `check.sh` never reads `templates/plan.md`, only `.sdlc/` at line 103) |
| T5 | `migrations/3.1.0.md` (format in `migrations/README.md`): plan template (size, `seam:`, *Review*), agents (turns, rules), new hook `turn-budget.sh`. | `migrations/3.1.0.md`, `evals/cases/121d-migration-3-1-0.json` | `121d` red first; existing migration cases green | X1 | main | T3 | 3m/1.2M | struck (cause: `migrations/README.md` says a migration ships only when project files change; this release changes `~/.claude` only; 2.5.0–3.0.0 shipped none either. The spec's X1 was wrong on this point) |
| T6 | 3.1.0: `VERSION`, `CHANGELOG.md`. Full suite, profile suite, `check-public.sh`, clean install (`HOME=$(mktemp -d) ./install.sh --no-profile --verbose`). Fill *Estimate vs actual* of the four plans. | `VERSION`, `CHANGELOG.md`, the four `plan.md` | The four commands in "Verification commands" green | X1 | main | T5, all other plans done | 5m/2M | done (cause: none; suite 318/0, company profile 329/0, example profile 319/0, check-public: 2 new hits found by review (the company name in this row and in actuals.jsonl), reworded; clean install 277/0) |
| T7 | Verify the whole change and two adjacent flows: `task-actuals` still measures a delegated task with the new prompt lines; `plan-resume` and `plan-hint` still read a plan with a *Review* section and `seam:` rows. Suite result given by main. | — | Verifier report with commands and output | all | verifier | T6 | 3m/520k | done (red: 2 IMPORTANT heredoc bypasses in `production-gate`, filter removed by developer decision; 3 NITs, 2 fixed red first: `T3-red` header, plan-hint `T3b`; the `$(cat <<'EOF'` commit-body block is documented, not changed) |
| T8 | Review pass: bugs | — | Findings per `REVIEW.md` | all | reviewer | T7 | 3m/660k | done (1 important fixed, 5 nits) |
| T9 | Review pass: security (heredoc stripping as a gate bypass; transcript and marker paths in `turn-budget.sh`) | — | Findings per `REVIEW.md` | C1, A2 | reviewer | T7 | 3m/660k | done (0 important, 4 nits) |
| T10 | Review pass: conformance (bash + jq, macOS bash and awk, no `sed -i`, budgets, English) | — | Findings per `REVIEW.md` | all | reviewer | T7 | 3m/660k | done (2 important fixed, 3 nits) |

Estimates from `calibrate.sh` (2026-11-16): repo medians main 3.1m/1.2M,
verifier 3.0m/520k, reviewer 3.1m/656k; scout from the machine log,
1.2m/382k. T6 sized above (four checks plus four tables).

## Schedule

The four plans in order (shared files force it):

1. `agent-turn-budgets` wave 1 with `report-hook-tdd` T1 and
   `permission-friction` T1 (disjoint files).
2. `agent-turn-budgets` waves 2–3.
3. `report-hook-tdd` T2, then `permission-friction` T2.
4. This plan:

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1 → T2 → T3 (same files, sequential) | 7m | `bash evals/run.sh` |
| 2 | T4, T5 | 3m | `git diff --stat` |
| 3 | T6 | 5m | — |
| 4 | T7 | 3m | read the verdict |
| 5 | T8, T9, T10 | 3m | fill *Review* |

- **Estimated wall-clock, this plan**: ~21m; **all four**: ~40m
- **Sequential sum, this plan**: 28m
- **Estimated tokens, this plan**: ~10M; **all four**: ~17M

## Test strategy

Red first for every text case. The verifier gets the suite result from main
(D6) and spends its turns on behavior and adjacent flows.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh status-line.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<name> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile --verbose
```

`check-public.sh` already exits 1 on `main` (hits in `.sdlc/claudio/spec.md`
and the LICENSE placeholder): the criterion is no new hit.

## Review

Covers the four slugs (2026-11-16). Every IMPORTANT was fixed with a case
seen red first; the suite after the fixes is 323/0.

- **bugs**: 1 important, fixed (Red rule matched only exact "not seen" /
  "none" / "n/a"; now an opening admission is sent back). Nits fixed: the
  verifier green rule vs a given suite result, `T3:` / `T3.` headers, the
  120a file name, the stale permission-friction T1 row. Left: a `Red:` line
  wrapped onto the next line is sent back once.
- **security**: 0 important. Nits fixed: the company name in two new files,
  the verifier given-result rule. Left: a report with thousands of empty
  `Red:` lines is slow (13.7 s for 5000); the report marker follows a
  dangling symlink (pre-existing in 3.0.0, creates empty files only).
- **conformance**: 2 important, both fixed (the company name; the Red rule
  above). Nits fixed: stale spec rows (now an *As built* paragraph), the
  permission-friction *Done means*, the CHANGELOG transcript claim.

## Implementation risks

- `skills/sdlc/SKILL.md` is touched by four tasks across three plans: strictly
  sequential, each one re-reads the file.
- The migration must not tell configured repos to change anything they
  already have.

## Estimate vs actual

Filled at T6 from each slug's `actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation (min / tok) | Cause |
|---|---------|-----|--------|-----------|-------|
| agent-turn-budgets T1 | main | 4m/1500k | 4.5m/3511k | 13% / 134% | two extra doc reads, a claude.dev check and a question to the developer |
| agent-turn-budgets T4 (+T5) | main | 3m/1200k | 5.1m/1927k | 70% / 61% | needles wrapped across lines; SKILL.md over its budget; T5 done inside it |
| report-hook-tdd T1 | implementer | 3m/200k | 3m/111k | 0% / -45% | none (main added scenario j afterwards) |
| report-hook-tdd T2 | main | 3m/1200k | 1.9m/619k | -37% / -48% | none |
| permission-friction T1 | implementer | 3m/200k | 7.3m/389k | 143% / 95% | sent back once: interpreter bypasses, allowlist redesign |
| permission-friction T2 | main | 3m/1200k | 1.8m/628k | -40% / -48% | none |
| plan-template-gates T1 (+T2, T3) | main | 3m/1200k | 2.5m/1071k | -17% / -11% | three rows in one pass |
| plan-template-gates T6 | main | 5m/2000k | 3.6m/2032k | -28% / 2% | none |

Over 50 %: agent-turn-budgets T1 (tokens), T4 (minutes, tokens) and
permission-friction T1 (minutes, tokens), causes above. Not measured:
agent-turn-budgets T5 and plan-template-gates T2, T3 (never moved to
`in progress`; done inside another row), T4 (one grep), T5 (struck). The
main thread between rows is not measured either.

## Outside this plan

The real install into `~/.claude` (ask first). Reporting #2 and #9 upstream.
Next intent, approved to open after 3.1.0 (developer, 2026-11-16): edits
made through Bash in auto mode skip `credential-guard`, `test-guard` and
`task-actuals`, which only match Edit/Write.
The personal 100-line rule (`/rules`).

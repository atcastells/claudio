# Plan: claudio-3-6-1

- **Derived from**: review of two sessions on 2026-11-19: ASTRA AST-ESP-002
  (Orchestrate, Fable 5.2 main, 3.6.0) and EIC front ci-aws /
  ci-tests-lighter (Spec mode, Opus 5.5 main).
- **Status**: APPROVED BY ENGINEER (Aaron, 2026-11-19: "si")
- **Built by**: a Claude cloud thread through folder access; push, PR and
  `./install.sh` stay with the developer.

## Evidence

| # | Seen | Cause |
|---|------|-------|
| E1 | Haiku scouts with `usd_min: null`, so the integrator's `cost` is null too | `task-actuals.sh` price table had no `claude-haiku-5-5` |
| E2 | Guard blocked `git ls-tree` and `grep -e "\.png$"` | `ls-tree`/`cat-file` not in the list; any `$` blocked |
| E3 | Fable main read whole T0 artifacts, a design doc and source code to draft a spec | The skill says what not to read but T0 did not return a summary fit to draft from |
| E4 | EIC: main tasks T3/T5/T6 without actuals rows, T4 at 0.1 min/0 tokens | Status changed with `python3` from Bash; the hook only saw Edit/Write |
| E5 | EIC: tags used the starting table (3m/400k) although calibrate ran | calibrate printed the starting table first and the median only as a factor line |
| E6 | `production-gate` blocked a heredoc and a docker command that said "production" | By design (cases 120a, 120g scan heredoc bodies); left unchanged, its message already says to use Write/Edit |

## Tasks

| # | Task | Files | Test | Status |
|---|------|-------|------|--------|
| T1 | Haiku 5.5 price ($0.10/$0.50, cache read $0.01) | `hooks/task-actuals.sh` | task-actuals i4 | done |
| T2 | Guard: `ls-tree`, `cat-file -p/-t/-s/-e`; `$` closing a quoted regex | `hooks/orchestrator-guard.sh` | guard git-read-more, git-chain | done |
| T3 | T0 for a spec returns facts with file:line; main drafts from it | `agents/integrator.md`, `skills/orchestrate/SKILL.md` | 125y1, 125y2, 125x8, 125n | done |
| T4 | Main rows when plan.md is edited from Bash | `hooks/task-actuals.sh`, `settings.template.json` | task-actuals i3, 84e | done |
| T5 | calibrate prints `est=` per runner from the median it says to use | `skills/sdlc/calibrate.sh` | 103h | done |
| T6 | production-gate | — | — | not changed (E6) |
| T7 | VERSION 3.6.1, CHANGELOG, full suite | `VERSION`, `CHANGELOG.md` | `review/final-evals.log` | done |

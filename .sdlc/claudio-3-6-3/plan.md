# Plan: claudio-3-6-3

- **Derived from**: live5 review (ASTRA VIS-EST-001, Fable 5.2 main, 3.6.2), 2026-11-19.
- **Status**: APPROVED BY ENGINEER (Aaron, 2026-11-19: "si")
- **Built by**: a Claude cloud thread through folder access, branch `feat/3.6.3-orchestrate` from `feat/3.6.2-orchestrate`; push, PR and `./install.sh` stay with the developer.

## Evidence

| # | Seen | Cause |
|---|------|-------|
| E1 | Two Read calls of PNG screenshots under `review/shots/` blocked; the developer had asked for a screenshot on every visual change | 3.6.2 Read guard limits all of `review/`, images included |
| E2 | T13–T16 left `in progress` after finishing; T5 left `needs-decision` | The plan-status hook closed only integrator rows; the main launched verifier and reviewers itself |
| E3 | Main wrote `review/findings.md` and `review/verifier.md` | Same: reviewers cannot write, and nothing kept the main from launching them |
| E4 | `cut` in a pipe and `grep -E "(a\|b)"` blocked | `cut` not a filter; quoted metacharacters treated as shell syntax |

## Tasks

| # | Task | Files | Test | Status |
|---|------|-------|------|--------|
| T1 | Images pass the Read guard whole | `hooks/orchestrator-guard.sh` | 126h | done |
| T2 | Plan row closes from any agent's RESULT (done when none) | `hooks/task-actuals.sh` | 126c | done |
| T3 | Main launches only integrator and scout; skill: review rows go to the integrator, a needs-decision is answered with SendMessage | `hooks/orchestrator-guard.sh`, `skills/orchestrate/SKILL.md` | 126i, 126k, 125n | done |
| T4 | Quoted metacharacters are text; `cut` is a filter | `hooks/orchestrator-guard.sh` | 126j | done |
| T5 | VERSION 3.6.3, CHANGELOG, full suite, commit | `VERSION`, `CHANGELOG.md` | `review/final-evals.log` | done |

# Plan: claudio-3-8-1

- **Derived from**: live6 review (ASTRA VIS-EST-002, Fable 5.2 main, 3.7.0), 2026-11-19, with the subagent transcripts.
- **Status**: APPROVED BY ENGINEER (Aaron, 2026-11-19: "ok")
- **Built by**: a Claude cloud thread through folder access, branch `feat/3.8.1-orchestrate` from `feat/3.8.0-module-claude-md`; push, PR and `./install.sh` stay with the developer.

## Evidence

| # | Seen | Cause |
|---|------|-------|
| E1 | T0 recorded 45.5 min, 7.1M tokens, $4.55; real work ~17 min | The main continued the T0 integrator with SendMessage for the plan and for T12; actuals measured first to last line, 28 min of waiting included; context grew to ~190k per call |
| E2 | T12 and T10 left `pending` | Done through SendMessage, never launched with their own tag |
| E3 | 0 LSP calls and 0 tags lookups in 26 agents, ~150 grep/rg | Rule only in prose; nothing checks the LSP server or reminds at the grep |

## Tasks

| # | Task | Files | Test | Status |
|---|------|-------|------|--------|
| T1 | Guard: SendMessage only for the agent's own task | `hooks/orchestrator-guard.sh`, `settings.template.json`, `skills/orchestrate/SKILL.md` | 126l, 126k, 125n | done |
| T2 | Actuals: active minutes, waits before a new prompt over 5 min left out | `hooks/task-actuals.sh`, fixture `idle.jsonl` | 102a scenario z, 126n | done |
| T3 | bash-habits tags reminder; check.sh LSP server and tags file | `hooks/bash-habits.sh`, `skills/repo-setup/check.sh` | 126m, 126o | done |
| T4 | VERSION 3.8.1, CHANGELOG, full suite, commit | `VERSION`, `CHANGELOG.md` | `review/final-evals.log` | done |

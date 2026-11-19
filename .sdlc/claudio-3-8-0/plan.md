# Plan: claudio-3-8-0

- **Derived from**: developer request, 2026-11-19: module CLAUDE.md files should appear on their own in any repo.
- **Status**: APPROVED BY ENGINEER (Aaron, 2026-11-19: "si" to the proposed text); built on `feat/3.8.0-module-claude-md` from `feat/3.7.0-astra-profiling`. Push, PR and `./install.sh` stay with the developer.

## Tasks

| # | Task | Files | Test | Status |
|---|------|-------|------|--------|
| T1 | Global rule "Module CLAUDE.md"; core budget 81, installed 116 | `global/CLAUDE.md`, cases 65, 65b | 128a, 128b, 65, 65b | done |
| T2 | orchestrate: repo knowledge to the module's CLAUDE.md, no asking | `skills/orchestrate/SKILL.md` | 128c | done |
| T3 | sdlc: update touched modules' CLAUDE.md before the PR; budget 162 | `skills/sdlc/SKILL.md`, case 79 | 128d, 79 | done |
| T4 | repo-setup: check.sh warns on module CLAUDE.md > 30 lines and missing AGENTS.md symlinks; skill creates them | `skills/repo-setup/check.sh`, `skills/repo-setup/SKILL.md`, `evals/scripts/module-claude-md-test.sh` | 128e, 128f | done |
| T5 | VERSION 3.8.0, CHANGELOG, full suite, commit (no push) | `VERSION`, `CHANGELOG.md` | `review/final-evals.log` | done |

# Plan: claudio-3-7-0

- **Derived from**: profile of the ASTRA sessions, 13-19 Nov 2026 (22 main sessions, 303 subagent transcripts).
- **Status**: APPROVED BY ENGINEER (Aaron, 2026-11-19: "Todos"); built on `feat/3.7.0-astra-profiling` from `feat/3.6.3-orchestrate`. Push, PR and `./install.sh` stay with the developer.

## Evidence

| # | Seen | Cause |
|---|------|-------|
| E1 | ~560 `grep -n "fn/pub/struct"` by subagents to find definitions, 2 lookups in `tags` | Agents' `tools:` has no `LSP`; scout says "Glob and Grep first" |
| E2 | Every live4 integrator brief repeats "no git writes, no full suite, no Godot windows, not the workspace target/" | No place for repo-wide agent rules; the brief carries them |
| E3 | Parallel tasks: "do not use target/", "if it fails on a half-written file, wait and retry" | Read-only agents share the writers' build dir |
| E4 | 2-12% of the implementers' `cargo test` runs kept output in a file | Rule in implementer.md and CLAUDE.md, nothing checks it |
| E5 | 40-65% of the implementers' edits were python/perl scripts | `bash-file-check` checks the result but says nothing about the habit |

## Tasks

| # | Task | Files | Test | Status |
|---|------|-------|------|--------|
| T1 | `LSP` in the five agents' tools; scout, implementer and verifier look symbols up with LSP or the tags index | `agents/*.md` | 127a-g | done |
| T2 | Integrator applies the repo's `## Agent defaults`; the brief states only exceptions | `agents/integrator.md`, `skills/sdlc/templates/brief.md`, `agents/implementer.md` | 127h, 127i | done |
| T3 | Read-only agents get `CARGO_TARGET_DIR=$TMPDIR/claudio-target-ro` while another task builds | `agents/integrator.md` | 127j | done |
| T4 | `bash-habits` PostToolUse(Bash) hook: reminders for test output to no file and script rewrites of repo files, never a block | `hooks/bash-habits.sh`, `settings.template.json`, `evals/scripts/bash-habits-test.sh` | 127k, 127l | done |
| T5 | VERSION 3.7.0, CHANGELOG, full suite, commit (no push) | `VERSION`, `CHANGELOG.md` | `review/final-evals.log` | done |

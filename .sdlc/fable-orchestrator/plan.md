# Plan: fable-orchestrator

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-11-18)
- **Nothing is implemented until this file is approved.**

This plan is built in the current mode (Opus 5.5 main, Sonnet implementers):
the new mode cannot build itself.

## Done means

Every requirement R1–R8 has its eval, seen red first; `bash evals/run.sh` is
green (also with the developer's profile); `scripts/check-public.sh` exits 0;
`HOME=$(mktemp -d) ./install.sh --no-profile --verbose` ends with the suite
green and installs `agents/integrator.md`, `skills/orchestrate/` and
`hooks/orchestrator-guard.sh`; budget cases 65, 65b and 79 unchanged.

## Stop and ask if

- T0 shows that a hook cannot tell the main session from a subagent, or
  cannot attribute a nested agent's usage to the integrator that launched
  it: R2 or R5 then need another design.
- The installed Claude Code is older than 2.1.219, or
  `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` is below 2 on the developer's
  machine.
- A budget eval (65, 65b, 79) would need raising.
- An existing test fails for a reason unrelated to this change.
- The task needs to open windows or apps on the developer's screen.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T0 | Checks before building: hook payload fields that tell main from a subagent (`agent_id`, `agent_type`) on PreToolUse; whether a nested agent's SubagentStop names its parent; whether SessionStart carries the model; the developer's spawn depth (`claude --version` is 2.1.327, given by the developer on 2026-11-18: nesting available). Findings go to `context.md` | `.sdlc/fable-orchestrator/context.md` | each finding cites a doc page or a captured payload shape (no values) | R2, R3, R5 | main | — | 10m/1.5M | done |
| T1 | `/orchestrate` and `/orchestrate off`: own marker next to Vibe's, SessionStart re-injects the notice after compact/resume and clears it on startup/clear; status line shows `Orch` | `hooks/lib/mode.sh`, `hooks/mode.sh`, `status-line.sh`, cases 125a–125c | 125a on/off marker, 125b SessionStart re-inject and clear, 125c status line | R1 | implementer | — | 3m/250k | done |
| T2 | `orchestrator-guard.sh` on PreToolUse, registered in `settings.template.json`: in the mode and in the main session blocks Edit, Write, NotebookEdit and Bash, except writes under `.sdlc/<slug>/` and read-only git; no-op without the marker or inside a subagent | `hooks/orchestrator-guard.sh`, `settings.template.json`, cases 125d–125h | 125d Edit blocked in main, 125e Edit allowed in subagent, 125f `.sdlc/` write allowed, 125g `git log` allowed and `cargo test` blocked, 125h no marker no-op; hook-registered case | R2 | implementer | T0, T1 | 5m/400k | done |
| T3 | `agents/integrator.md` (model opus, effort medium, `Agent` in tools; implementer's failure budget, filtered tests, log in a file; artifact report); `Agent` in `disallowedTools` of the other four agents | `agents/integrator.md`, `agents/implementer.md`, `agents/verifier.md`, `agents/reviewer.md`, `agents/scout.md`, cases 125i–125k | 125i integrator pins opus/medium, 125j the four disallow Agent, 125k integrator report names `ARTIFACT:` | R3 | implementer | — | 3m/250k | done |
| T4 | Artifact template and the `orchestrate` skill: format, the five kinds, the six `data` types and destinations, the persistence matrix with the starting threshold, condense don't copy, `work/` emptied at Build close; the sdlc skill points to it without adding lines | `skills/sdlc/templates/artifact.md`, `skills/orchestrate/SKILL.md`, `skills/sdlc/SKILL.md`, cases 125l–125n | 125l template has every field, 125m skill has the matrix, 125n orchestrate SKILL.md ≤ 80 lines; 79 still green | R4, R7 | implementer | — | 3m/300k | done |
| T5 | `subagent-report-check`: integrator reports need `ARTIFACT: <path>`, the file under `.sdlc/<slug>/work/` and the required frontmatter fields; other agents unchanged | `hooks/subagent-report-check.sh`, cases 125o–125q | 125o no ARTIFACT sent back, 125p missing file sent back, 125q missing `data` sent back; existing report cases green | R6 | implementer | T3, T4 | 3m/300k | done |
| T6 | `task-actuals` writes `cost` into the integrator's artifact: its own usage plus its nested agents', as T0 found they can be attributed | `hooks/task-actuals.sh`, cases 125r–125s | 125r cost written into frontmatter, 125s nested usage summed | R5 | implementer | T0, T5 | 5m/400k | done |
| T7 | `/repo-setup` ignores `.sdlc/*/work/`; migration `3.4.0` | `skills/repo-setup/SKILL.md`, `skills/repo-setup/templates/*` (gitignore part only), `migrations/3.4.0.md`, cases 125t–125u | 125t template ignores work/, 125u migration installed | R8 | implementer | — | 3m/250k | done |
| T8 | Release: `VERSION` 3.4.0, `CHANGELOG.md`, `docs/technical.md`; full suite, profile suite, `check-public`, clean test install | `VERSION`, `CHANGELOG.md`, `docs/technical.md` | the Done means commands | all | main | T1–T7 | 5m/1.5M | done |
| T9 | Verify: the change plus two adjacent flows (Vibe mode on/off, implementer report check in the normal mode) | — | VERDICT green | all | verifier | T8 | 4m/600k | done (self-review in the main session, no subagent) |
| T10 | Review: bugs, security, conformance in parallel | — | three PASS reports | all | reviewer | T8 | 3m/600k | done (self-review in the main session, no subagent) |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T0 | 10m | write `context.md`; stop and ask if T0 says so |
| 2 | T1, T3, T4, T7 | 3m | `git diff --stat`, read the diffs, fold `Learned:` |
| 3 | T2, T5 | 5m | same |
| 4 | T6 | 5m | same |
| 5 | T8 | 5m | full suite once, output to a file |
| 6 | T9, T10 | 4m | consolidate findings |

- **Estimated wall-clock**: about 32 m plus main checks between waves
- **Sequential sum**: 47 m
- **Estimated tokens**: about 6.4 M

Estimates from `calibrate.sh` on this repo: implementer median 2.3m/167k,
main 3.2m/1.4M, verifier 3.4m/561k, reviewer 3.0m/572k.

## Order and dependencies

T0 first: R2 and R5 depend on hook payload fields that are not confirmed.
T2 needs the marker from T1. T5 needs the agent name (T3) and the format
(T4). T6 writes into the file T5 validates and needs T0's answer on nested
attribution. Wave 2 tasks have disjoint files.

## Test strategy

Every rule gets its eval, seen red first. Hook cases run without
`CLAUDE_PROJECT_DIR`, from their payload alone; fixtures carry no real
values.

- **Unit**: hook cases with crafted payloads (main vs subagent, marker on and
  off, paths inside and outside `.sdlc/`); `file_contains` and `max_lines`
  cases for agents, template and skill.
- **Integration**: clean install into a temp `HOME`; full suite.
- **Manual verification** (after install, by the developer): one short
  session with `claude --model claude-fable-5-2` then `/orchestrate`, one
  small task end to end; check that Fable sees only the integrator's
  artifact.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh status-line.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<name> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile --verbose
```

## Implementation risks

- The guard can lock the main session out of the work it must do (writing
  `context.md`, plan Status): the `.sdlc/` exception is tested in 125f.
- `subagent-report-check` and `task-actuals` both run on SubagentStop; the
  order between them is not guaranteed, so T6 writes `cost` after the check
  without depending on its order.
- Nested agents' reports never reach the main session: if the integrator
  drops a blocking finding from its artifact, Fable does not see it. The
  integrator's rule says `blocked` and `red` findings go into the summary.
- The `production-gate` gotcha in `CLAUDE.md`: write docs with Write/Edit,
  not heredocs.

## Review

Filled in Deploy. A plan is not closed while this section is empty.

- **bugs**: self-review, 1 fixed: the guard blocked `calibrate.sh`, which the main session needs to estimate the plan; now allowed, with a case.
- **security**: self-review, no findings: the guard rejects chaining, redirection, `..`, symlinked dirs outside `.sdlc/`, `-c` and external diff tools; markers are created exclusively, never through a link.
- **conformance**: R1–R8 each have cases (125a–125u). Two documented changes: the main session cannot delete `work/`, so the last integrator task does; and promoting to the repo's `CLAUDE.md` goes through the integrator.

Waiver: no `verifier` or `reviewer` subagents ran. The build was done from a remote session on the developer's folder, without Claude Code's agents (maintainer to decide whether to run `/sdlc` review before committing, 2026-11-18).

## Estimate vs actual

Filled at Build close from `.sdlc/fable-orchestrator/actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation | Cause |
|---|---------|-----|--------|-----------|-------|

Not measured: the tasks ran in a remote session editing the folder, not in
Claude Code on the developer's machine, so `task-actuals` recorded nothing.
`calibrate.sh` history is unchanged.

Suite (repo mode, run in chunks): 395 cases, 392 pass. The 3 that fail
(110a `EVALS_RESULT_JSON`, 122h `bash-file-check` failure event, 123c
coalescing) fail the same way on a `git archive HEAD` copy in the same
environment: not caused by this change. Installed mode in a temp `HOME`:
every chunk green except 123c, and the 122 chunk did not finish in the time
limit (it stalls on a `bash-file-check` case, not touched here).

## Outside this plan

- The trial in 3 to 5 sessions and the decision in `intent.md`.
- Tuning the "expensive" threshold with that data.
- Making the mode the default.

Git is reserved for the developer: the change is left in the working tree.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.

# Plan: Agent turn budgets (A1–A5)

- **Derived from**: `../delegation-hardening/spec.md` (requirements A1–A5,
  decisions D2, D6, D7)
- **Status**: APPROVED BY ENGINEER (2026-11-16, "Apruebo los planes")
- **Nothing is implemented until this file is approved.**

## Done means

`bash evals/run.sh` FAIL 0 with the new cases `118*` seen red first;
`implementer` and `verifier` at `maxTurns: 60`; the four agents say what to
leave when they are cut; the `sdlc` skill says to resume a subagent whose
output comes back partial.

**Decision after T1 (developer, 2026-11-16, "Límite holgado + parcial"):** no
turn-warning hook. The subagents docs say that at `maxTurns` "Claude Code
returns its output marked as partial, and Claude can resume it" (v2.1.246+);
"Building effective agent automations" (claude.dev, 2026-10-08) advises a cap
of three to five times a normal run, tightened with real numbers. T2 and T3
are struck; T4 also raises `verifier` to 60; T5 adds the resume step.

## Stop and ask if

- T1 finds `PostToolUse` does not carry `agent_type` or `agent_transcript_path`
  for subagent calls, or its `additionalContext` is not documented to reach the
  subagent: stop before T2; the developer chooses wording-only or another event.
- An existing case other than `101d` must change.
- The task needs to open windows or apps on the developer's screen.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | Spike: in the official Claude Code hooks reference, find whether `PostToolUse` inside a subagent carries `agent_type`, `agent_id`, `agent_transcript_path`, and whether `additionalContext` reaches the subagent. Then a live check: a throwaway `PostToolUse` hook logging its payload to the scratchpad while a `scout` runs one lookup. Write findings with URLs at the end of this plan. | `.sdlc/agent-turn-budgets/plan.md` | Each answer cites a URL or the logged payload, or says "not documented" | A1 | main | — | 4m/1.5M | done (cause: two extra doc reads, a claude.dev check the developer asked for, and a question to the developer; findings below) |
| T2 | `hooks/turn-budget.sh`: `PostToolUse`; exit 0 at once unless `agent_type` ∈ {implementer, verifier, reviewer, scout}; read `maxTurns` from `<hook dir>/../agents/<type>.md`; count assistant messages in `agent_transcript_path`; at ≥ `maxTurns − 8` emit `additionalContext` once (marker `${TMPDIR:-/tmp}/claudio-turns-<agent_id>`, id validated as `[A-Za-z0-9_-]+`). Scenario script and case, red first. | `hooks/turn-budget.sh`, `evals/scripts/turn-budget-test.sh`, `evals/cases/118a-turn-budget.json`, `evals/fixtures/turn-budget/` | `118a` scenarios: limit−8 warns; limit−9 silent; second call silent; unknown type silent; bad `agent_id` silent; missing transcript silent; never exit ≠ 0 | A2 | implementer | T1 | 3m/200k | struck (decision after T1) |
| T3 | Register `turn-budget.sh` in `settings.template.json` under `PostToolUse` (matcher `.*`); check `install.sh` merges it. | `settings.template.json`, `evals/cases/118b-hook-registered-turn-budget.json` | `118b` red first; `evals/scripts/install-test.sh` green | A2 | implementer | T2 | 2m/160k | struck (decision after T1) |
| T4 | Agents: `implementer.md` `maxTurns: 60`; in all four agent files the sentence "If you are told your turns are running out, stop and write your report with what is done and what is left." `scout.md` description: one lookup question, not audits or reviews (those go to `reviewer` or `main`). `verifier.md`: order is change behavior, adjacent flows, then the suite unless its result was given in the prompt. | `agents/implementer.md`, `agents/verifier.md`, `agents/reviewer.md`, `agents/scout.md`, `evals/cases/101d-implementer-max-turns.json`, `evals/cases/118c*.json` | `118c1–c4` (sentence per agent), `118c5` (scout size), `118c6` (verifier order) red first; `101d` updated to `maxTurns: 60` (replaced test, below) | A3, A4, A5 | main | — | 3m/1.2M | done (cause: needles wrapped across lines, rewrapped; `verifier` to 60 too and `75c` replaced, per the T1 decision; 118c1–c6 red then green, suite 299/0) |
| T5 | `skills/sdlc/SKILL.md` Stage 4: `main` runs the suite once and passes its result to the `verifier`. | `skills/sdlc/SKILL.md`, `evals/cases/118d-sdlc-suite-on-main.json` | `118d` red first | A4 | main | T4 | 2m/1.2M | done (cause: SKILL.md hit its 160-line budget; dropped the two `---` separators instead of raising it; resume line added per T1 decision; 118d1–d2 red then green, now 157 lines) |

Estimates from `calibrate.sh` (2026-11-16): repo medians implementer
2.0m/156k, main 3.1m/1.2M. T1 sized above (docs plus a live check).

## Replaced tests

| Case | Before | After | Why |
|------|--------|-------|-----|
| `101d` | `maxTurns: 40` | `maxTurns: 60` | Decision D2, approved in the spec |
| `75c` | `maxTurns:` (any) | `maxTurns: 60` | Decision after T1: `verifier` to 60 too |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1, T4 | 4m | read T1 findings: stop or go |
| 2 | T2, T5 | 3m | `git diff --stat` |
| 3 | T3 | 2m | `bash evals/run.sh` |

- **Estimated wall-clock**: ~10m (+ main checks)
- **Sequential sum**: 14m
- **Estimated tokens**: ~4.3M

## Test strategy

Red first for every new case. `118a` is a scenario script with transcript
fixtures of the real shape (one JSON line per message). Verification and
review of the four slugs run together in `plan-template-gates`.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh
bash evals/run.sh
```

## Implementation risks

- `PostToolUse` on every tool adds a process per call to every session; the
  early exit must come before any file read.
- The transcript's message count may not match the harness's turn count:
  warning at 8 left absorbs the drift.

## T1 findings (2026-11-16)

Source: https://code.claude.com/docs/en/hooks (read as `hooks.md`).

1. **Tool hooks fire inside subagents** and carry `agent_id` and
   `agent_type`, which are common input fields ("When a subagent calls a
   tool, tool events such as `PreToolUse` and `PostToolUse` fire the same
   configured hooks", section *Hook locations*).
2. **`agent_transcript_path` is documented only for `SubagentStop`**, not for
   tool events. The *Stop and ask if* condition fired: T2 as written (count
   messages in the subagent transcript) has no documented input.
3. **`PostToolBatch`** fires "exactly once with the full batch" of parallel
   calls, before the next model request, so once per model turn. It has no
   matcher and accepts `additionalContext`, inserted "next to the tool result".
   A counter per `agent_id` on this event counts turns without reading any
   transcript.
4. **`additionalContext`** is inserted "into the conversation at the point
   where the hook fired"; that it lands in the subagent's own context is an
   inference, not stated.
5. Nothing in the hook input gives `maxTurns` or a turn count.

Not verified live: no throwaway hook was registered. Doing so means changing
the settings a running session reads; left to the developer.

## Outside this plan

Release, verification and review: `plan-template-gates` T6–T10.

## Review

Covered by the review of all four slugs: see `../plan-template-gates/plan.md`, *Review*.

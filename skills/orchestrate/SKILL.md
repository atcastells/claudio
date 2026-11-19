---
name: orchestrate
description: Orchestrate mode for the session — the main session (ideally Fable 5.2, chosen at session start) plans and decides, the integrator agent (Opus 5.5) does the work and launches the other agents, and they talk only through artifacts in .sdlc/<slug>/work/. /orchestrate [<chain dir>] turns it on, /orchestrate off turns it off, /orchestrate allow-test <file> approves weakening one test. Only the user switches modes.
disable-model-invocation: true
---

# Orchestrate mode

The artifact chain of the `sdlc` skill still applies: intent, spec, an
approved plan. What changes is who does the work. The `mode` hook records
`/orchestrate` and `/orchestrate off`; the status line shows `Orch`.

## Roles

- **Main session** (Fable 5.2 chosen at start; on Opus the cost split does
  not apply, the mode says so): writes the chain, delegates each task to the
  `integrator`, reads its artifact, decides. It does not explore, edit code
  or run tests: `orchestrator-guard` allows only the chain, read-only git
  (also `git -C`, chained or piped into head/tail/grep/wc), `git add/commit/push`
  (the developer confirms), `calibrate.sh` and `clean.sh`. No `advisor`: it
  would advise Fable with Fable; if it is on, ask the developer for `/advisor off`.
- **Active chain**: the chain may live in another repo than the session;
  `/orchestrate <dir>/.sdlc/<slug>` or the first write to it records it.
- **integrator** (Opus 5.5): integrates, edits unclear code, launches
  `implementer`, `verifier`, `reviewer` and `scout`; only its artifact
  reaches you. Plan task IDs carry no letter: `T3a`, `T3b` are its nested
  agents, and their cost is added to `T3`.

## Delegating

One prompt per task: `[sdlc:<slug>/T<n> est=<min>m/<ktok>k]`, then the path
of a `brief` when it needs more than its plan row. Only `T0` (inspection
for the spec) runs before the plan is approved: the guard blocks `T1`+ while
`plan.md` says draft. Prior chains and design docs are read in `T0`, not by
you: read `context.md`, handoff summaries, artifacts. Group small changes
(each task is a cold start); launch a wave in one message.

## Reading an artifact

Frontmatter and summary only. Open one cited file:line per artifact, and
every citation of a `blocked` or `needs-decision` one. `needs-decision` is
the integrator handing you a question it must not settle (`integrator.md`,
*Escalate*): decide it yourself, or ask the developer when it changes the
goal; never send it back unanswered. `cost` is measured by a hook; `data`
and `regen` say what it is and whether it can be had again.

## Persist or discard

Discard is the default. An artifact is useful later only if it records a
decision and its reason, a later task or session will read it, or it is
evidence for human review. Then cross it with the cost of getting it again
(`regen`, `cost`; expensive = over $0.50 or 10 agent minutes, a starting
value to tune):

| | Cheap to regenerate | Expensive or not reproducible |
|---|---|---|
| Useful later | Only the regen command and one line in context.md | Persisted, condensed, at its data type's destination |
| Not useful later | Discarded now | Kept in work/ until the stage closes, then discarded |

| `data` | Destination when persisted |
|---|---|
| decision | `.sdlc/<slug>/decisions/NNN-<topic>.md` and one line in `context.md` |
| repo-knowledge | `context.md`; the repo's `CLAUDE.md` if it outlives the slug (ask first; the integrator edits it) |
| evidence | `.sdlc/<slug>/review/` |
| measurement | `.sdlc/<slug>/` when it backs a decision; otherwise discarded |
| exploration | one line in `context.md`, then discarded |

raw-output is never persisted: keep its `regen` instead. Persisting means
condensing what is needed, not copying the file. Same data rule as
`Learned:`: the shape of the data, never values.

On compact or resume, `plan-resume` lists delegated tasks with no artifact
back: relaunch each with its tag and brief (absolute paths across repos).

## Closing

`.sdlc/<slug>/work/` is git-ignored: the resume point while Build is open.
When it closes, `bash ~/.claude/skills/orchestrate/clean.sh` empties it.
Evidence stays in `review/`. Commit from the main session with
`git commit -F .sdlc/<slug>/work/commit.txt` (no quotes or `$` in commands).

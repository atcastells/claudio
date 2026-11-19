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
  not apply, the mode says so): writes the chain (`plan.md`, `context.md`,
  status, small edits), delegates each task to the `integrator`, reads the
  artifact it returns, decides what to persist. It does not explore, edit
  code or run tests: `orchestrator-guard` allows only the chain, read-only
  git (also `git -C <dir>`), `git add/commit/push` (the developer confirms),
  `calibrate.sh` and `clean.sh`.
- **Active chain**: the chain may live in another repo than the session.
  `/orchestrate <dir>/.sdlc/<slug>` records it; so does the first write to
  an existing chain. Hooks find it there (guard, `task-actuals`, resume).
- **integrator** (Opus 5.5): integrates, edits unclear code, launches
  `implementer`, `verifier`, `reviewer` and `scout`, and answers with one
  artifact. Only its artifact reaches the main session.
- In this mode plan task IDs carry no letter: `T3a`, `T3b` are the
  integrator's nested agents, and their cost is added to `T3`.

## Delegating

One prompt per task: `[sdlc:<slug>/T<n> est=<min>m/<ktok>k]`, then the path
of a `brief` artifact when the task needs more than its plan row. Group
small changes into one task: each delegation costs the integrator a cold
start (context, plan, files). Launch a wave's tasks in one message.

## Reading an artifact

Read the frontmatter and the summary, never the whole body by default. Open
one cited file:line per artifact, and every citation of a `blocked` or
`needs-decision` one, before acting on it. `cost` is measured by a hook;
`data` and `regen` tell you what it is and whether it can be had again.

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
back: relaunch each with its tag and brief (absolute paths when the chain
is in another repo).

## Closing

`.sdlc/<slug>/work/` is git-ignored: the resume point while Build is open.
When it closes, `bash ~/.claude/skills/orchestrate/clean.sh` empties it.
Evidence stays in `review/`. Commit from the main session with
`git commit -F .sdlc/<slug>/work/commit.txt` (no quotes or `$` in commands).

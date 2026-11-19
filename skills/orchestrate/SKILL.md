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

- **Main session** (Fable 5.2 chosen at start): writes the chain, delegates
  each task to the `integrator`, reads its artifact, decides. The guard allows
  it the chain, read-only git (chained or piped into head/tail/grep/wc),
  `git add/commit/push` (the developer confirms), `calibrate.sh`, `clean.sh`.
  No `advisor` (Fable advising Fable): if on, ask for `/advisor off`.
- **Active chain**: the chain may live in another repo than the session;
  `/orchestrate <dir>/.sdlc/<slug>` or the first write to it records it.
- **integrator** (Opus 5.5): integrates, edits unclear code, launches
  `implementer`, `verifier`, `reviewer` and `scout`; you launch only it and
  `scout`, review rows too. Only its artifact reaches you.
  Plan task IDs carry no letter: `T3a`, `T3b` are nested, cost added to `T3`.

## Delegating

One prompt per task: `[sdlc:<slug>/T<n> est=<min>m/<ktok>k]`, then the path
of a brief from `~/.claude/skills/sdlc/templates/brief.md` (at most 20 lines)
when the plan row is not enough. Only `T0` (inspection for the spec) runs
before the plan is approved: the guard blocks `T1`+ while `plan.md` says draft.
Prior chains, design docs and code are read in `T0`, not by you.

You decide, the integrator writes: your decisions go one line each in a
brief, and a `T0` drafts or amends spec.md and the plan prose from them and
its file:line facts (a gap is a follow-up `T0`, not a read). You read the
result and correct it with short edits. A hook sets the Status of delegated
rows (`in progress`, then the artifact's `result`): edit only main rows.

## Reading an artifact

Frontmatter and summary only: the guard lets you Read artifacts, `review/`
and code with `limit` 40 at most. Open one cited file:line per artifact, and
every citation of a `blocked` or `needs-decision` one. `needs-decision` is
the integrator handing you a question it must not settle (`integrator.md`,
*Escalate*): decide it yourself, or ask the developer when it changes the
goal; never send it back unanswered: continue that integrator with
`SendMessage` and your decision, so the hook closes the row.

## Persist or discard

Discard is the default. Useful later = a decision and its reason, read by a
later task or session, or evidence for human review. Cross it with the cost
of getting it again (`regen`, `cost`; expensive = over $0.50 or 10 minutes):

| | Cheap to regenerate | Expensive or not reproducible |
|---|---|---|
| Useful later | Only the regen command and one line in context.md | Persisted, condensed, at its data type's destination |
| Not useful later | Discarded now | Kept in work/ until the stage closes, then discarded |

| `data` | Destination when persisted |
|---|---|
| decision | `.sdlc/<slug>/decisions/NNN-<topic>.md` and one line in `context.md` |
| repo-knowledge | `context.md`; if it outlives the slug, the `CLAUDE.md` of the module it applies to (the root one only when repo-wide); the integrator edits it |
| evidence | `.sdlc/<slug>/review/` |
| measurement | `.sdlc/<slug>/` when it backs a decision; otherwise discarded |
| exploration | one line in `context.md`, then discarded |

raw-output is never persisted: keep its `regen` instead. Persisting means
condensing, not copying; the shape of the data, never values.

On compact or resume, relaunch each task `plan-resume` lists, same brief.

## Closing

`.sdlc/<slug>/work/` is git-ignored: the resume point while Build is open.
When it closes, `bash ~/.claude/skills/orchestrate/clean.sh` empties it.
Evidence stays in `review/`. Commit from the main session with
`git commit -F .sdlc/<slug>/work/commit.txt` (no quotes or `$` in commands).

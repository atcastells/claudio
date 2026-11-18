# Spec: fable-orchestrator

Traces to `intent.md`.

## Requirements

- R1. A per-session opt-in mode: `/orchestrate` turns it on, `/orchestrate
  off` turns it off; it survives compaction and resume and is cleared on
  startup and clear, like Vibe. The status line shows it. It is independent
  of Spec/Vibe: the artifact chain still applies. It is chosen at the start
  of the session, with Fable 5.2 as the model, because a model switch
  mid-session rewrites the cache. (decision 1)
- R2. In this mode the main session neither explores, edits nor runs tests:
  a hook blocks Edit, Write, NotebookEdit and Bash in the main session
  except writes under `.sdlc/<slug>/` and read-only git. Subagents are not
  affected. (19% tests, 69% reruns as main)
- R3. A new `integrator` agent (Opus 5.5, effort medium) is the only agent
  the main session launches in this mode. It integrates, edits unclear
  code, and launches `implementer`, `verifier`, `reviewer` and `scout`
  (nested level 2) with the same rules as today. Those four cannot launch
  agents (`Agent` in `disallowedTools`), so the chain stays at two levels.
  It inherits the implementer's failure budget, filtered tests and log in a
  file. (decision 2)
- R4. Every result back to the main session is an artifact under
  `.sdlc/<slug>/work/` with a fixed frontmatter (`task`, `from`, `kind`,
  `result`, `data`, `cost`, `regen`, `persist`, `files`, `evidence`) and
  three parts: a summary of at most 15 lines, the decision needed (only for
  `needs-decision`), and the detail. The final message is
  `ARTIFACT: <path>` plus the frontmatter and the summary. (decision 3)
- R5. `cost` is measured, not estimated: tokens, dollars, minutes and agent
  count of the integrator plus the nested agents it launched, written into
  the frontmatter by a hook from what `task-actuals` measures. (decision 3)
- R6. `subagent-report-check` sends an integrator report back when it lacks
  `ARTIFACT:`, the file does not exist under `.sdlc/<slug>/work/`, or the
  frontmatter misses a required field.
- R7. Persistence rule, in the new skill: discard by default; persist only
  what records a decision and its reason, will be read by a later task or
  session, or is evidence for human review. Crossed with the cost of
  regenerating it: useful and expensive → persisted, condensed, at the
  destination of its `data` type; useful and cheap → only the `regen`
  command and one line in `context.md`; not useful and expensive → kept in
  `work/` until the stage closes; not useful and cheap → discarded at once.
  `raw-output` is never persisted. Main condenses; it does not copy files
  whole.
- R8. `.sdlc/*/work/` is git-ignored in configured projects (`/repo-setup`
  template and migration `3.4.0`); `work/` is emptied when Build closes and
  is the resume point if a session stops before.

## Out of scope

- Making the mode the default: only after the measurement in `intent.md`.
- Changing the current mode: Opus main with `/advisor` stays as it is.
- Agent teams and separate headless sessions.

## Policy

Persisted artifacts follow the `Learned:` rule: the shape of the data, never
values; no personal data, credentials or sensitive business data.
`global/CLAUDE.md` does not grow (75-line budget). `skills/sdlc/SKILL.md` is
at its 160-line budget (case 79), so the mode lives in a new
`skills/orchestrate/SKILL.md` and the sdlc skill only points to it, without
adding lines.

## Release

MINOR (3.4.0): new mode, agent, hook and template, and a project template
change, so it ships `migrations/3.4.0.md`.

# Intent: Orchestrate hardening (3.5.0)

Status: approved by the developer (2026-11-19); implemented in 3.5.0, not committed.

## Why

First real delivery in Orchestrate mode (chain in one repo, session in
another, main session on Opus 5.5). The task split, integrators that cite
file:line and the three-pass review worked. Eight limits cost time; below,
each with its verified cause and the proposed change. Every change gets its
eval, seen red first.

## Causes found (verified in the code)

| # | Limit | Cause |
|---|---|---|
| 1 | Main session cannot write the chain in another repo, nor after a `cd` into `.sdlc/` | `orchestrator-guard.sh` only allows `${cwd}/.sdlc/<slug>/`, with `cwd` taken literally. With cwd = `repo-a/.sdlc/<dir>` the base becomes `.../.sdlc/<dir>/.sdlc/`, so even that repo's own chain is blocked. |
| 2 | No git path to close a delivery | The guard allows only `git status|diff|log|blame|show` as the first word, so `git -C <repo> status` fails. `settings.template.json` denies `git add/commit/push` for everyone. |
| 3 | Approvals do not reach subagents | `rm -r *` and `rm -rf *` are in `permissions.deny`: absolute, no approval can lift them, in main or in a subagent. `test-guard` has no way to receive "the developer approved removing this test". |
| 4 | Evidence in `/tmp`; `review/findings.md` blocked | `agents/integrator.md` step 4 sends logs to `/tmp/claudio-test-*.log`. `reviewer` and `verifier` have no Write tool. The `findings.md` block is most likely limit 1 (the main session writing a chain in another repo). |
| 5 | No `actuals.jsonl` | Reproduced: `task-actuals` SubagentStop writes only if `${cwd}/.sdlc/<slug>/` exists. The payload cwd is the session's repo, the slug lives in another: the record is dropped, and the machine log too, because it is written after that check. Same for `stamp_cost` (no `cost:` in the artifacts) and the PostToolUse branch for `Runs on: main`. The tag parser is fine. |
| 6 | Cold start per delegation; T15 stopped on restart | By design every change goes through an integrator. Nothing on SessionStart looks at `work/` for tasks left half done. |
| 7 | Parallel agents on one file rely on the prompt | The plan has no shared-files mark and no hook watches it. |
| 8 | Mode assumes Fable 5.2 in main | Hard-coded in `skills/orchestrate/SKILL.md` and in the `mode.sh` notice; nothing checks the real model. |

## Proposed changes

**A. Active chain (1, 4, 5, 6).** One source of truth for "which chain this
session works on": the orch marker `${TMPDIR}/claudio-orch-<sid>` stores the
physical path of the chain (`.../.sdlc/<slug>`), set by
`/orchestrate <path>` or by a new read-only-safe script
`~/.claude/skills/orchestrate/set-chain.sh <path>` that the guard lets the
main session run (it checks the path ends in `.sdlc/<slug>/` and holds
`plan.md` or `intent.md`). Then:
- the guard allows writes under the active chain (physical path, symlinks
  resolved) plus the repo's own `.sdlc/` taken from the git top level of
  cwd, not cwd itself (fixes the `cd` case);
- `task-actuals` and `stamp_cost` resolve the slug directory as: cwd's top
  level `.sdlc/<slug>/`, else the active chain when its basename is the slug;
  the machine log is written even when no chain directory is found;
- small chain edits (state, context) stay in the main session; no integrator
  needed for them.

**B. Git (2).** Guard: allow `git -C <path> <read-only verb>` (same verb list,
same `--ext-diff/--output/--textconv` block, `-c` rejected). For writes,
two options (decision below):
- B1 (recommended): keep closing outside the mode; the skill's Closing
  section says so and `/orchestrate off` is the documented last step.
- B2: the guard lets `git add/commit/push` through from the main session
  only (never from agents), so the permission system asks the developer.
  Requires moving them from `deny` to `ask` in the developer's settings.

**C. Scoped approvals (3).**
- Deletes: new `~/.claude/scripts/claudio-clean.sh <path>...`, allowed in
  settings, that deletes only inside `<chain>/work/` and
  `${TMPDIR}/claudio-*` (physical paths, no symlink escape); everything else
  stays denied. Integrator brief and closing step use it.
- Test removals: the developer types `/claudio allow test <file>` (only a
  typed prompt can create it, via the `mode` hook on UserPromptSubmit). That
  writes a one-shot, 30-minute marker for that session and file;
  `test-guard` accepts one weakening edit of that file from any agent of the
  session, then deletes the marker. Same caveat as the mode markers: a model
  with shell access could create the file in `/tmp`; documented.

**D. Durable evidence (4).** Integrator step 4: logs to
`<chain>/review/T<n>-<what>.log` (tail 200 lines) instead of `/tmp`;
`work/` keeps raw output. The integrator writes `review/findings.md` from
the reviewers' reports (they keep no Write tool).

**E. Resume (6).** `plan-resume` (SessionStart compact|resume|startup while
the orch marker holds a chain) lists the tasks whose `work/T<n>-brief.md`
or plan row "in progress" has no `T<n>-result|finding|decision-request`
artifact and tells the main session to relaunch them with their brief. A
hook cannot relaunch an agent itself; this makes it a one-step action.
Note: today `startup` deletes the orch marker; a resumed session (`resume`)
keeps it.

**F. Shared files (7).** Plan template: a `Shared` column (files more than
one task of a wave touch). New check in `orchestrator-guard` for agents
(today it exits on agent_id): on Edit/Write of a file listed as shared,
record `work/.edits/<hash>` = task + agent_id; if another task of the same
wave holds it, inject a warning (not a block): "T5 also edits mod.rs:
re-read it before this edit".

**G. Model (8).** Skill and notice say "a main session on a stronger or
pricier model than the integrator"; `mode.sh` reads the model on
SessionStart (payload `model`) and, when main runs the integrator's model,
adds one line: "main and integrator share Opus 5.5: the cost split does not
apply; consider Spec mode or a lighter integrator". `task-actuals` already
records the model per task, so calibration sees it.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-19 | Git: close outside the mode (B1) or in the main session (B2) | B2: main session only, through the permission prompt | developer |
| 2026-11-19 | Main session on Fable 5.2 or Opus 5.5 | Fable 5.2 stays the default; the mode stops depending on it (G) and the next deliveries are measured on both | proposed, pending |

Model facts behind the second row: in the session profile, mixed sessions
led by Fable 5.2 spent 4.2 M cost-weighted tokens per agent hour against
8.0 M for Opus 5.5 (6 against 114 sessions, before this mode existed: a
correlation). In this mode the main session mostly re-reads a cached
context, priced the same on both (0.2 $/M cache read), so the price gap
narrows; what is left is decision quality. That delivery left no actuals (limit 5),
so there is no measurement of the mode on either model yet.

## Out of scope

Automatic relaunch of agents, locks that block parallel edits, any change
to repos other than this one.

## Release

3.5.0 (new behavior). `migrations/3.5.0.md` only for the plan template
column. `settings.template.json` changes (clean script allow; B2 if chosen)
need `./install.sh`, which the developer runs.

## As implemented (differences from the proposal)

- Active chain: also recorded by the first main-session write to an existing
  chain, so no script is needed; `set-chain.sh` was dropped.
- Test approval: `/orchestrate allow-test <file>` (an unknown slash command
  would not reach the hook), valid 30 minutes for that file, not one edit.
- Git writes from the main session are answered by the guard with
  `permissionDecision: ask`, so `git -C <dir> commit`, which no permission
  rule matches, is confirmed too. The project settings template moves the
  three verbs to `ask` as well (migration 3.5.0): a project deny would win.
- Shared files: a `(shared)` mark in the Files cell instead of a column; the
  warning fires for any file two agents of the active chain edit within an
  hour, marked or not.

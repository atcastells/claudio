# Intent: File edits made through Bash skip the workflow's file hooks

- **Originator**: maintainer
- **Date**: 2026-11-16
- **Status**: approved by product owner (2026-11-16, "Aprobado, sigue")
- **Slug**: bash-edits-skip-hooks

## The problem, in the originator's words

Translated from Spanish:

> "Right now most edits are made with Python instead of the coding agent
> editing a file by hand. Why? Check online why it does it that way."

Then, after the answer: "Yes, after 3.1.0" (open this intent).

## What we know

- **Why it happens.** In auto mode, Claude Code adds an instruction to the
  system prompt: do much of the work through Bash, including small,
  mechanical file changes with `sed`, heredocs or short scripts instead of
  Read, Edit or Write (Edit or Write only when a shell edit would be
  fragile). Seen directly in the system prompt of the session that wrote
  this intent. Claudio installs `"defaultMode": "auto"`
  (`settings.template.json`).
- **Public reports, no official explanation found** (2026-11-16): the
  instruction is described in claude-code issues #92178, #90599 and
  #94441 (it also reaches subagents and overrides CLAUDE.md rules); #89731
  notes it reverses 2.1.21, which made the model prefer Read/Edit/Write;
  #87575 (`/rewind` does not undo Bash edits); #94657 and a primeline.cc
  test (Edit|Write hooks never fire for Bash edits).
- **What it breaks in Claudio**, from `settings.template.json`:
  - `credential-guard.sh` and `test-guard.sh` match only
    `Write|Edit|MultiEdit|NotebookEdit`: a credential written, or a test
    changed to pass, through Bash is not checked.
  - `task-actuals.sh` matches only `Edit|Write|MultiEdit`: a `plan.md`
    status changed through Bash records no time. Seen in the 3.1.0 build:
    a row closed with `awk` was not measured until redone with Edit.
  - `evals-on-config-change.sh` (PostToolUse on Write/Edit) does not run
    for config changed through Bash.
- `production-gate.sh` is the only file-content check that already sees
  Bash, and 3.1.0 showed that filtering shell text without a parser fails
  open.

## Who it affects

Every repo with the workflow installed, every session in auto mode (the
default), and the subagents those sessions launch.

## What happens if we do nothing

The two guards that protect secrets and tests are bypassed by the editing
path the harness itself prefers, silently; estimates lose their `main`
measurements; and nobody notices, because nothing fails.

## How we will know it is solved

- A file written through Bash with a credential-shaped value is blocked,
  or the session is steered so that such a write goes through Write/Edit
  (an eval for each path).
- A `plan.md` status change in a measured session is recorded whatever
  tool made it.
- An eval reproduces each bypass first, red.

## Open questions

1. **Approach.** Steer the model (rule text: "edit files with Edit/Write,
   never with shell"; the auto-mode instruction pushes the other way), or
   guard Bash (extend `credential-guard` and `test-guard` to Bash commands
   that write files; parsing shell is fragile, as 3.1.0 showed), or check
   after the fact (a `PostToolUse` on Bash that diffs the tree against the
   guards), or a mix.
2. **Auto mode as the default.** Keep `"defaultMode": "auto"` in the
   template, or change it, knowing the cost in permission prompts.
3. **`task-actuals`.** Measure `plan.md` status changes from any tool, for
   example by reading the plan at `PostToolUse` on Bash too, or accept the
   gap and document "update Status with Edit" (already in the template).
4. Whether the auto-mode instruction is stable across Claude Code versions
   (not verified; the issues cite 2.1.234 to 2.1.273).

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.

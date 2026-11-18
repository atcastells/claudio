# Intent: The config-change evals hook never finishes

- **Originator**: maintainer
- **Date**: 2026-11-16
- **Status**: approved by product owner (2026-11-16, "Aprobado, sigue")
- **Slug**: evals-hook-timeout
- **Builds on**: 3.2.0 (uncommitted in the main checkout at the time of
  writing)

## The problem, in the originator's words

Translated from Spanish: "Do this task here: 'Fix evals-on-config-change
timeout vs suite length'." The task came out of the 3.2.0 review: the
developer chose to drop the evals run from `bash-file-check` and fix the
evals hook's timeout separately.

## What we know

- `hooks/evals-on-config-change.sh` (PostToolUse on
  `Write|Edit|MultiEdit|NotebookEdit`, `timeout: 15` in
  `settings.template.json`) runs the eval suite when a workflow config file
  changes: the installed `~/.claude` copies, or `global/`, `hooks/`,
  `skills/`, `agents/`, `evals/`, `migrations/`, `profiles/`,
  `settings.template.json` or `VERSION` in the source repo.
- The suite it runs (`EVALS_SKIP_REPO=1 bash evals/run.sh`, with the
  installed profile when there is one) took **111 s** on 2026-11-16 (333
  cases; a reviewer measured 85 s earlier the same day).
- The hooks reference (code.claude.com/docs/en/hooks, *Timeouts*): a
  command hook that reaches its `timeout` is cancelled and its output
  discarded. So, by the documentation, every run since the suite grew past
  15 s is killed and a red suite never reaches the model. Not observed live.
- The same reference offers two background modes for command hooks:
  `async: true` (no timeout enforced; `additionalContext` delivered on the
  next turn) and `asyncRewake: true` (timeout still enforced; on exit 2 it
  wakes Claude with the hook's stderr).
- Each config edit starts its own run; several edits in a row would start
  several 1–2 minute suites at once.

## Who it affects

Whoever edits the workflow with Claude: the maintainer in this repo, and
anyone who edits their installed `~/.claude` rules, hooks or skills.

## What happens if we do nothing

The playbook rule "the suite runs whenever CLAUDE.md, skills or hooks
change" holds on paper only: the local gate costs 15 s of CPU per edit and
reports nothing, so a config change that breaks a case is found only when
someone runs the suite by hand.

## How we will know it is solved

- A config edit that breaks a case is reported to the model within a
  bounded time, without the edit waiting for the suite.
- Several edits in a short burst run the suite once or twice, not once per
  edit.
- An eval reproduces each behavior first, red.

## Open questions

1. **Mode.** `asyncRewake` (wakes Claude on red, needs a timeout above the
   suite time) or `async` (no timeout, result on the next turn, green
   results can be reported too).
2. **Bursts.** Coalesce runs (one running, one pending at most) or let
   each edit run its own suite.
3. **Scope of the run.** The whole suite, or only the cases tied to the
   changed file (faster, but a mapping to maintain).
4. **Bash edits.** Should `bash-file-check` dispatch this hook again once
   it no longer blocks (the 3.2.0 review dropped it only because of the
   timeout).

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.

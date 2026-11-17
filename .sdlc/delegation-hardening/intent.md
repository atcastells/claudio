# Intent: Delegated execution that survives long, multi-layer tasks

- **Originator**: maintainer, from a handoff written by a session that ran
  eight plan tasks across two other repos over three days
- **Date**: 2026-11-16
- **Status**: approved by product owner (2026-11-16, "Aprobado, sigue":
  intent and the four-slug split)
- **Slug**: delegation-hardening

## The problem, in the originator's words

Translated from the handoff (Spanish):

> "The artifact chain (intent, spec, plan, approval) works and has prevented
> wrong work. What fails is delegated execution: the tasks the chain forces
> to be small do not fit changes that touch several layers, subagents run out
> of turns or lose their terminal halfway, and several rules ('red first',
> 'never skip a stage', 'under 100 lines') are broken systematically without
> anything detecting it."

Session figures reported by the handoff (counted on its transcript, not
re-verified here): 154 subagents, 19 stops on the turn limit, 5 subagents
that lost their terminal, 20 resumes via `SendMessage`.

## Evidence, checked against this repo (3.0.0)

Installed `hooks/` and `agents/` are identical to the repo, so every defect
below that lives in the repo still exists in 3.0.0.

| # | Handoff defect | Status here | Where |
|---|---|---|---|
| 1 | 40-turn limit cuts tasks mid-edit; no report | Confirmed: nothing tells the agent to report before the limit | `agents/implementer.md:7`, `agents/verifier.md:7` |
| 2 | Subagent loses its terminal ("adapter has no active turn") | Harness; cause unknown. Only a mitigation is repo work (start and kill a server in one command; cleanup on `SubagentStop`) | — |
| 3 | "Under 100 lines per task" not achievable for cross-layer types | The rule is personal, outside the repo (`~/.claude/rules/personal/`). Repo part: the `plan.md` template has no notion of a declared "seam" task or a row cap per task | `skills/sdlc/templates/plan.md` |
| 4 | "Red first" replaced by "mutation after"; tests born green | Confirmed: the report asks for `<red before>` but nothing checks it | `agents/implementer.md:54`, `hooks/subagent-report-check.sh` |
| 5 | Deploy stage never ran; no `REVIEW.md` | Partly covered: `/repo-setup` checks and offers `REVIEW.md`, Stage 5 offers it too. Gap: nothing stops closing a task without review or a written waiver | `skills/repo-setup/check.sh:102`, `skills/sdlc/SKILL.md:100` |
| 6 | Subagents cannot `rm`/`mv`; one moved a repo file out and could not return it | `rm` is under `ask`, not `deny`; only `rm -r`, `rm -rf`, `mv /*` are denied. Likely the same cause as #9. No rule says "copy, do not move, repo files" | `settings.template.json` |
| 7 | Report hook only accepts `T<n>` IDs | Confirmed, and the plan template uses `T<n>`; the session renamed rows. Either widen the pattern or say it in the template | `hooks/subagent-report-check.sh:24` |
| 8 | `cmd && git commit` denied as a whole | Behaviour of the permission matcher. Documenting it in core needs a line: core is at its 75-line budget | `global/CLAUDE.md` |
| 9 | `ask` rule becomes deny when nobody is there to click | Harness. A per-session "commits allowed on this branch" mode is not something the repo can build; a pending-commit queue might be | — |
| 10 | `production-gate` blocked a Rust file with `use crate::production::config` | Confirmed: the hook scans the whole command text, heredoc content included | `hooks/production-gate.sh:22` |
| 11 | `scout` (Haiku, 15 turns) asked for audits, delivered nothing | Confirmed limit; its description does not say what size of question it takes | `agents/scout.md:7` |
| 12 | Verifier spends its turns on the suite and skips the independent walk | Confirmed design: one agent does both | `agents/verifier.md` |
| 13 | Main-thread tokens not measured | Already built: `task-actuals.sh` measures plan rows whose "Runs on" is `main` when they move to "in progress" and "done". The session probably never marked `main` rows. Gap is discoverability, not code | `hooks/task-actuals.sh:10` |

Orchestration mistakes the handoff attributes to itself, with the rule it
proposes: a row cap per delegated task; "no figure reaches the user without a
run in which the measurement could fail"; a fixed planning question for UI
tasks, "may I open windows?".

What the handoff asks to keep: per-task `context.md`, early risk spikes, the
verifier writing its own client, "stop and ask" conditions in the plan, the
replaced-tests table, numbered-decision approvals, and the closing format.

## Who it affects

Anyone running plans with delegated subagents, most on long tasks that touch
several layers at once. In the reported session, most tasks from the fourth
onward.

## What happens if we do nothing

Each turn-limit stop costs a resume and a `git status` reconstruction; rules
that are broken every time lose their meaning; tests can ship green without
ever having failed; no change gets an independent code review.

## How we will know it is solved

- A subagent that hits its turn limit still returns a report the hook accepts.
- An implementer report without a literal red output (or an explicit,
  allowed mutation with its output) is sent back by the hook.
- `production-gate` does not block a write whose content mentions
  `production` in code.
- A plan can close only with a review pass or a written waiver.
- Each of these has an eval seen red first.

## Open questions

1. **Split.** This is too much for one plan. Proposed slugs, in no order
   (the originator has not set priorities):
   - `agent-turn-budgets` — #1, #11, #12 (report before the limit, scout
     scope, split verifier).
   - `report-hook-tdd` — #4, #7 (red evidence, ID pattern).
   - `permission-friction` — #6, #8, #10 (copy-not-move rule, scratch
     cleanup, git in its own command, `production-gate` scope).
   - `plan-template-gates` — #3, #5, #13 and the orchestration rules (seam
     tasks, row cap, review or waiver, `main` rows, "may I open windows?").
2. **Red first vs mutation.** Keep strict red-first and check it, or accept
   mutation-after as valid when its output is shown?
3. **Turn limits.** Is a warning at N turns left possible from a hook, or
   only by prompt wording? Raise `implementer` to 60?
4. **Core budget.** Where does "git always in its own command" go if core
   stays at 75 lines: an agent prompt, the `sdlc` skill, or swap a line?
5. **Harness items (#2, #9).** Report upstream, and which mitigation, if any,
   to build here.
6. **The personal 100-line rule (#3).** Changed through `/rules` by the
   developer, not by this plan.

Not verified (carried from the handoff): the cause of the adapter error;
whether `ask` rules apply live or need a restart; real tokens per task.

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.

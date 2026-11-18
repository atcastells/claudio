# Intent: Close the harness gaps two external references point at

- **Originator**: maintainer
- **Date**: 2026-11-10
- **Status**: draft — scope and open questions pending
- **Slug**: harness-hardening

## The problem, in the originator's words

> "check https://claude.dev/blog/safely-scaling-multi-agent-teams-with-fable-5-2/
> and https://x.com/mirku21/status/2098836008468992471 in order to improve
> the workflow. this repo should be linked to the github atcastells claudio
> repo."

## Who it affects

Every developer with the workflow installed, at Design (spec), Build (waves
of `implementer` subagents) and whenever a guard hook blocks a subagent.

## Facts found (sources, checked 2026-11-10)

Repository link: `origin` is already `https://github.com/atcastells/claudio`
(fetch and push); `gh repo view` confirms it exists, public, base `main`.
Nothing to change.

Source A: claude.dev, "Safely scaling multi-agent teams with Fable 5.2".
Read through a summarizing fetch; figures are the article's, not verified.

- A1. One lead and 999 helpers coordinated only through Git and a shared
  database; no messaging tools. Each agent had its own branch; a separate
  job merged into main and rejected conflicts.
- A2. The gateway tagged every request with the agent's identity from
  outside the sandbox, so an agent cannot claim to be another.
- A3. A monitor blocked tool calls; a block stops the team and a person
  reviews before restarting. A block on a helper removed only that helper.
- A4. The action monitor does not read the agent's reasoning, so the
  reasoning cannot persuade it.
- A5. Agents give up early and misjudge difficulty: helpers called 47 of 60
  statements unfeasible and the team later proved most of them after the
  lead reassigned helpers.
- A6. The hardest statement was done as a task tree any helper could extend
  when a piece was too large (2,418 tasks, 10 levels).
- A7. The harness sent the lead 19 automatic reminders of the time left.

Source B: X article "Harness Engineering: How to Build AI Workflows That
Never Fall Apart" (linked from the post). x.com returned HTTP 402; read
through a public mirror API and a summarizing fetch, not the original page.
Its figures carry no source in the article.

- B1. Every request becomes a contract: deliverable, constraints, non-goals,
  acceptance criteria.
- B2. A compact map, not an encyclopedia; memory in durable files.
- B3. Sensors before autonomy: the harness, not the model, decides a pass.
- B4. Double encoding: every rule in text and behind a mechanical gate.
- B5. Failure escalation: the same error twice stops autonomous editing,
  shows the exact log and waits; at most four attempts before a human.
- B6. Two passes on hard reasoning: the draft lists every assumption it
  made; a separate skeptical pass lists the flaws before a corrected version.

## What Claudio already covers

- B1, B2: `intent.md` → `spec.md` (acceptance criteria, Out of scope) →
  `plan.md` (Done means, Files per task, Outside this plan); `CLAUDE.md`
  Structure; `context.md`; the *Status* column as resume point.
- B3, A4: `test-guard`, `credential-guard`, `production-gate`, the
  `verifier`, the eval suite; hooks are deterministic and read payloads only.
- A2: `task-actuals` measures time and tokens; the agent only explains.
- A7: plan hints in the status line.
- B6 on the diff: three `reviewer` passes at Stage 5;
  `subagent-report-check` demands a demonstration for IMPORTANT findings.

## Gaps observed (candidates, not yet agreed scope)

- G1 (B5). No failure budget. Nothing says when to stop retrying the same
  red test; `agents/implementer.md` has `maxTurns: 40` as its only limit, and
  the plan template's "Stop and ask if" is free text.
- G2 (B4, A1). "Edit only the files in the task's Files cell" is text only.
  The main session compares `git diff --stat` after the wave; nothing blocks
  the write when it happens.
- G3 (B6). The spec and the plan reach the human with no adversarial pass
  and no list of assumptions; review starts at Stage 5, on the diff.
- G4 (A5). `RESULT: blocked` is accepted as reported.
  `subagent-report-check` checks the header, not that a blocked report says
  what was tried and what the output was.
- G5 (A6). An implementer that finds its task too large can only stop. Its
  report has no field to propose a split (`T3a`, `T3b`) for the main session
  to accept into `plan.md`.
- G6 (A3). When a guard hook blocks a subagent, nothing tells the subagent
  to stop instead of looking for another route, and nothing surfaces the
  block to the developer at the end of the wave.

## What happens if we do nothing

- A subagent can spend its 40 turns on one failing test, and the cost shows
  up only afterwards in `actuals.jsonl`.
- A write outside a task's files is found after the wave, when a parallel
  task may already have built on it.
- Wrong assumptions in a spec are found at Stage 5, after the build was paid.
- Tasks reported as blocked are dropped or redone by the main model without
  checking whether the block was real.

## How we will know it is solved

- Each agreed gap has its rule in text, its mechanical gate where one is
  possible, and an eval seen red first.
- Suite green, with the profile too; budgets of `global/CLAUDE.md` kept
  (core ≤ 75 lines, today exactly 75).

## Open questions

- Which of G1–G6 enter this change, and whether as one slug or several.
- G1: the thresholds. The article gives "twice with the same error" and
  "four attempts" without reconciling them. Can a hook count attempts from
  its payload alone, or is this a text rule plus a report field?
- G2: is the task tag available to a `PreToolUse` hook inside a subagent,
  so the hook can read the task's Files cell? Not checked yet.
- G3: who runs the pass (`reviewer` with a new `spec` pass, or the main
  session), and whether it applies in Vibe mode.
- G6: does a guard block inside a subagent stop only that subagent, or the
  wave?
- A1 keeps parallel implementers on separate branches; Claudio runs them in
  one tree with disjoint files (decided in `parallel-plans`). Reopen or not?
- This is a MINOR release if templates change (needs a migration file).

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.

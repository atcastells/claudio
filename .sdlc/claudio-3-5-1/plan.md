# Plan: claudio-3-5-1 (Orchestrate fixes seen in the S1-T3 session)

- **Derived from**: review of the live ASTRA S1-T3 session (Fable 5.2 main,
  2026-11-19) plus the K013 and S1-T2 chains. No spec yet: each row names the
  evidence it comes from.
- **Status**: APPROVED BY ENGINEER (Aaron, 2026-11-19: "perfecto", plus T10 and T11)
- **Built by**: a Claude cloud thread editing the developer's checkout through folder access; git and `./install.sh` stay with the developer.

## Evidence and corrections to the first summary

| # | Seen | Where | Cause found in the code |
|---|------|-------|-------------------------|
| E1 | 4 guard blocks in the first minute: two chained git reads (`;`, `\| tail`), `git branch -a --contains`, `git ls-files` | live transcript 08:56 UTC | `orchestrator-guard.sh:107` rejects any `;&\|$<>()`; `:118` allows only status, diff, log, blame, show |
| E2 | T1 (baseline) launched with `plan.md` still `Status: draft`, no approval message | live transcript 09:11 | `skills/orchestrate/SKILL.md` says "an approved plan" but nothing checks it; T0 (pre-plan inspection) is legitimate |
| E3 | Main read whole spec, plan and context of S1-T2 plus the S1 design doc: 5.4M cache read, 562k cache write, 160k output in 15 min | live transcript | The skill limits reading for integrator *artifacts*, not for prior chains during Plan |
| E4 | Nested estimates 3m/400k (implementer) and 5m/300k (scout); actuals median ~0.8m/130k and ~0.25m/100k. Estimates are **3–5x too high**, not too short. 100 % of rows flagged | S1-T2 and S1-T3 `actuals.jsonl` | `agents/integrator.md:29` asks for `est=` on nested prompts but gives no source; the integrator never runs `calibrate.sh` |
| E5 | Main rows have no `usd_min`, and main is the most expensive model (Fable) | S1-T2 `actuals.jsonl` T0/T19/T22 | `task-actuals.sh` `post_tool_use` builds the main record without the price table that `subagent_stop` uses |
| E6 | test-guard blocked removing a duplicated assertion (T21b) | S1-T2 actuals cause | `test-guard.sh:47-50` compares assertion counts only, so any dedupe looks like weakening |
| E7 | `sed -i` failed on macOS in T9 and skipped the red step | S1-T2 actuals cause | No BSD/macOS note in `agents/implementer.md` |
| E8 | Reviewer evidence lost: K013 T15 findings "not written to disk", reconstructed later; S1-T2 fuzz evidence left in the session scratchpad | K013 and S1-T2 `review/findings.md` | `integrator.md` step 6 says to write `findings.md`, nothing checks it |
| E10 | Escalation exists as `result: needs-decision` / `kind: decision-request`, but `integrator.md` gives no criteria for when a doubt is the main session's call | `agents/integrator.md`, `templates/artifact.md` | Only "You do not decide scope" |
| E11 | Fable main called the `advisor` tool (advisor model also Fable) | live transcript | `advisor` is a server tool: PreToolUse hooks never see it, so only the mode notice and the skill can stop it |
| E9 | Scouts nested in the integrator record 0.2–0.3 min with 56k–135k tokens | S1-T3 `actuals.jsonl` T0a–T0e | **Unconfirmed.** The method (first/last transcript timestamp) gives a correct 7.4 min for the integrator; fast Haiku scouts may be real |
| — | ~~Duplicated null rows in actuals~~ | — | **Not a bug**: they are the `{"event":"start"}` markers of main tasks (`task-actuals.sh`), my reader only printed the other fields |

## Done means

- Every row has its eval in `evals/cases/`, seen red first; `bash evals/run.sh`
  green; `scripts/check-public.sh` exits 0.
- `skills/orchestrate/SKILL.md` stays ≤ 80 lines (case 125n; it is at 79 now).
- `VERSION` 3.5.1, `CHANGELOG.md` entry, `migrations/3.5.1.md`.

## Stop and ask if

- T0 shows the scout times are wrong: T8 then needs a design.
- Allowing chained reads needs more than a fixed list of filters (head, tail,
  wc, sort, uniq, grep on stdin).
- The draft-plan rule (T2) would block a pre-plan inspection that the
  developer considers normal.
- A budget eval (65, 65b, 79, 125n) would need raising.

## Tasks

| # | Task | Files | Test that proves it | Evidence | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|----------|---------|---------|-----|--------|
| T0 | Check E9: in one S1-T3 integrator transcript, compare each scout's first/last timestamps with the integrator's `Agent` tool_use → tool_result times. Finding to `context.md` | `.sdlc/claudio-3-5-1/context.md` | the two times agree within 10 s, or the gap is measured | E9 | claude | — | 5m/500k | blocked (needs an integrator transcript from ~/.claude, out of reach of the cloud thread) |
| T1 | Guard read-only git: add `ls-files`, `rev-parse`, `merge-base`, and `branch` in list form only (reject `-d -D -m -M -c -C -f -u --delete --move --copy --force --set-upstream* --unset-upstream --edit-description`). Allow `;`, `&&` and `\|` when every segment is an allowed git read or one of head, tail, wc, sort, uniq, grep (no file args). `$`, backticks, `<`, `>` and `()` stay blocked | `hooks/orchestrator-guard.sh`, cases 125x1–125x4 | x1 `git branch -a --contains X` allowed, x2 `git branch -D X` blocked, x3 `git status; git log -3 \| tail` allowed, x4 `git log \| sh` and `git log; cargo test` blocked | E1 | claude | — | 1m/150k | done |
| T2 | No delegation of a plan row while `plan.md` is `Status: draft`: `orchestrator-guard` on the `Agent` tool in Orchestrate mode reads the tag's chain and blocks `T1`+ when the plan is a draft; `T0` (pre-plan inspection) passes. One line in the skill | `hooks/orchestrator-guard.sh`, `settings.template.json` (Agent matcher), `skills/orchestrate/SKILL.md`, cases 125x5–125x7 | x5 T1 with draft plan blocked, x6 T0 with draft plan allowed, x7 T1 with approved plan allowed; 125n ≤ 80 lines | E2 | claude | T1 (same file) | 1.5m/200k | done |
| T3 | Plan-stage reading: in the skill, prior chains and design docs go to the integrator or a scout through a brief; main reads `context.md`, the handoff summary and the artifact. Trim another line to stay ≤ 80 | `skills/orchestrate/SKILL.md`, case 125x8 | x8 the rule is present; 125n green | E3 | claude | T2 (same file) | 1m/120k | done |
| T4 | Nested estimates from data: the integrator runs `bash ~/.claude/skills/sdlc/calibrate.sh <repo>` once per task and uses the runner's median; the main brief passes those medians when it has them. Starting table in `templates/plan.md` lowered to the medians of the 3 repos (implementer ~1m/150k, scout ~0.5m/120k) | `agents/integrator.md`, `skills/sdlc/templates/plan.md`, `skills/sdlc/calibrate.sh` if the integrator needs a runner filter, case 125x9 | x9 integrator.md names calibrate.sh for nested `est=`; existing calibrate cases green | E4 | claude | — | 1m/150k | done |
| T5 | `usd_min` on main rows: reuse the price table of `subagent_stop` in `post_tool_use` (one shared jq def) | `hooks/task-actuals.sh`, case 125x10 | x10 a main `done` row on Fable gets a numeric `usd_min`; existing actuals cases unchanged | E5 | claude | — | 1m/150k | done |
| T6 | test-guard: removing assertions passes when every removed assertion line is still present in the new text (pure dedupe); any other drop still blocks | `hooks/test-guard.sh`, cases 125x11–125x12 | x11 removing an exact duplicate allowed, x12 removing a distinct assertion still blocked | E6 | claude | — | 1m/120k | done |
| T7 | macOS note in the implementer: BSD `sed -i ''` or `perl -pi -e`, and a red step that fails must be retried another way, never skipped | `agents/implementer.md`, case 125x13 | x13 the note is present; agent budget case green | E7 | claude | — | 0.5m/80k | done |
| T8 | Review evidence must exist: `subagent-report-check` sends an integrator review task back when its artifact cites `review/findings.md` and the file is missing or older than the task start; reviewer evidence copied into `review/evidence/`, never left in a scratchpad | `hooks/subagent-report-check.sh`, `agents/integrator.md`, cases 125x14–125x15 | x14 missing findings.md sent back, x15 present file passes | E8 | claude | T4 (integrator.md) | 1.5m/200k | done |
| T10 | Escalation criteria in `integrator.md`: stop as `needs-decision` (decision-request, options table, recommendation) instead of deciding when the spec admits two readings, two designs trade off something the spec does not rank, a fix would leave the task's Files or layer, the same failure has two competing causes, a review finding is disputed, or there is a security, data-loss or irreversibility risk. The skill: main decides those itself, never back to the integrator unanswered | `agents/integrator.md`, `skills/orchestrate/SKILL.md`, cases 125x16–125x17 | x16 integrator.md lists the criteria, x17 skill says main decides; 125n green | E10 | claude | T8 | 1m/150k | done |
| T11 | No advisor in the main session in Orchestrate mode: the mode notice and the skill say not to call it and to run `/advisor off` if it is on (Fable would advise Fable). A hook cannot block it (server tool) | `hooks/mode.sh`, `skills/orchestrate/SKILL.md`, cases 125x18–125x19 | x18 the notice names `advisor`, x19 the skill does; 125n green | E11 | claude | T3 | 0.5m/80k | done |
| T9 | Close: `VERSION`, `CHANGELOG.md`, `migrations/3.5.1.md`, full `evals/run.sh`, `check-public.sh` | those files, `review/` logs | suite green, logs in `.sdlc/claudio-3-5-1/review/` | — | claude | T1–T8, T10, T11 | 10m/2M | done (3 env-only fails, also on HEAD: 110a, 122h, 123c) |

Estimates use the medians seen today, not the old 3m/400k table.

## Schedule

| Wave | Tasks (in parallel) | Then (main) |
|------|---------------------|-------------|
| 1 | T0, T1, T4, T5, T6, T7 | read T0's finding; if E9 is a real bug, add a row |
| 2 | T2, T8 | `git diff --stat` against Files |
| 3 | T3 | same |
| 4 | T9 | commit with the developer's confirmation |

T1, T2 and T3 touch the same files, so they go in separate waves.

## Left out on purpose

- The `flag` threshold (|deviation| > 50 %): revisit after T4 brings estimates
  near the medians; today every row is flagged only because of E4.
- Kiln K013 has no `actuals.jsonl`, but it ran before 3.5.0: check again on
  the next Kiln task.
- Two `silent_turn_reminder` nudges to Fable during long writes: harness, not
  Claudio.
- The Sentry token seen in a process list during S1-T2 review: not a harness
  issue, but worth rotating.

# Plan: claudio-3-6-2

- **Derived from**: live4 review (ASTRA natural-volume-registry, Fable 5.2 main, 3.6.0), 2026-11-19.
- **Status**: APPROVED BY ENGINEER (Aaron, 2026-11-19: "ok, implementa")
- **Built by**: a Claude cloud thread through folder access, branch `feat/3.6.2-orchestrate` from `feat/3.6.1-orchestrate-fixes`; push, PR and `./install.sh` stay with the developer.

## Evidence

| # | Seen | Cause |
|---|------|-------|
| E1 | `plan.md` has T1–T10 `pending` though T1–T9 ran and have actuals | Only the main session updates Status, and it did not |
| E2 | Main read T0-inspection and T0-verify whole (20–24 KB each) | Only the skill asks for "frontmatter and summary"; nothing checks the Read or the summary's size |
| E3 | Main (Fable) produced 1.1M output tokens: 11 edits of spec.md, 3 of plan.md, 10 briefs of 2.6–7.3 KB | The skill has the main session write spec and plan prose and long briefs |

## Tasks

| # | Task | Files | Test |
|---|------|-------|------|
| T1 | Hook sets the plan row's Status: `in progress` when the main session launches `Agent` with `[sdlc:<slug>/T<n>]`, and `done`/`blocked`/`needs-decision` from the artifact's `result:` at the integrator's SubagentStop. Only rows not run by main; nested tags (T5a) are skipped | `hooks/task-actuals.sh`, `settings.template.json` | launch sets in progress; done artifact sets done; blocked sets blocked; main row untouched |
| T2a | Artifact check: `## Summary` present, non-empty, at most 15 lines; otherwise the integrator is sent back once | `hooks/subagent-report-check.sh` | 16-line summary sent back; 10-line passes |
| T2b | Guard on `Read` in Orchestrate main session: `work/*.md` (except `*-brief.md`), `review/*` and files outside `.sdlc/` need `limit` ≤ 40; the message says to read frontmatter+summary or delegate a `T0` | `hooks/orchestrator-guard.sh`, `settings.template.json` | whole artifact blocked; limit 40 allowed; brief allowed; developer session unaffected |
| T3 | Less Fable output: the main session records decisions (one line each, in `decisions/` or the brief) and an integrator task writes spec.md and the plan prose from them; the brief has a template of at most 20 lines (tag, goal, files, decisions, done-means) | `skills/orchestrate/SKILL.md` (stays ≤ 80), `agents/integrator.md`, `skills/sdlc/templates/brief.md` | skill names the spec-draft task; template ≤ 20 lines; 125n green |
| T4 | VERSION 3.6.2, CHANGELOG, full suite in batches, commit on the branch (no push) | `VERSION`, `CHANGELOG.md` | `review/final-evals.log` |

## Stop and ask if

- T2b would block a read the developer considers normal (for example the design doc the main is approving).
- T3 does not fit the 80-line limit of the skill without dropping a rule.

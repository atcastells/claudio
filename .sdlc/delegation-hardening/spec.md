# Spec: Delegated execution that survives long, multi-layer tasks

- **Derived from**: `intent.md`
- **Status**: approved (2026-11-16, "Apruebo la spec": all defaults D1–D12)
- **Approved by**: product owner (maintainer, 2026-11-16)

This spec covers the four slugs approved in the intent. Each slug gets its
own `.sdlc/<slug>/plan.md` (the `task-actuals` and `plan-resume` hooks read
that path) with `Derived from: ../delegation-hardening/spec.md`. Requirement
IDs carry the slug's letter: A = `agent-turn-budgets`, B = `report-hook-tdd`,
C = `permission-friction`, D = `plan-template-gates`.

## Decisions to approve

Each has a default; answer by number ("D2: 50, not 60"). The requirements
below assume the defaults.

| # | Decision | Default proposed | Why |
|---|----------|------------------|-----|
| D1 | Red first vs mutation after | Accept both, but the report must carry the **literal** failing line of either. `Red:` for a test run before the code; `Mutation:` for a test run against code broken on purpose. Missing, or "not seen", is sent back. | The defect was not the order; it was tests that never failed. A literal failing line catches that in both cases, and banning mutation would only move the rule-breaking elsewhere. |
| D2 | Turn limit | A hook warns the subagent when 8 turns are left: "write your report now". `implementer` goes from 40 to 60; the others stay. If the spike (A1) shows a hook cannot reach a subagent, fall back to prompt wording only. | Prompt wording alone did not prevent the 19 stops. 60 covers integration tasks without making a stuck agent expensive. |
| D3 | Where "git in its own command" goes | `agents/implementer.md`, `agents/verifier.md` and the `sdlc` skill, not the 75-line core. | Core is at budget; the failure happened inside delegated work. |
| D4 | Harness defects (#2 adapter, #9 ask-as-deny) | Not fixed here. Mitigation in agent prompts only: a background process is started and stopped in the same command, and no process outlives the agent. No `SubagentStop` process-killing hook. | A hook that kills processes by guess can kill the developer's own servers. The cause of #2 is unknown. |
| D5 | Closing without review | The plan template gets a **Review** section: the three reviewer verdicts, or `Waiver: <reason> (<who>, <date>)`. The `sdlc` skill says a plan is not closed with that section empty. No blocking hook. | Makes the skip visible and signed, which is what the handoff asked for, without a hook guessing when a plan "closes". |
| D6 | Verifier split | No new agent. `main` runs the suite once (one command, cheap) and passes the result to the `verifier`, which starts with change behavior and adjacent flows and runs the suite only if it was not given. | Same effect as two agents for one command less to orchestrate. |
| D7 | `scout` | Stays Haiku/15. Its description says: one lookup question; audits go to `reviewer` or `main`. | The model fits lookups; the problem was what it was asked. |
| D8 | Task IDs | Keep `T<n>` (five hooks parse it). The template says so, and the report hook's message says how to fix a non-`T` ID. | Widening the pattern touches five parsers for a naming preference. |
| D9 | `rm` and `mv` for subagents | No permission change (`rm` stays `ask`). Agent rule: a repo file is copied for a negative test, never moved out; temporary files go under `mktemp -d` and are removed in the same command. | Opening `rm` to agents is broader than the defect, which was moving a repo file out. |
| D10 | Task size | Plan template: a delegated task covers at most 3 plan rows and must leave the tree building with its tests green. A `seam` task (crossing layers that do not build apart) is allowed when the Task cell says `seam:` and why. The personal 100-line rule is untouched; you change it with `/rules` if you want. | Gives the cross-layer case a legal, visible shape instead of a silent break. |
| D11 | Main-thread tokens (#13) | No code. The `sdlc` skill's Build step says to put orchestration on `main` rows so `task-actuals` measures it. | Already built; the gap is that nobody is told to use it. |
| D12 | Orchestration rules from the handoff | Two lines: in the `sdlc` skill, "no figure reaches the user without a run in which the measurement could have failed"; in the plan template's *Stop and ask if*, "the task needs to open windows or apps on the developer's screen". | Both cost one line each and prevented real rework. |

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| A1 | Spike: confirm whether a `PostToolUse` hook receives `agent_type` and `agent_transcript_path` for a subagent tool call, and whether its `additionalContext` reaches that subagent. | #1; open question 3 | A written result in the plan's findings, with the payload seen. Decides A2's form. |
| A2 | A subagent of type `implementer`, `verifier`, `reviewer` or `scout` gets one warning when it has 8 turns left: write the report now. Limits are read from the agent's frontmatter, not hard-coded. | #1 | Hook evals: payload with a transcript at limit−8 → warning; at limit−9 → nothing; a second call at limit−7 → nothing (warns once); unknown `agent_type` → nothing. Seen red first. |
| A3 | `implementer` `maxTurns: 60`. Each of the four agent prompts says: "if you are told turns are running out, stop and write your report with what is done and what is left". | #1, D2 | Eval checks the frontmatter value and the sentence in each agent file. |
| A4 | `verifier.md`: order is change behavior, adjacent flows, then the suite unless its result was given in the prompt. The `sdlc` skill's Test stage says `main` runs the suite and passes the result. | #12, D6 | Eval checks both texts. Existing verifier cases still green. |
| A5 | `scout.md` description names its size: one lookup; not audits or reviews. | #11, D7 | Eval checks the description. |
| B1 | The implementer report has a `Red:` or `Mutation:` line with a command and a literal failing output after `→`. `subagent-report-check.sh` sends back a report without one, or with "not seen" / "none" / "n/a" in it. | #4, D1 | Hook evals: `Red:` with output → pass; `Mutation:` with output → pass; missing → blocked; `Red: not seen` → blocked. Cases 82h and 82l updated only in their report fixture, not in their expectation. |
| B2 | `implementer.md` report format and step 1 describe `Red:` / `Mutation:`; a test that passes before the change is reported as such, not as red. | #4 | Eval checks the text. |
| B3 | The report hook's message for a bad `TASK:` line says IDs are `T<n>` (optionally with a letter) and that phases go in the Task cell. The plan template says the same. | #7, D8 | Hook eval on `TASK: x/A1` checks the message text. |
| C1 | `production-gate` ignores heredoc bodies when scanning: the text between `<<TAG` and `TAG` is not scanned for the environment word or the action verb. The command line itself still is. | #10 | Hook evals: a heredoc writing `use crate::production::config` plus `apply` in its body → allowed; `kubectl apply -n production` with a heredoc after it → blocked; existing cases 10–13f green. Seen red first. |
| C2 | `implementer.md` and `verifier.md`: git in its own command, never chained; a background process started and stopped in the same command; repo files copied, never moved out of the repo; temporary files under `mktemp -d` removed in the same command. | #2, #6, #8, D3, D4, D9 | Eval checks each sentence in both files. |
| D1r | Plan template: *Tasks* note on size (≤ 3 rows per delegated task, tree building and tests green after it) and on `seam:` tasks; *Stop and ask if* default line about opening windows. | #3, D10, D12 | Eval checks the template text. |
| D2r | Plan template gains a *Review* section (three verdicts or a signed waiver). The `sdlc` skill's Deploy stage says a plan is not closed with it empty. | #5, D5 | Eval checks template and skill text. |
| D3r | `sdlc` skill: Build step tells to track orchestration on `main` rows; the "no figure without a run that could fail" line. | #13, D11, D12 | Eval checks the skill text. |
| X1 | Release: `VERSION` bump (MINOR: new hook behavior), `CHANGELOG.md` entry, `migrations/<version>.md` because the plan template and agents that projects use change. | Releasing a version (repo `CLAUDE.md`) | `bash evals/run.sh` FAIL 0, with the profile too; `check-public.sh` adds no hit; `HOME=$(mktemp -d) ./install.sh --no-profile` ends green. |

**C1 reverted (developer, 2026-11-16, "Quitar el filtro").** The verifier
found heredoc filters that let production actions through which 3.0.0
blocked: a hyphenated tag, an unquoted body that bash expands, `>(bash)`, and
`<<` inside comments, quotes or `$((`. `production-gate.sh` keeps the 3.0.0
scan; its block message now says to write files with Write or Edit, whose
content is never scanned. Cases `120a`/`120e` flip to "still blocked";
`120h`, `120i` and `120j` guard the bypasses and the message.

**As built (3.1.0), where it differs from the table below:**

- A1/A2: no turn-warning hook (developer decision after the spike, recorded
  in `agent-turn-budgets/plan.md`). A3: `implementer` and `verifier` at 60;
  the agent sentence is "Your turns are limited… output cut short at the
  turn limit still says where you stopped" (cases `118c1–c4`), not the
  "if you are told" wording.
- B1: the text after `→` is sent back when it is empty or opens with an
  admission ("not seen", "n/a", "no …", "none", "pass", "passed", "green"),
  not only on an exact match (found by review). `RESULT: blocked` is exempt.
  A `TASK:` id is `T<n>` plus an optional letter, then a space, `:`, `.`,
  `,`, `*` or the end.
- D6: the verifier's green rule accepts a suite result given in the prompt
  with its command and output (case `118c7`).
- X1: no `migrations/3.1.0.md`; `migrations/README.md` asks for one only
  when project files change, and this release changes `~/.claude` only.

## Design

- **A2, turn warning.** New `hooks/turn-budget.sh` on `PostToolUse` (matcher
  `.*`). Reads `agent_type`; if it is one of the four, reads `maxTurns` from
  `~/.claude/agents/<type>.md` (repo: `agents/<type>.md`), counts assistant
  messages in `agent_transcript_path`, and when the count reaches
  `maxTurns − 8` emits `additionalContext` once (marker
  `${TMPDIR:-/tmp}/claudio-turns-<agent_id>`, same `agent_id` validation as
  `subagent-report-check.sh`). Never blocks; any missing input exits 0.
  Registered in `settings.template.json`. If A1 says the context does not
  reach the subagent, A2 is dropped and A3 carries the change alone.
- **B1.** One more check in the implementer branch of
  `subagent-report-check.sh`: `^[[:space:]]*(Red|Mutation): .+→ *\S` and not
  matching `(not seen|none|n/a)` after the arrow, case-insensitive.
- **C1.** Before the existing `grep`, strip heredoc bodies with an awk pass
  over `$scan` (start on `<<-?['"]?TAG`, end on a line equal to `TAG`).
  macOS awk compatible.
- Text changes (A3–A5, B2–B3, C2, D1r–D3r) are edits to existing files;
  each sentence has its `file_contains` eval.
- Core `global/CLAUDE.md` is not touched.

## Policy applied

- **Personal data**: none.
- **Sensitive business data**: none. The handoff's project names and port
  numbers stay out of public files.
- **Credentials**: none.
- **Decisions about people / high risk**: no.

## Out of scope

- The cause of the adapter error (#2) and ask-becomes-deny (#9): harness.
  You report them upstream if you want; this repo only mitigates.
- A per-session "commits allowed" mode or a commit queue (#9).
- Changing the personal 100-line rule (#3): yours, through `/rules`.
- A hook that blocks closing a plan without review (D5 chose visibility).
- Widening task IDs beyond `T<n>` (D8).

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `PostToolUse` context does not reach subagents | A2 cannot be built | A1 spike first; fallback is A3 wording |
| Counting turns from the transcript drifts from the harness's own count | Warning too early or too late | Warn at 8, not 1; eval with a real transcript shape |
| `PostToolUse` on every tool adds latency | Slower agents | Exit at once unless `agent_type` is one of four; no transcript read before that |
| Heredoc stripping hides a real production command inside a heredoc fed to a shell (`bash <<EOF`) | Gate bypass | Do not strip when the heredoc feeds `bash`, `sh`, `zsh`, `ssh` or `kubectl`; eval for it |
| B1 makes existing implementer report fixtures fail | Red suite | Update fixtures' report text only; expectations unchanged |

---
Next stage: Build reads this file and writes one `plan.md` per slug.

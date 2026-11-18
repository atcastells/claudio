# Context: fable-orchestrator

Shared by every task of the plan. Read it before anything else. The main
session is the only writer. Committed: no personal data, credentials or
sensitive business data.

## Decisions that shape the code

- T0, main vs subagent: hook input carries `agent_id` and `agent_type` when
  the hook fires inside a subagent (code.claude.com/docs/en/hooks, common
  input fields). The guard treats an empty `agent_id` as the main session,
  as `subagent-report-check` already does.
- T0, nested cost: the docs list no parent agent id. Instead of a parent id,
  the integrator tags nested prompts `[sdlc:<slug>/T<n>a ...]`, so
  `task-actuals` records them as `T<n>a`, `T<n>b`; the integrator's cost is
  its own record plus those. Nested agents are synchronous by default in an
  interactive session, so their records exist when the integrator stops.
- T0, consequence: in Orchestrate mode plan task IDs carry no letter; the
  letters are reserved for nested agents.
- T0, ordering: hooks on the same event run in parallel, so `task-actuals`
  stamps `cost` without depending on `subagent-report-check`; a report sent
  back stops again later and the stamp is rewritten, not appended.
- T0, model: only SessionStart may carry `model`, and not always; the mode
  does not depend on it. The notice says Fable 5.2 is chosen at start.
- T0, version: the developer runs Claude Code 2.1.327 (nesting from 2.1.219,
  three levels by default). `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` on the
  developer's machine is unchecked: this session cannot read ~/.claude.

## Key paths

- `hooks/lib/mode.sh`: markers `claudio-mode-<sid>` (Vibe) and
  `claudio-orch-<sid>` (Orchestrate), independent.
- `agents/integrator.md`, `skills/orchestrate/SKILL.md`,
  `skills/sdlc/templates/artifact.md`, `hooks/orchestrator-guard.sh`.

## Do not

- Do not add lines to `skills/sdlc/SKILL.md` (160-line budget, case 79).

## Learned

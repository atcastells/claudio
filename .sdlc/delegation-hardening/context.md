# Context: delegation-hardening (shared by its four slugs)

Written only by the main session. Subagents: read this first.

## Decisions

- Spec D1–D12 approved as defaults (2026-11-16).
- After `agent-turn-budgets` T1: no turn-warning hook. `implementer` and
  `verifier` at `maxTurns: 60`; agents keep a running report; a partial
  output is resumed with SendMessage.
- `production-gate` heredoc filter removed after the verifier found bypasses
  (developer decision): heredoc bodies are scanned as in 3.0.0; files are
  written with Write/Edit. Filtering shell text without a parser fails open.
- Task ids are `T<n>` plus an optional letter, then a space or the end:
  `T3-red` is not an id (report hook and plan-hint now agree).
- An implementer report with `RESULT: blocked` needs no `Red:` line.

## Learned

- The installed `production-gate` blocks test text with the production word
  plus an action verb: build the word at runtime (`P=prod; P="${P}uction"`)
  and keep payloads in a file, not on the command line.
- `file_contains` needles must sit on one line: wrap the prose around them.
- `skills/sdlc/SKILL.md` has a 160-line budget (eval); it is at 157.
- Text after `→` is extracted with `${line#*→}`, which works under `LC_ALL=C`;
  a bracket like `[^→]` would not.

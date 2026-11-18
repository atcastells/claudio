# Spec: test-time

Traces to `intent.md`.

## Requirements

- R1. The `implementer` runs its task's test and the tests of the files it
  touches, not the repo's suite; the main session runs the suite once per
  wave. (51%/55% runs, 39% subagent test time)
- R2. Test output goes to a file and is read from there; a test is not run
  again with nothing changed. The `verifier` reuses the wave's output.
  (51% reruns)
- R3. Failure budget: the same failure twice stops the task with
  `RESULT: blocked` and the log; never more than four runs of the same test.
  The implementer report carries `Attempts: <n>`, required by
  `subagent-report-check`. (red streaks of 3+: 18–30%)
- R4. The sdlc skill names when to hand lookups to the `scout` (more than two
  searches, or the file is unknown); the `scout` runs at effort `low`.
  (26% of main tokens exploring)
- R5. The model ladder ends in Fable 5.2 as an advisor, not Fable 5.1 as the
  main model. (35% of cost, 50% red)
- R6. `/repo-setup` writes Rust test commands for repos with `Cargo.toml`:
  `cargo check --tests` first, `cargo nextest run` filtered while iterating,
  the whole workspace once at the end. (`cargo test` 74% of test time)
- R7. `evals-on-config-change` runs only the cases that name the edited
  file, and the whole suite only when none does. (52% in this repo)

## Out of scope

- The hook that denies rerunning the same test on the same tree (proposal 8):
  only if R2 does not move the rerun rate.
- Changing the agents' models: implementer, verifier and reviewer stay on
  Sonnet, which matches the model hierarchy.

## Policy

No personal or business data: the profile figures are aggregates.
`global/CLAUDE.md` stays within its 75-line budget (rules go to agents and
skills), `skills/sdlc/SKILL.md` within 160 lines.

## Release

MINOR (3.3.0): new rules and a project template change (`repo-setup`), so it
ships `migrations/3.3.0.md`.

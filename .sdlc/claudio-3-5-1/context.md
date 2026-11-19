# Context: claudio-3-5-1

- Built 2026-11-19 by a Claude cloud thread through folder access to the
  developer's checkout. No git writes, no `./install.sh`.
- Evals ran in the thread's Linux VM, in batches (`evals/run.sh '<glob>'`,
  180 s per call): every case green except 110a, 122h and 123c, which fail
  the same way on an untouched `git archive HEAD` copy (VM paths and
  timing). Log: `review/final-evals.log`. Run the full suite on the Mac
  before installing.
- `advisor` is a server tool (`server_tool_use` in the transcript): no
  PreToolUse hook sees it, so T11 is text only (mode notice and skill).
- The "null rows" seen in S1-T2 `actuals.jsonl` are main-task start markers
  (`{"event":"start"}`), not a bug.
- test-guard never counted Rust `assert_eq!`/`assert_ne!` (`!` before `(`);
  T6 fixed that too, so Rust tests are now protected.
- T4: the `templates/plan.md` starting row (main 5m/500k) was left as is:
  today's main medians are higher (10m/4M), not lower.
- T0 open: compare a nested scout's first/last timestamps with the
  integrator's Agent call times in one S1-T3 integrator transcript.
- Version: shipped as 3.6.0 (CHANGELOG rule: new rules = MINOR); the slug
  keeps the plan's working name claudio-3-5-1.

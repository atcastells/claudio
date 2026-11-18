# Intent: Less session time on tests, a clear model hierarchy

- **Originator**: maintainer
- **Date**: 2026-11-18
- **Status**: approved by the originator ("perfecto", 2026-11-18)
- **Slug**: test-time

## The problem, in the originator's words

> "Busco más tiempo ocupado con trabajo y menos con tests."
> "La idea es tener una jerarquía u organigrama de modelos definitivo y quién
> puede hacer cada cosa."
> (2026-11-18, after a metadata-only profile of the local sessions)

## Facts (session profile, 439 sessions, June–November 2026)

- 21% of agent time goes to tests (17% main session, 30% subagents);
  Sonnet subagents spend 39% of their time on tests, 57 runs per hour.
- 51% of main-session test runs repeat a run with no edit in between; 55%
  of all runs are the full suite (no test or path filter).
- `cargo test` is 74% of test execution time: 32 s per run, 47% red.
- Exploring (Read/Grep/Glob and read-only shell) is 26% of the main
  session's tokens on Opus 5.5; one lookup costs about $0.11 there against
  $0.03 in a Sonnet subagent. The Haiku `scout` adds up to only 3 h of use.
- Fable 5 and 5.1 as the main model are 35% of the API-equivalent cost;
  Fable 5.1 has the worst first-test-after-edit result (50% red).
- In this repo, 52% of session time is tests; `evals/run.sh` ran 523 times,
  95% of them as the full suite.

## How we will know it is solved

Two weeks after release, the same profile shows lower values for: subagent
time in tests (30%), reruns with no edit (51%), full-suite runs (55%) and
main-session tokens spent exploring (26% on Opus 5.5).

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-18 | Which of the eight proposals | 1–7 now; 8 (hook that blocks reruns) only if 2 is not enough after two weeks | originator |
| 2026-11-18 | G1 thresholds (harness-hardening) | stop after the same error twice; at most four runs of the same test | originator |

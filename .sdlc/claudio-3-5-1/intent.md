# Intent: claudio-3-5-1

- **Originator**: Aaron Castells (developer)
- **Date**: 2026-11-19
- **Status**: approved by the developer (2026-11-19)
- **Slug**: claudio-3-5-1

## The problem

The first live Orchestrate session on 3.5.0 (ASTRA S1-T3, Fable 5.2 main,
Opus 5.5 integrator) worked, but showed friction and waste: the guard
blocked harmless git reads, a plan row was delegated with the plan still a
draft, the main session read whole chains, nested estimates were 3–5x too
high, main rows had no cost, test-guard blocked a pure dedupe, `sed -i`
failed on macOS, reviewer evidence was lost twice, the integrator had no
rule for when a hard question is the main session's call, and the Fable main
session called the Fable advisor.

## What the developer asked for

1. Fix the findings of the session review (plan rows T0–T8).
2. A way for the integrator (Opus) to recognize a very complex question and
   hand it to the main session (Fable) in the artifact header instead of
   deciding it (T10).
3. Fable should not use the advisor in the main session (T11).

Git and `./install.sh` stay with the developer.

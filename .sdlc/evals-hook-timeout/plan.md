# Plan: The config-change evals hook never finishes

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-11-16, "Apruebo el plan")
- **Nothing is implemented until this file is approved.**

## Done means

- `evals-on-config-change.sh` registered with `asyncRewake: true` and
  `timeout: 600`, carried by `install.sh`; a red stub suite exits 2 with at
  most 40 `FAIL` lines and the summary; a green one exits 0 silently; a
  burst of three invocations during one run gives two runs; a dead-pid lock
  is taken over. Cases `123*` seen red first; `19b`, `19e`, `111d` green
  unchanged.
- CHANGELOG 3.2.0 bullet; `bash evals/run.sh` FAIL 0 with both profiles,
  `check-public.sh` no new hit, clean install green; verifier and three
  reviewer passes, every IMPORTANT fixed.

## Stop and ask if

- `install.sh` drops `asyncRewake` or `timeout` when merging and fixing it
  means changing the merge logic for every hook.
- `19b`, `19e` or `111d` must change.
- The task needs to open windows or apps on the developer's screen.

## Tasks

The *Status* column is updated as each task closes: it is the live list and
the resume point after compaction or a new session.

A delegated task covers at most 3 plan rows and leaves the tree building with
its tests green. Task IDs are `T<n>`, optionally with a letter.

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | `settings.template.json`: the PostToolUse Write/Edit entry for `evals-on-config-change.sh` gets `"asyncRewake": true` and `"timeout": 600`. Scenario script checks the template and a clean test install with `jq`. | `settings.template.json`, `evals/scripts/evals-hook-async-test.sh`, `evals/cases/123a-evals-hook-async-registered.json` | `123a` red first: template entry has both fields; installed `settings.json` after `HOME=$(mktemp -d) ./install.sh --no-profile` has both | R1 | implementer | — | 2m/160k | done (install.sh unchanged: a fresh install copies the template and a merge replaces the whole hooks object; only the fresh path is tested) |
| T2 | Report: on red, stderr is "EVALS RED after modifying <file>." plus at most 40 `FAIL` lines and the `PASS:` summary line, exit 2; on green, nothing printed, exit 0. Scenario script with a stub suite in a temp source repo (`WORKFLOW_HOME/source`). | `hooks/evals-on-config-change.sh`, `evals/scripts/evals-hook-run-test.sh`, `evals/cases/123b-evals-hook-report.json` | `123b` red first: 60-FAIL stub → exit 2, exactly 40 FAIL lines plus the summary; green stub → exit 0, empty stdout and stderr; `19e`, `111d` green | R2, R5 | implementer | — | 2m/200k | done (suite 335/0) |
| T3 | Coalescing: lock dir `${TMPDIR:-/tmp}/claudio-evals-<cksum of suite path>` with the pid inside; a live holder → touch `pending`, exit 0; a dead holder → take over; the holder loops while `pending` exists, at most 3 runs; trap releases the lock; a symlink at the lock path → exit 0. | `hooks/evals-on-config-change.sh`, `evals/scripts/evals-hook-run-test.sh`, `evals/cases/123c-evals-hook-coalesce.json` | `123c` red first: stub sleeps 2 s and logs; second invocation returns in under 1 s; three invocations during one run → two runs in the log; a lock with a dead pid → the suite runs; lock dir gone after the run; symlink at the lock path not followed | R3, R4 | implementer | T2 | 3m/250k | done (lock later moved to `WORKFLOW_HOME/locks`, see T5; also: a non-directory at the lock path exits 0; INT/TERM/HUP release the lock; suite 336/0 run by main) |
| T4 | CHANGELOG 3.2.0 bullet (background run, wakes Claude on red, coalesced bursts, `claude -p` caveat). Full suite, both profile suites, `check-public.sh`, clean install. Fill *Estimate vs actual*. | `CHANGELOG.md`, `.sdlc/evals-hook-timeout/plan.md` | The commands in "Verification commands" green | R6 | main | T1, T3 | 4m/1.5M | done (cause: clean install failed 123a, which needs the repo's template and install.sh; marked `repo_only`. Suite 336/0, company profile 347/0, example 337/0, check-public 26 old hits, clean install 294/0) |
| T5 | Verify: the hook against a real copy of this repo's suite (not a stub) with a planted failing case, timing included; the burst with real invocations in parallel; adjacent flows: `bash-file-check` (no longer dispatches it) and `19e`'s unrelated-file path. Suite result given by main. | — | Verifier report with commands and output | all | verifier | T4 | 4m/600k | done (amber, 0 important; real suite: red in 119 s with the planted case named, green in 128 s silent, burst of 3 gave 2 runs, SIGKILLed lock taken over. Nit fixed by main red first: FAIL matched case names. Also fixed red first after an automated security note: lock moved from TMPDIR to `WORKFLOW_HOME/locks` mode 700, no write through symlinks) |
| T6 | Review pass: bugs | — | Findings per `REVIEW.md` | all | reviewer | T5 | 3m/660k | done (3 important: pid reuse silences the gate, lost run in the release window, crash report with no diagnostic; 4 nits) |
| T7 | Review pass: security (lock path in a shared `TMPDIR`, pid reuse, symlinks, the trap) | — | Findings per `REVIEW.md` | R3, R4 | reviewer | T5 | 3m/660k | done (1 important: pid reuse, same as T6; 2 nits: TERM deferred during the suite, pid write not atomic) |
| T8 | Review pass: conformance (bash 3.2, macOS tools, no `sed -i`, English, spec G1–G6) | — | Findings per `REVIEW.md` | all | reviewer | T5 | 3m/660k | done (0 important; 4 doc nits fixed by main) |
| T9 | Fix after review: a lock is live only if its pid is numeric > 1, alive, running this hook (`ps`), and its pid file is under 11 min old; an empty pid in a lock under 5 s old counts as live; pid written atomically (temp + `mv`); release by renaming the lock away, then rerun if `pending` was set in it (cap 3 still); suite run as a background child with `wait`, signals forwarded to it; a crash with no FAIL and no `PASS:` line reports the exit code and the last 20 lines; an unusable lock dir runs the suite unlocked instead of skipping; on red after the cap with edits pending, one line says so. | `hooks/evals-on-config-change.sh`, `evals/scripts/evals-hook-run-test.sh`, `evals/cases/123d-evals-hook-lock-robust.json` | `123d` red first, one scenario per item; `123b`, `123c`, `19e`, `111d` green | After review | implementer | T8 | 4m/350k | done (also: a stale lock is renamed away before `mkdir`, so one taker wins; a symlink at the lock path still exits 0, as 123c(5) requires; suite 337/0, company 348/0, example 338/0, check-public 26 old hits, clean install 295/0) |

- **Runs on**: `main` (Opus, the session); `implementer` (Sonnet 5.5);
  `verifier` / `reviewer` (Sonnet 5.5).
- **Est**: from `calibrate.sh` (2026-11-16): repo medians implementer
  2.0m/156k, main 3.1m/1.2M, verifier 3.0m/520k, reviewer 3.1m/656k. T3
  sized above (lock and timing scenarios); T5 above (a real suite run is
  about 2 min).
- Each delegated task's prompt starts with `[sdlc:evals-hook-timeout/T<n> est=<min>m/<ktok>k]`
  and says to read `.sdlc/delegation-hardening/context.md` and
  `.sdlc/bash-edits-skip-hooks/context.md` first.

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1, T2 | 2m | suite |
| 2 | T3 | 3m | suite |
| 3 | T4 | 4m | — |
| 4 | T5 | 4m | read the verdict |
| 5 | T6, T7, T8 | 3m | fill *Review* |

T2 and T3 edit the same hook and script: one after the other. T1 touches
only the template and its own script.

- **Estimated wall-clock**: ~16m (+ main checks)
- **Sequential sum**: 24m
- **Estimated tokens**: ~5.3M

## Test strategy

Red first for every case. Hook cases are scenario scripts with a stub suite
(`evals/run.sh` in a temp git repo named by `WORKFLOW_HOME/source`), so they
run in seconds; `CLAUDE_EVALS_RUNNING` unset inside them. T5 runs the real
suite once.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh status-line.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<company> bash evals/run.sh
WORKFLOW_PROFILE=profiles/example bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile --verbose
```

## Implementation risks

- The evals hook itself is part of what `bash evals/run.sh` tests: a stub
  suite keeps the scenarios from recursing; `CLAUDE_EVALS_RUNNING` stays the
  guard in real use.
- `kill -0` on a reused pid takes a dead lock as live until the next
  invocation after that process exits; accepted (spec risks).

## Review

Filled in Deploy. A plan is not closed while this section is empty.

Every IMPORTANT was fixed with a scenario seen red first (T9).

- **verifier (T5)**: amber, 0 important; nit fixed (FAIL matched case
  names). After it, main moved the lock out of `TMPDIR` (automated security
  note), red first.
- **bugs (T6)**: 3 important fixed in T9: pid reuse silenced the gate; a run
  could be lost in the release window; a crashing suite gave an empty
  report. Nits fixed: takeover race, unusable lock dir skipped the suite,
  cap with pending not told, TERM deferred during the suite.
- **security (T7)**: 1 important (pid reuse, same as T6), fixed. Nits
  fixed: atomic pid write, TERM deferred. Noted: the agent itself can
  suppress the gate (a fake live lock), like it can edit `settings.json`;
  this is a gate against accidents, not against a hostile agent.
- **conformance (T8)**: 0 important; 4 doc nits fixed (spec *As built*,
  plan T3 note, CHANGELOG Bash bullet, the suite time in `CLAUDE.md`).
  Left: `123c` takes ~19 s with 2 s stubs.

## Estimate vs actual

Filled at T4 from `actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation (min / tok) | Cause |
|---|---------|-----|--------|-----------|-------|
| T1 | implementer | 2m/160k | 1.1m/136k | -45% / -15% | none |
| T2 | implementer | 2m/200k | 3m/82k | 50% / -59% | ran the full suite once as a check |
| T3 | implementer | 3m/250k | 1.8m/145k | -40% / -42% | none |
| T4 | main | 4m/1500k | 8.2m/2454k | 105% / 64% | clean install failed `123a` (needs the repo), marked `repo_only`; full suites ~2 min each |
| T5 | verifier | 4m/600k | 91.2m/601k | 2180% / 0% | wall time: three real suite runs (~2 min each) plus waits; tokens on estimate |
| T6 | reviewer | 3m/660k | 3.7m/347k | 23% / -47% | none |
| T7 | reviewer | 3m/660k | 2.2m/242k | -27% / -63% | none |
| T8 | reviewer | 3m/660k | 1.1m/192k | -63% / -71% | none |
| T9 | implementer | 4m/350k | 4m/440k | 0% / 26% | none |

Over 50 %: T2 (minutes), T4 (both), T5 (wall clock, not work).

## Outside this plan

- After the developer installs 3.2.0: one live check that a red suite
  wakes the session (edit a hook so a case fails, wait, see the reminder).
- Running this hook for config files changed through Bash (spec G5).

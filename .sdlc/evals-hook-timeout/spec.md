# Spec: The config-change evals hook never finishes

- **Derived from**: `intent.md`
- **Status**: approved (2026-11-16, "Apruebo la spec": defaults G1–G6)
- **Approved by**: product owner (maintainer, 2026-11-16)

## Decisions to approve

| # | Decision | Default proposed | Why |
|---|----------|------------------|-----|
| G1 | Mode | `asyncRewake: true`, `timeout: 600`. The edit never waits; a red suite exits 2 and wakes Claude with the report; a green suite exits 0 and says nothing. | Red is what matters and must reach the model even after its turn ended; `async` only delivers on the next turn and never wakes it. 600 s leaves room for 111 s runs plus reruns (G2). |
| G2 | Bursts | Coalesce: at most one run at a time per suite, and at most one pending. An edit that finds a run in progress marks it pending and exits 0 at once; the running hook reruns once when it finishes, at most 3 runs per hook. A lock whose process is gone is taken over. | Ten edits in a minute would otherwise start ten 2-minute suites. The last run sees the latest state, which is the one that matters. |
| G3 | Scope | The whole suite, as today (with the installed profile in the source repo). | A file-to-cases map would need its own maintenance and its own evals; the time cost no longer blocks anyone once G1 is in. |
| G4 | Report size | On red: the `FAIL` lines (at most 40) and the `PASS:` summary line, not the whole output. | The full output is hundreds of lines; the model needs which cases failed. |
| G5 | Bash edits | Out of scope: `bash-file-check` does not dispatch this hook. Noted for later. | Dispatching an async hook from a sync one needs its own design (the result would have to reach the model from a detached process). |
| G6 | Release | Fold into 3.2.0, which is not committed or installed yet: same version, its CHANGELOG entry gains one bullet. | Avoids a version that nobody installs on its own. |

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | The evals hook is registered with `asyncRewake: true` and `timeout: 600`; `install.sh` carries both fields into the installed `settings.json`. | Problem; G1 | Scenario eval with `jq` on `settings.template.json` and on a clean test install, red first. |
| R2 | A red suite exits 2 with at most 40 `FAIL` lines plus the `PASS:` line on stderr, after "EVALS RED after modifying <file>". A green suite exits 0 with no output. | "How we will know": reported to the model; G4 | Scenario eval with a stub suite in a temp source repo (`WORKFLOW_HOME/source` pointing at it): stub with 60 FAIL lines → exit 2, 40 FAIL lines in stderr plus the summary; green stub → exit 0, empty stdout and stderr. |
| R3 | Coalescing: while a run is in progress, another invocation for the same suite exits 0 within 1 s without running it, and leaves a pending mark; the running hook reruns once; three invocations during one run give two runs in total. | "How we will know": a burst runs the suite once or twice; G2 | Scenario eval with a stub that sleeps 2 s and appends to a log: counts runs and the second invocation's duration. |
| R4 | A lock left by a process that no longer exists is taken over. | G2 | Scenario eval with a lock holding a dead pid → the suite runs. |
| R5 | Existing behavior kept: unrelated files ignored (`19e`), installed vs source suite choice, `EVALS_SKIP_REPO=1` (`111d`), no recursion (`CLAUDE_EVALS_RUNNING`). | Regression | `19b`, `19e`, `111d` green unchanged. |
| R6 | CHANGELOG 3.2.0 gains a bullet: the evals hook runs in the background, wakes Claude on red, coalesces bursts. | G6 | Suite, both profiles, `check-public.sh` no new hit, clean install green. |

**As built.** The lock is not in `TMPDIR`: an automated security note and
the main session moved it, after verification, to `$WORKFLOW_HOME/locks/<key>`
(`~/.claude/workflow/locks`), with the locks dir created mode 700, owner
checked, and no write through a symlink. A stricter variant of the design
below; recorded in plan T5 and the CHANGELOG. The red report matches the
status column (`FAIL (` or a trailing `FAIL`), not any line containing
"FAIL" (verifier nit).

## Design

- `settings.template.json`: the `Write|Edit|MultiEdit|NotebookEdit`
  PostToolUse entry for `evals-on-config-change.sh` gets
  `"asyncRewake": true` and `"timeout": 600`. Check that `install.sh`'s
  merge keeps unknown hook fields (it copies hook objects; verify).
- `hooks/evals-on-config-change.sh`, after the suite is chosen:
  - Lock: `mkdir "${TMPDIR:-/tmp}/claudio-evals-<key>"` where `<key>` is
    `cksum` of the suite path; the hook's pid in `pid` inside it. If
    `mkdir` fails and the pid in it is alive (`kill -0`), touch `pending`
    in the lock dir and exit 0. If the pid is dead, take the lock over.
  - Loop up to 3 times: remove `pending`, run the suite as today; stop when
    `pending` does not exist. Release the lock (remove the dir) on exit
    with a trap.
  - Report: the last run's result. Red → the G4 lines on stderr, exit 2.
    Green → exit 0, nothing printed.
- Lock directory: a symlink at that path is not followed (`[ -L ]` → exit
  0); the key has no user-controlled part.

## Policy applied

- **Personal data**: none.
- **Sensitive business data**: none; the report carries case names only.
- **Credentials**: none.
- **Decisions about people / high risk**: no.

## Out of scope

- Running evals for config files changed through Bash (G5).
- A faster or partial suite (G3).
- `claude -p` sessions: the hooks reference says async hooks still running
  at teardown are cancelled; a non-interactive run may never see the red.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `asyncRewake` behaves differently from the docs in this Claude Code version | No red reaches the model | Check once live after install (the plan has a step for it) |
| A suite run hangs past 600 s | Lock held until the hook is killed; next edits only mark pending | Dead-pid takeover (R4); the trap releases the lock on normal exit |
| Two sessions editing config at once share one lock | One session's red wakes only the session whose hook ran | Accepted: the lock is per suite; the pending rerun covers the other's edit |
| Background suite runs compete for CPU with the session | Slower turns for ~2 min after a config edit | At most one run at a time (G2) |

---
Next stage: Build reads this file and writes `plan.md`.

# Spec: File edits made through Bash skip the workflow's file hooks

- **Derived from**: `intent.md`
- **Status**: approved (2026-11-16, "Apruebo la spec": defaults E1–E6)
- **Approved by**: product owner (maintainer, 2026-11-16)

## What the hooks reference allows (read 2026-11-16, code.claude.com/docs/en/hooks)

- `PreToolUse` and `PostToolUse` on Bash carry `tool_use_id`; a
  `PostToolUse` hook that exits 2 "shows stderr to Claude; the tool already
  ran". It cannot undo the command.
- `FileChanged` fires for any change to a watched file, whatever made it, but
  watches only literal file names (or `watchPaths`), cannot block, and its
  `systemMessage` goes to the terminal, not to the model.
- No event blocks a file write made by a shell command before it happens,
  short of parsing the command (3.1.0 showed that fails open).

## Decisions to approve

| # | Decision | Default proposed | Why |
|---|----------|------------------|-----|
| E1 | Approach | **Check after the fact, then report to the model.** One new hook, `bash-file-check.sh`: on `PreToolUse(Bash)` it records a start marker; on `PostToolUse(Bash)` it lists the repo files that changed during that command and runs the existing guards on them, as if they had been written with Write/Edit. A hit exits 2: the model sees what it wrote and is told to fix it. | Reuses `credential-guard`, `test-guard`, `task-actuals` and `evals-on-config-change` unchanged; no shell parsing; works for `sed`, Python, heredocs, scripts. It cannot stop the write, only report it before the next step. |
| E2 | Steering | Also add one rule to `implementer.md` and `verifier.md` and one line to the `sdlc` skill: edit repo files with Edit or Write, not with shell; shell only for temp files. Core `global/CLAUDE.md` untouched (at budget). | Fewer writes reach the after-the-fact check; agents are where most edits run. The auto-mode instruction still pushes the other way, so E1 is the guarantee, E2 the habit. |
| E3 | Auto mode as the default | Keep `"defaultMode": "auto"`. | Changing it trades a silent gap for many permission prompts; E1 closes the gap without that cost. |
| E4 | Which files are checked | Files inside the git work tree of `cwd` that are modified or untracked (not ignored) and newer than the start marker. Outside a git repo: nothing checked, said in the docs. At most 50 files and 1 MB each per command; over that, one line to the model saying the check was skipped. | `git status` is cheap and already ignores build output; an ignored file (`.env`) is not committed, which is what the guards protect. |
| E5 | What each guard sees | `credential-guard`: the added lines of a tracked file (`git diff -U0`), the whole content of an untracked one. `test-guard`: removed lines as `old_string`, added lines as `new_string`, so its assertion-count and skip checks work as for Edit. `task-actuals` and `evals-on-config-change`: only `file_path`. | Same inputs the guards already understand; a credential already in the file before the command is not re-reported. |
| E6 | Message to the model | "Changed through Bash and checked after the fact: <guard message>. The file is already written: fix it with Edit now." | It must not read as "blocked": the write happened. |

## After review (2026-11-16)

Three IMPORTANT findings in the review of 3.2.0, and two developer decisions.

- **Git must not run repo code** (security pass). `git status` and
  `git diff` inside a repo the agent controls run `core.fsmonitor`, clean
  filters, `textconv` and `diff.external` from the repo's config, outside
  the Bash permission gate. Fix: list files with `git ls-files` (no content
  read) and `find -cnewer`, take old text with `git cat-file blob`, compare
  with `diff`; `-c core.fsmonitor=false`; `GIT_*` location variables unset;
  the top level must contain `cwd`.
- **Cost on dirty trees** (bugs pass): one `find` per listed file made a
  no-change command take ~6 s with 3000 untracked files. Fix: batch the
  `-cnewer` test.
- **E5 amended (developer, "Comparar con HEAD").** A tracked file is
  checked against HEAD: everything uncommitted in a touched file is checked,
  as untracked files already are; an old uncommitted hit can be reported
  again. Pinned by a scenario.
- **R4 dropped (developer, "Quitarlo y tarea aparte").** The suite takes
  ~85 s against the hook's 30 s timeout; a killed hook would lose the guard
  hits of that command. `bash-file-check` no longer runs the evals hook. The
  evals hook's own timeout (15 s on Write/Edit, already too short) is a
  separate task.
- **`PostToolUseFailure`**: a Bash command that writes and then fails fires
  it instead of `PostToolUse` (hooks reference); the hook handles both.

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | A credential-shaped value written to a repo file through Bash is reported to the model in the same turn. | "How we will know": credential written through Bash | Scenario eval: temp git repo, a `PreToolUse` then a `PostToolUse` payload around a command that wrote a fake `squ_…` value into a tracked file and into a new file → exit 2, stderr names the file and `credential-guard`. Red first. |
| R2 | A test file weakened through Bash (skip added, assertions removed, test commented out) is reported the same way. | Intent: test changed to pass | Scenario eval with each of the three cases → exit 2 naming `test-guard`; an added assertion → exit 0. |
| R3 | A `plan.md` status changed through Bash is measured by `task-actuals` as if it had been edited with Edit. | "How we will know": status change recorded whatever the tool | Scenario eval: `main` row moved to `in progress` then `done` with `sed`, each around a Bash payload → `actuals.jsonl` gets the start and close lines. |
| R4 | A change to a workflow config file through Bash triggers `evals-on-config-change` as Write/Edit does. | Intent: config changed through Bash | Scenario eval: `hooks/x.sh` touched through Bash → the evals hook runs (its own marker or output). |
| R5 | Nothing changes when no repo file changed, outside a git repo, or when only ignored files changed; the hook never fails a command on its own errors. | Risk of a new hook on every Bash call | Scenario evals: no change → exit 0, no output; non-git cwd → exit 0; ignored file → exit 0; missing marker → exit 0. |
| R6 | Limits: over 50 changed files or a file over 1 MB → one line to the model that the check was skipped for those files. | E4 | Scenario eval with 51 files. |
| R7 | Rule text: `implementer.md`, `verifier.md`, `sdlc` skill say to edit repo files with Edit or Write, shell only for temp files. | E2 | `file_contains` evals, red first; `SKILL.md` stays ≤ 160 lines. |
| R8 | Hook registered for `PreToolUse` and `PostToolUse` with matcher `Bash`; `install.sh` merges it. | — | `hook-registered` eval, `install-test.sh` green. |
| R9 | Release 3.2.0 (MINOR: new hook). No migration (project files untouched). `CHANGELOG.md` says what the check can and cannot do. | Repo `CLAUDE.md`, *Releasing* | Suite, profile suites, `check-public.sh` no new hit, clean install green. |

## Design

`hooks/bash-file-check.sh`, one script, branches on `hook_event_name`:

- **PreToolUse(Bash)**: `tool_use_id` validated as `[A-Za-z0-9_-]+`;
  touch `${TMPDIR:-/tmp}/claudio-bash-<tool_use_id>`. Exit 0 always.
- **PostToolUse(Bash)**: marker missing → exit 0. Else, from `cwd`,
  `git rev-parse --show-toplevel` (none → exit 0); `git status --porcelain
  -z` for modified and untracked paths; keep those with mtime newer than
  the marker (`find <path> -newer <marker>`); remove the marker. For each
  file, build a Write/Edit-shaped payload (E5) with `jq` and pipe it to
  `credential-guard.sh` and `test-guard.sh` (PreToolUse shape) and to
  `task-actuals.sh` and `evals-on-config-change.sh` (PostToolUse shape,
  with `transcript_path` and `session_id` carried over). Collect the
  guards' stderr; if any guard exited 2, print the E6 message and exit 2.
- Guards are called by path next to this script; none of them changes.
- Bash 3.2 and macOS `find`/`stat` compatible; no `sed -i`.

## Policy applied

- **Personal data**: none.
- **Sensitive business data**: none. The hook reads changed repo files
  locally and prints only the guard message, never the file content.
- **Credentials**: the point of R1. Fixtures use fake values built at
  runtime (`squ_` + generated), never written with Write/Edit.
- **Decisions about people / high risk**: no.

## Out of scope

- Blocking a shell write before it happens (no event allows it without
  parsing the command).
- Files outside the git work tree of `cwd`, and ignored files.
- `FileChanged` watching: it cannot reach the model; noted for later if the
  harness changes.
- Changing the auto-mode default (E3).

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `git status` on every Bash call in a large repo | Slower turns | Only when a marker exists; `-uno`-style limits and the 50-file cap; measure on this repo and a large one in Build |
| mtime resolution: a write in the same tick as the marker | Missed file | APFS and ext4 have sub-second mtimes; marker touched before the command starts |
| A file changed by another process (dev server, formatter) during the command | False report | The message names the file and guard; the model can say it did not write it |
| A guard's own false positive now also fires on Bash edits | More noise | Same placeholder filters as today; eval with a placeholder |
| Parallel Bash calls | Wrong attribution | Marker per `tool_use_id`; a file newer than either marker is checked by both, reported at most twice |

---
Next stage: Build reads this file and writes `plan.md`.

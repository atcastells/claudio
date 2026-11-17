# Plan: File edits made through Bash skip the workflow's file hooks

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-11-16, "Apruebo el plan")
- **Nothing is implemented until this file is approved.**

## Done means

- `hooks/bash-file-check.sh` registered on `PreToolUse` and `PostToolUse`
  (matcher `Bash`): a credential or a weakened test written through Bash is
  reported to the model with exit 2; a `plan.md` status changed through Bash
  is measured; a config change through Bash runs the evals hook; nothing
  happens without a changed repo file. Cases `122*` seen red first.
- Agents and the `sdlc` skill say to edit repo files with Edit or Write.
- The PostToolUse cost measured here and on a large repo, under the limit in
  *Stop and ask if*.
- 3.2.0: `bash evals/run.sh` FAIL 0 with both profiles, `check-public.sh`
  no new hit, clean install green; verifier and three reviewer passes, every
  IMPORTANT fixed.

## Stop and ask if

- Any of the four existing guards has to change to be called from the new
  hook (the spec says they stay unchanged).
- The PostToolUse branch costs more than 300 ms median per Bash call on the
  large repo (T7).
- An existing case changes its expectation.
- The task needs to open windows or apps on the developer's screen.

## Tasks

The *Status* column is updated as each task closes: it is the live list and
the resume point after compaction or a new session.

A delegated task covers at most 3 plan rows and leaves the tree building with
its tests green. Task IDs are `T<n>`, optionally with a letter.

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | `hooks/bash-file-check.sh` skeleton: `PreToolUse(Bash)` touches `${TMPDIR:-/tmp}/claudio-bash-<tool_use_id>` (id validated `[A-Za-z0-9_-]+`); `PostToolUse(Bash)` finds the git top level of `cwd`, lists modified and untracked non-ignored paths newer than the marker, removes the marker, and for now prints nothing. A function `changed_files` the next tasks call. Scenario script with a temp git repo. | `hooks/bash-file-check.sh`, `evals/scripts/bash-file-check-test.sh`, `evals/cases/122a-bash-file-check-quiet.json` | `122a` scenarios: no change → 0, silent; non-git cwd → 0; only an ignored file changed → 0; missing marker → 0; bad `tool_use_id` → 0 and no file created; `changed_files` lists a tracked edit and a new file, not a file older than the marker | R5 | implementer | — | 2m/160k | done |
| T2 | Dispatch to `credential-guard.sh` and `test-guard.sh` (PreToolUse shape, E5 inputs: added lines of tracked files via `git diff -U0`, whole content of untracked; removed lines as `old_string`); on any exit 2 print the E6 message with the guard's stderr and exit 2. Credential fixtures generated at runtime. | `hooks/bash-file-check.sh`, `evals/scripts/bash-file-check-test.sh`, `evals/cases/122b-bash-file-check-guards.json` | `122b` scenarios: fake `squ_` value added to a tracked file → 2 naming the file and `credential-guard`; same in a new file → 2; a credential already in the file before the command → 0; placeholder → 0; `.skip(` added, assertions removed, test commented out → 2 naming `test-guard`; assertion added → 0; message says the file is already written | R1, R2 | implementer | T1 | 3m/200k | done (diffs against HEAD, not the index: a file staged earlier is still checked) |
| T3 | Dispatch to `task-actuals.sh` and `evals-on-config-change.sh` (PostToolUse shape, `tool_name: Edit`, `file_path`, `transcript_path`, `session_id`, `cwd` carried over). Their exit codes never fail the command. | `hooks/bash-file-check.sh`, `evals/scripts/bash-file-check-test.sh`, `evals/cases/122c-bash-file-check-dispatch.json` | `122c` scenarios: a `main` row of `.sdlc/x/plan.md` moved to `in progress`, then `done (cause: none)`, each with `sed` around a Bash payload pair → `actuals.jsonl` gets the start and close lines (fixture transcript as in `task-actuals-test.sh`); a touched `hooks/x.sh` in a repo shaped like this one → the evals hook runs | R3, R4 | implementer | T2 | 3m/200k | done (the evals hook's exit 2 is surfaced, parity with Write/Edit; it runs at most once per command, on the first file it acts on; PostToolUse Bash timeout 30 s; suite 330/0) |
| T4 | Limits: over 50 changed files, or a file over 1 MB, → those files are skipped and one line tells the model so (exit 0 unless a checked file hit a guard). | `hooks/bash-file-check.sh`, `evals/scripts/bash-file-check-test.sh`, `evals/cases/122d-bash-file-check-limits.json` | `122d` scenarios: 51 new files → 0 with the skip line; a 2 MB file with a credential → 0 with the skip line; 50 files, one with a credential → 2 | R6 | implementer | T3 | 2m/160k | done (only-skipped case reaches the model as `additionalContext` with exit 0, a main correction to the spec's "one line"; suite 331/0) |
| T5 | Register `bash-file-check.sh` in `settings.template.json` for `PreToolUse` and `PostToolUse`, matcher `Bash`; check that `install.sh` merges both. | `settings.template.json`, `evals/cases/122e-hook-registered-bash-file-check.json` | `122e` red first (shape of `19a`); `evals/scripts/install-test.sh` green | R8 | implementer | T1 | 2m/160k | done (one `file_contains` case, it cannot tell the event; main checked a clean install with jq: PreToolUse Bash = production-gate, bash-file-check; PostToolUse Bash = bash-file-check) |
| T6 | Rule text: `implementer.md` and `verifier.md` Rules, and one line in the `sdlc` skill: edit repo files with Edit or Write; shell only for temp files. `SKILL.md` stays ≤ 160 lines. | `agents/implementer.md`, `agents/verifier.md`, `skills/sdlc/SKILL.md`, `evals/cases/122f*.json` | `122f1–f3` red first; case `79` (≤ 160) green | R7 | main | — | 3m/1.2M | done (cause: none; 122f1–f3 red then green; SKILL.md kept at 160 by rewrapping the Routing paragraph; suite 327/0) |
| T7 | Measure the PostToolUse branch: median of 20 runs on this repo and on a large repo clone (path given in the task prompt, not written here), with one changed file and with none. Write the numbers and the commands at the end of this plan. | `.sdlc/bash-edits-skip-hooks/plan.md` | Numbers in the findings, each with the command that produced it; the measurement fails if the hook is not on the path (checked by a run with a planted credential that must report) | Risks (spec) | main | T4 | 4m/1.5M | done (cause: none; 52/169 ms here, 75/190 ms on the large repo; planted credential reported in both) |
| T8 | 3.2.0: `VERSION`, `CHANGELOG.md` (what the check does and cannot do: no blocking before the write, git work tree only, ignored files skipped). Full suite, both profile suites, `check-public.sh`, clean install. Fill *Estimate vs actual*. | `VERSION`, `CHANGELOG.md`, `.sdlc/bash-edits-skip-hooks/plan.md` | The commands in "Verification commands" green | R9 | main | T5, T6, T7 | 5m/2M | done (cause: none; suite 331/0, company profile 342/0, example profile 332/0, check-public 26 old hits only, clean install 290/0) |
| T9 | Verify: the change (the hook against real `sed`, Python and heredoc writes in a temp repo; parallel Bash markers) and two adjacent flows: `credential-guard` and `test-guard` still block Write/Edit as before; `task-actuals` from Edit still records once, not twice, when the same row also changes through Bash. Suite result given by main. | — | Verifier report with commands and output | all | verifier | T8 | 4m/600k | done (amber: 1 IMPORTANT fixed by main red first, mtime → ctime so `mv`/`cp -p`/`tar` of an old file are checked; nit fixed: double period in the message; nit left: overlapping parallel calls report a file twice, as the spec allows) |
| T10 | Review pass: bugs | — | Findings per `REVIEW.md` | all | reviewer | T9 | 3m/660k | done (1 important: per-file `find` on dirty trees; 4 nits) |
| T11 | Review pass: security (marker paths, `tool_use_id`, file content never printed, symlinks in the changed list, a file path with spaces or newlines) | — | Findings per `REVIEW.md` | R1, R5 | reviewer | T9 | 3m/660k | done (1 important: repo git config runs code from the hook; 3 nits) |
| T12 | Review pass: conformance (bash 3.2, macOS `find`/`stat`, no `sed -i`, budgets, English, spec E1–E6) | — | Findings per `REVIEW.md` | all | reviewer | T9 | 3m/660k | done (1 important: E5 baseline is HEAD, not the state before the command; 4 nits) |
| T13 | Fix after review, security and cost: `changed_files` from `git -c core.fsmonitor=false ls-files -z` (tracked) and `ls-files -z -o --exclude-standard` (untracked) with one batched `find -cnewer`; old text from `git cat-file blob HEAD:<path>`, compared with `diff`; `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` unset; top level must contain `cwd`. | `hooks/bash-file-check.sh`, `evals/scripts/bash-file-check-test.sh`, `evals/cases/122g-bash-file-check-git-safe.json` | `122g` red first: fsmonitor, clean filter, textconv and `diff.external` planted in the temp repo never run; an added line starting with `++` is checked; `app/[i].txt` not blamed for `app/i.txt`; 3000 untracked files and no change in under 1.5 s; an uncommitted credential from before the command is reported again (E5 as amended); 122a–d green | After review (spec) | implementer | T12 | 4m/300k | done (git only through `git_safe`; no `git status`/`git diff`; 3000 untracked was 5.6 s, now under 1.5 s; suite 332/0) |
| T14 | Fix after review, scope: drop the evals-hook dispatch (R4) and its scenarios; handle and register `PostToolUseFailure` (matcher `Bash`); `tool_use_id` checked with `[[ =~ ]]` (no newline); a symlink at the marker path removed before `touch`; control characters in file names replaced before printing. | `hooks/bash-file-check.sh`, `evals/scripts/bash-file-check-test.sh`, `evals/cases/122c-bash-file-check-dispatch.json`, `evals/cases/122h-bash-file-check-failure-event.json`, `settings.template.json` | `122h` red first: a write then non-zero exit, sent as `PostToolUseFailure`, is reported; marker symlink not followed; a name with ESC and LF printed sanitized; `a<LF>b` id rejected; the evals hook is never run (122c changed, listed in Replaced tests); install merges the new event | After review (spec) | implementer | T13 | 3m/250k | done (main added one scenario red first: the skip context names the incoming event; suite 333/0) |
| T15 | Docs after review: CHANGELOG 3.2.0 limits (HEAD baseline, ctime, no evals run, marker removed or aged by the command, nested repos, background Bash, write plus `git commit` in one command); spec *As built*; `verifier.md` wording (it has no Edit/Write); test script header; hook header line. Fill *Review* and *Estimate vs actual*. | `CHANGELOG.md`, `agents/verifier.md`, `evals/cases/122f2-verifier-edit-with-tools.json`, `.sdlc/bash-edits-skip-hooks/*` | Suite, both profiles, `check-public.sh` no new hit, clean install | After review (spec) | main | T14 | 4m/1.5M | done (cause: a second security pass, T16, found 2 more important; fixed red first: `GIT_NO_LAZY_FETCH`, `diff -a`; suite 333/0, profiles 344/0 and 334/0, check-public 26 old hits only, clean install 292/0) |

- **Runs on**: `main` (Opus, the session); `implementer` (Sonnet 5.5);
  `verifier` / `reviewer` (Sonnet 5.5).
- **Est**: from `calibrate.sh` (2026-11-16): repo medians implementer
  2.0m/156k, main 3.1m/1.2M, verifier 3.0m/520k, reviewer 3.1m/656k. T2, T3
  sized above (two guards and fixtures each); T7 above (two repos, 80 runs);
  T9 above (real writes plus a parallel case).
- Each delegated task's prompt starts with `[sdlc:bash-edits-skip-hooks/T<n> est=<min>m/<ktok>k]`
  and says "read `.sdlc/delegation-hardening/context.md` first" (its
  *Learned* lines apply here).

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1, T6 | 3m | read T1's diff; suite |
| 2 | T2, T5 | 3m | `git diff --stat`; suite |
| 3 | T3 | 3m | suite |
| 4 | T4 | 2m | suite |
| 5 | T7 | 4m | stop if over 300 ms |
| 6 | T8 | 5m | — |
| 7 | T9 | 4m | read the verdict |
| 8 | T10, T11, T12 | 3m | fill *Review* |

T2, T3 and T4 edit the same hook and script: one after the other.

- **Estimated wall-clock**: ~27m (+ main checks)
- **Sequential sum**: 37m
- **Estimated tokens**: ~8.7M

## Order and dependencies

The skeleton (T1) fixes the marker and the changed-file list every dispatch
uses; guards (T2) before the measuring hooks (T3) because the exit-2 path is
the risky one; limits (T4) last because they wrap the loop. T7 measures the
finished hook.

## Test strategy

Red first for every case. All hook cases are scenario scripts in a
`mktemp -d` git repo, with payload pairs (`PreToolUse` then `PostToolUse`)
built with `jq`. Credential values are generated at runtime, never written
with Write/Edit. Text cases are `file_contains`.

- **Manual verification**: T9 writes through real `sed`, Python and a
  heredoc, not hand-made payloads only.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh status-line.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<company> bash evals/run.sh
WORKFLOW_PROFILE=profiles/example bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile --verbose
```

`check-public.sh` already exits 1 on `main` for older hits in
`.sdlc/claudio/`: the criterion is no new hit.

## Implementation risks

- The PostToolUse hook runs after every Bash call of every session: an error
  that exits 2 by accident would show noise on every command. Every failure
  path must exit 0 silently except a real guard hit.
- `git status` in a repo with many untracked files; `find -newer` on each.
- Dispatching `task-actuals` from Bash and from Edit for the same row: it
  already dedups by agent id for subagents; check `main` rows (T9).
- This session's own Bash calls will be checked once 3.2.0 is installed:
  fixtures with fake credentials live under `mktemp -d`, outside the repo.

## Review

Every IMPORTANT was fixed with a scenario seen red first.

- **verifier (T9)**: amber, 1 important fixed (mtime → ctime for moved or
  copied files).
- **bugs (T10)**: 1 important fixed in T13 (per-file `find` on dirty trees:
  6 s with 3000 untracked files, now under 1.5 s). Nits fixed: `++` lines,
  pathspec globbing, id with a newline. Left: overlapping parallel calls
  report a file twice (allowed by the spec).
- **security (T11)**: 1 important fixed in T13 (repo git config ran code
  through `git status`/`git diff`). Nits fixed: marker symlink, control
  characters in names. Documented: marker deleted or aged by the command,
  nested repos.
- **conformance (T12)**: 1 important resolved by the developer (E5 amended:
  baseline HEAD). Nits fixed: verifier wording, test header, CHANGELOG
  limits. Developer also dropped R4 (evals run), its timeout made the hook
  lose guard hits.
- **security, second pass (T16)**: 2 important fixed by main, red first
  (`GIT_NO_LAZY_FETCH`: a partial clone ran its `uploadpack`; `diff -a`:
  a NUL byte hid a tracked file's lines). Documented: files hidden by an
  exclude file the command can edit. Left: a background process swapping a
  listed file for a FIFO could hang the hook until its timeout (not
  demonstrated).

## Estimate vs actual

Filled at T8 from `actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation (min / tok) | Cause |
|---|---------|-----|--------|-----------|-------|
| T1 | implementer | 2m/160k | 1.6m/179k | -20% / 12% | none |
| T2 | implementer | 3m/200k | 2.4m/197k | -20% / -2% | none |
| T3 | implementer | 3m/200k | 3.4m/358k | 13% / 79% | evals hook test setup (`CLAUDE_EVALS_RUNNING`, `WORKFLOW_HOME`) |
| T4 | implementer | 2m/160k | 5.1m/340k | 155% / 113% | main changed the brief mid-task (additionalContext); a shell edit denied by the auto-mode classifier, redone with Edit |
| T5 | implementer | 2m/160k | 5.1m/362k | 155% / 126% | two install attempts denied; ran the whole suite to see one case |
| T6 | main | 3m/1200k | 2.2m/1661k | -27% / 38% | SKILL.md at its budget, a paragraph rewrapped |
| T7 | main | 4m/1500k | 0.6m/362k | -85% / -76% | the script was written before the row moved to in progress, so the clock missed it |
| T8 | main | 5m/2000k | 6.2m/730k | 24% / -64% | none |

| T9 | verifier | 4m/600k | 2.6m/372k | -35% / -38% | none |
| T10 | reviewer | 3m/660k | 3.7m/570k | 23% / -14% | none |
| T11 | reviewer | 3m/660k | 2.5m/503k | -17% / -24% | none |
| T12 | reviewer | 3m/660k | 4.6m/778k | 53% / 18% | timed the suite and ran a probe repo |
| T13 | implementer | 4m/300k | 6.6m/396k | 65% / 32% | four planted-config scenarios plus a 3000-file timing |
| T14 | implementer | 3m/250k | 5m/421k | 67% / 68% | a shell rewrite denied by the auto-mode classifier, redone with Edit |
| T15 | main | 4m/1500k | 79.1m/4779k | 1877% / 219% | the clock stayed open while T16 ran (62 min) and its two findings were fixed |
| T16 | reviewer | 3m/660k | 62.1m/1000k | 1970% / 52% | wall time, not work: 28 tool calls; the long wait is not explained by its report (denied `rm -r` calls) |

Over 50 %: T3 (tokens), T4 and T5 (both), T7 (under, clock artefact), T12,
T13, T14 (minutes), T15 and T16 (wall clock, see causes).

## Replaced tests

| Scenario | Before | After | Why |
|----------|--------|-------|-----|
| `dispatch` mode (122c) | the evals hook ran once per command and its exit 2 was surfaced | the evals hook must never run | R4 dropped by the developer after review |
| `122f2` | verifier "edit repo files with Edit or Write" | "never change repo files; shell writes only to temp files" | the verifier has no Edit or Write (conformance nit) |
| `changed_files` in `bash-file-check-test.sh` (122a) | a file written after the marker with a back-dated mtime was expected absent | expected present; plus a file moved in (present) and a file untouched since before the marker (absent) | the old expectation encoded the bypass the verifier found: `mv`, `cp -p` and `tar` keep an old mtime |

## T7 findings (2026-11-16)

PostToolUse branch, median of 20 runs each, on a local clone (`git clone
--local` under `mktemp -d`), repo copy of the hook, MacBook, warm cache.
Script: `measure.sh <hook> <repo> <label>` in the session scratchpad (Pre
payload, the change, then a timed Post payload; `perl Time::HiRes`).

| Repo | Tracked files | No change | One changed file |
|------|---------------|-----------|------------------|
| this repo | 525 | 52 ms | 169 ms |
| large repo (path in the task prompt) | 2003 | 75 ms | 190 ms |

The measurement could fail: in both clones a planted fake credential in the
changed file made the hook exit 2. Under the 300 ms stop limit. Not
measured: a repo with tens of thousands of untracked files, and a run where
the evals hook fires (that one runs the suite, as Write/Edit already does).

## Outside this plan

- Blocking a shell write before it happens; files outside the git work
  tree; ignored files; `FileChanged` (spec, *Out of scope*).
- The real install into `~/.claude` (ask first).
- The two 3.1.0 nits left open: slow report check on thousands of empty
  `Red:` lines, report marker following a dangling symlink.

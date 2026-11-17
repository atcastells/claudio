# Context: bash-edits-skip-hooks

Written only by the main session. Subagents: read this first, then
`../delegation-hardening/context.md` (its Learned lines apply here too).

## Decisions

- Spec E1–E6 approved as defaults (2026-11-16): check after the fact on
  `PostToolUse(Bash)`, exit 2 only on a real guard hit; the four existing
  guards are called unchanged.

## Learned

- `hooks/bash-file-check.sh`: sourcing it defines
  `changed_files <toplevel> <marker>` (NUL-separated absolute paths) without
  running main (guard `[ "${BASH_SOURCE[0]}" = "$0" ]`). Pass the result of
  `git rev-parse --show-toplevel` as toplevel: on macOS `mktemp -d` paths
  resolve to `/private/...`.
- Main branch is `bash_file_check_main`; T2–T4 extend its PostToolUse case,
  where the list is currently discarded. Marker removal is in place.
- `check_changed <top> <marker> <cwd> <payload>` runs the guards, then
  `dispatch_file` per file (task-actuals for `*/.sdlc/*/plan.md`, the evals
  hook once per command). Output is printed only at the end.
- Testing `evals-on-config-change.sh` needs `unset CLAUDE_EVALS_RUNNING` and a
  `WORKFLOW_HOME/source` naming the resolved toplevel.
- Since T13: every git call goes through `git_safe` (`-c core.fsmonitor=false
  -C <top>`), `GIT_*` location variables are unset, and only `rev-parse`,
  `ls-files` and `cat-file` are used. Never add `git status` or `git diff`:
  they run repo-config code (fsmonitor, filters, textconv, diff.external).
- `changed_files` = `ls-files -z` (tracked) + `ls-files -z -o
  --exclude-standard`, filtered by one batched `find -prune -type f -cnewer`.
- Tracked files are compared with `git cat-file blob HEAD:<rel>` through
  plain `diff`: baseline is HEAD (spec E5 as amended).
- The evals-hook dispatch is being removed (R4 dropped).

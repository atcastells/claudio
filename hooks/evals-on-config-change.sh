#!/bin/bash
# evals-on-config-change: runs the eval suite when the agent's own configuration
# changes. Playbook rule: evals run whenever CLAUDE.md, skills or hooks change.
# No CI yet — this is the local gate.
# PostToolUse hook on Write|Edit|MultiEdit|NotebookEdit. Exit 2 reports red evals.

payload=$(cat)
path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
[ -z "$path" ] && exit 0

home="${WORKFLOW_HOME:-$HOME/.claude/workflow}"
src=$(cat "$home/source" 2>/dev/null)

# Installation (~/.claude) or the workflow source repo; each has its own suite
suite=""
case "$path" in
  */.claude/CLAUDE.md|*/.claude/settings.json) suite="$HOME/.claude/evals/run.sh" ;;
  */.claude/hooks/*|*/.claude/skills/*|*/.claude/agents/*|*/.claude/evals/*) suite="$HOME/.claude/evals/run.sh" ;;
esac
if [ -z "$suite" ] && [ -n "$src" ]; then
  case "$path" in
    "$src"/global/*|"$src"/hooks/*|"$src"/skills/*|"$src"/agents/*|"$src"/evals/*|"$src"/migrations/*|"$src"/profiles/*|"$src"/settings.template.json|"$src"/VERSION)
      suite="$src/evals/run.sh" ;;
  esac
fi
[ -z "$suite" ] && exit 0

# Never recurse: the suite itself writes nothing, but be explicit about it.
[ -n "${CLAUDE_EVALS_RUNNING:-}" ] && exit 0
export CLAUDE_EVALS_RUNNING=1

# One run at a time per suite: a concurrent invocation leaves a "pending" mark
# and returns; the running one repeats (max 3 runs) and reports the last run.
key=$(printf '%s' "$suite" | cksum | cut -d' ' -f1)
# The lock lives in the user's own workflow dir, not in a shared TMPDIR
locks="$home/locks"
lock="$locks/$key"
held=""      # the dir this process must remove on exit
child=""     # the suite process, while it runs
work=""      # scratch dir when there is no usable lock

mtime_of() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

# Live = a real hook process and a recent pid file. An empty pid is a peer that
# has just created the dir: live for 5 s only.
lock_is_live() {
  [ -L "$lock/pid" ] && return 1
  local pid m
  pid=$(cat "$lock/pid" 2>/dev/null)
  if [ -z "$pid" ]; then
    m=$(mtime_of "$lock") && [ -n "$m" ] || return 1
    [ $(( $(date +%s) - m )) -lt 5 ]
    return
  fi
  case "$pid" in *[!0-9]*) return 1 ;; esac
  [ "$pid" -gt 1 ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  ps -p "$pid" -o command= 2>/dev/null | grep -q 'evals-on-config-change' || return 1
  [ -n "$(find "$lock/pid" -mmin -11 2>/dev/null)" ]
}

# Atomic: a reader never sees a half-written pid
write_pid() {
  rm -f "$lock/pid.$$"
  printf '%s' "$$" > "$lock/pid.$$" 2>/dev/null && mv -f "$lock/pid.$$" "$lock/pid" 2>/dev/null
}

mark_pending() { [ -L "$lock/pending" ] || touch "$lock/pending" 2>/dev/null; }

# 0 = held, 1 = a live peer owns it (pending marked), 2 = lock dir unusable
acquire() {
  if ! mkdir "$lock" 2>/dev/null; then
    [ -d "$lock" ] && [ -O "$lock" ] || return 2
    if lock_is_live; then mark_pending; return 1; fi
    # Only one taker wins the rename of a stale lock
    rm -rf "$lock.stale.$$"
    mv "$lock" "$lock.stale.$$" 2>/dev/null
    rm -rf "$lock.stale.$$"
    if ! mkdir "$lock" 2>/dev/null; then
      [ -d "$lock" ] && [ -O "$lock" ] && [ ! -L "$lock" ] || return 2
      mark_pending
      return 1
    fi
  fi
  held="$lock"
  write_pid || { rm -rf "$lock"; held=""; return 2; }
  return 0
}

trap 'rm -rf "$lock.released.$$" "$lock.stale.$$"; [ -n "$held" ] && rm -rf "$held"; [ -n "$work" ] && rm -rf "$work"' EXIT
trap '[ -n "$child" ] && kill "$child" 2>/dev/null; exit 1' INT TERM HUP

locked=0
if [ ! -L "$locks" ] && mkdir -p "$locks" 2>/dev/null && [ -O "$locks" ] && chmod 700 "$locks" 2>/dev/null; then
  [ -L "$lock" ] && exit 0
  acquire
  case $? in
    0) locked=1 ;;
    1) exit 0 ;;
  esac
fi
if [ "$locked" -eq 0 ]; then
  work=$(mktemp -d 2>/dev/null) || exit 0
fi

# Source repo: also run the installed profile's cases
profile_dir=$(cat "$home/profile" 2>/dev/null)
runs=0
capped=0
while :; do
  runs=$((runs + 1))
  if [ "$locked" -eq 1 ]; then outf="$lock/out"; rm -f "$lock/pending"; else outf="$work/out"; fi
  if [ -n "$src" ] && [ "$suite" = "$src/evals/run.sh" ] && [ -d "$profile_dir" ]; then
    EVALS_SKIP_REPO=1 WORKFLOW_PROFILE="$profile_dir" bash "$suite" >"$outf" 2>&1 &
  else
    EVALS_SKIP_REPO=1 bash "$suite" >"$outf" 2>&1 &
  fi
  child=$!
  wait "$child"
  code=$?
  child=""
  out=$(cat "$outf" 2>/dev/null)
  [ "$locked" -eq 1 ] || break
  if [ -e "$lock/pending" ] && [ "$runs" -lt 3 ]; then continue; fi

  # Test-only: widens the window between the last check and the release
  [ -n "${EVALS_HOOK_TEST_PAUSE:-}" ] && sleep "$EVALS_HOOK_TEST_PAUSE"
  # Release by renaming: a peer arriving after this sees no lock and runs itself;
  # one that marked pending before the rename is found in the renamed dir
  held="$lock.released.$$"
  mv "$lock" "$held" 2>/dev/null || { held="$lock"; break; }
  if [ -e "$held/pending" ]; then
    if [ "$runs" -lt 3 ]; then
      rm -rf "$held"
      held=""
      # If mkdir fails, a newer invocation owns the lock and will run
      mkdir "$lock" 2>/dev/null || break
      held="$lock"
      write_pid || break
      continue
    fi
    capped=1
  fi
  break
done

if [ "$code" -ne 0 ]; then
  # The status column, not a case name that happens to contain FAIL
  fails=$(printf '%s\n' "$out" | grep -aE 'FAIL \(|FAIL$' | grep -av '^PASS:' | head -n 40)
  summary=$(printf '%s\n' "$out" | grep -a '^PASS:' | tail -n 1)
  {
    printf '%s\n' "EVALS RED after modifying $(basename "$path")."
    [ -n "$fails" ] && printf '%s\n' "$fails"
    [ -n "$summary" ] && printf '%s\n' "$summary"
    if [ -z "$fails" ] && [ -z "$summary" ]; then
      printf '%s\n' "suite exited $code without a summary; last lines:"
      printf '%s\n' "$out" | tail -n 20
    fi
    [ "$capped" -eq 1 ] && printf '%s\n' "Edits after the third run are not covered: edit again to rerun."
    printf '%s\n' "The agent's configuration changed and the suite no longer passes. Fix this
before continuing: a control that is not verified is not a control."
  } >&2
  exit 2
fi

exit 0

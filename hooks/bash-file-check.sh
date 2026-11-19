#!/bin/bash
# bash-file-check: finds the repo files a Bash command changed, so the file
# guards can check them as if they had been written with Write/Edit.
# PreToolUse(Bash): records a start marker per tool_use_id in ${TMPDIR:-/tmp}
# (a symlink at that path is removed first, never followed).
# PostToolUse(Bash) and PostToolUseFailure(Bash): a command that writes and
# then exits non-zero fires the second. Lists tracked or untracked,
# non-ignored files whose ctime is newer than the marker, then removes the
# marker. Any other event or tool: nothing.
# Runs credential-guard and test-guard on each changed file (E5); a guard hit
# exits 2 with its message. A tracked file is compared with HEAD, so every
# uncommitted line of a touched file is checked. task-actuals is told about a
# changed plan.md. The evals suite is never run here (too slow for the hook).
# An internal error is silent, exit 0. File names are printed with control
# characters replaced by "?". Sourcing defines changed_files without running.
# Limits (E4): only the first 50 changed files are checked and a file over
# 1 MB is skipped. With nothing else to report, the skip is passed on as
# stdout JSON (hookSpecificOutput.additionalContext, exit 0) so the model
# reads it; with a guard hit, the skip line is added to the exit-2 report. A
# skipped file is never reported by itself: it was not checked.
#   changed_files <toplevel> <marker>  -> absolute paths, NUL-separated
# Git runs inside a repo the agent controls, so only rev-parse, ls-files and
# cat-file are used (never status or diff), with core.fsmonitor off and the
# GIT_* location variables unset; the top level must contain cwd.

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
# A partial clone would fetch a missing blob and run the repo's uploadpack
export GIT_NO_LAZY_FETCH=1

git_safe() { # <toplevel> <git args...>
  local top="$1"; shift
  git -c core.fsmonitor=false -C "$top" "$@"
}

changed_files() {
  local top="$1" marker="$2" f
  [ -d "$top" ] && [ -e "$marker" ] || return 0
  # Only ls-files: it reads no file content, so no filter, textconv or fsmonitor
  # from the repo's config runs. Absolute paths, then one batched find; ctime,
  # not mtime: mv, cp -p and tar keep an old mtime but change ctime.
  {
    git_safe "$top" ls-files -z
    git_safe "$top" ls-files -z -o --exclude-standard
  } 2>/dev/null |
    while IFS= read -r -d '' f; do printf '%s\0' "$top/$f"; done |
    xargs -0 sh -c '[ "$#" -gt 0 ] || exit 0; find "$@" -prune -type f -cnewer "$0" -print0' "$marker" 2>/dev/null
  return 0
}

# guard_payload <toplevel> <file> <cwd> <tmpdir> [session_id]: prints a PreToolUse-shaped
# Edit payload (tracked file: added and removed lines) or Write payload
# (untracked file: whole content) for the file guards.
guard_payload() {
  local top="$1" f="$2" cwd="$3" tmp="$4" sid="${5:-}" rel
  rel="${f#"$top"/}"
  if git_safe "$top" cat-file -e "HEAD:$rel" 2>/dev/null; then
    git_safe "$top" cat-file blob "HEAD:$rel" >"$tmp/head" 2>/dev/null
    diff -a "$tmp/head" "$f" 2>/dev/null | grep -a '^< ' | sed 's/^< //' >"$tmp/old"
    diff -a "$tmp/head" "$f" 2>/dev/null | grep -a '^> ' | sed 's/^> //' >"$tmp/new"
    jq -n --arg p "$f" --arg cwd "$cwd" --arg sid "$sid" --rawfile o "$tmp/old" --rawfile n "$tmp/new" \
      '{hook_event_name:"PreToolUse",tool_name:"Edit",cwd:$cwd,session_id:$sid,tool_input:{file_path:$p,old_string:$o,new_string:$n}}'
  else
    jq -n --arg p "$f" --arg cwd "$cwd" --arg sid "$sid" --rawfile c "$f" \
      '{hook_event_name:"PreToolUse",tool_name:"Write",cwd:$cwd,session_id:$sid,tool_input:{file_path:$p,content:$c}}'
  fi
}

# dispatch_file <file> <incoming payload>: after the guards, tells task-actuals
# about a changed plan.md, as if it had been written with Edit. Its output and
# exit code are ignored.
dispatch_file() {
  local f="$1" in="$2" here pl
  here=$(dirname "$0")
  case "$f" in
    */.sdlc/*/plan.md) ;;
    *) return 0 ;;
  esac
  [ -f "$here/task-actuals.sh" ] || return 0
  pl=$(printf '%s' "$in" | jq -c --arg p "$f" \
    '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$p},cwd:(.cwd // ""),session_id:(.session_id // ""),transcript_path:(.transcript_path // "")}' 2>/dev/null) || return 0
  printf '%s' "$pl" | bash "$here/task-actuals.sh" >/dev/null 2>&1
  return 0
}

# check_changed <toplevel> <marker> <cwd> <payload>: runs the file guards on each
# changed file, then dispatches it. Prints the report on stdout and returns 2
# when any guard blocked.
check_changed() {
  local top="$1" marker="$2" cwd="$3" payload="$4" here tmp f g err rc hit=0 seen=0 skipped=0 size line rel
  here=$(dirname "$0")
  tmp=$(mktemp -d 2>/dev/null) || return 0
  while IFS= read -r -d '' f; do
    seen=$((seen + 1))
    size=$(wc -c <"$f" 2>/dev/null | tr -d ' ')
    if [ "$seen" -gt 50 ] || [ "${size:-0}" -gt 1048576 ]; then
      skipped=$((skipped + 1))
      continue
    fi
    rel="${f#"$top"/}"; rel="${rel//[[:cntrl:]]/?}"
    for g in credential-guard test-guard; do
      [ -f "$here/$g.sh" ] || continue
      err=$(guard_payload "$top" "$f" "$cwd" "$tmp" "$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)" | bash "$here/$g.sh" 2>&1 >/dev/null)
      rc=$?
      if [ "$rc" -eq 2 ]; then
        hit=1
        err="${err//[[:cntrl:]]/?}"
        printf 'Changed through Bash and checked after the fact (%s): %s The file is already written: fix it with Edit now.\n' "$rel" "${err%.}."
      fi
    done
    dispatch_file "$f" "$payload"
  done < <(changed_files "$top" "$marker")
  rm -rf "$tmp"
  line="bash-file-check: skipped $skipped changed files (over 50 per command or over 1 MB); they were not checked."
  if [ "$hit" -eq 1 ]; then
    [ "$skipped" -gt 0 ] && printf '%s\n' "$line"
    return 2
  fi
  # Nothing blocked: the skip travels as context for the model (exit 0, stdout JSON).
  [ "$skipped" -gt 0 ] && jq -n --arg c "$line" \
    --arg e "$(printf '%s' "$payload" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null)" \
    '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
  return 0
}

bash_file_check_main() {
  local payload event tool id cwd marker top phys rc=0
  payload=$(cat)
  event=$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)
  tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)
  [ "$tool" = "Bash" ] || return 0
  id=$(printf '%s' "$payload" | jq -r '.tool_use_id // ""' 2>/dev/null)
  [[ "$id" =~ ^[A-Za-z0-9_-]+$ ]] || return 0
  marker="${TMPDIR:-/tmp}/claudio-bash-$id"

  case "$event" in
    PreToolUse)
      [ -L "$marker" ] && rm -f "$marker"
      touch "$marker" 2>/dev/null
      ;;
    PostToolUse|PostToolUseFailure)
      [ -e "$marker" ] || return 0
      cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)
      top=$(git_safe "$cwd" rev-parse --show-toplevel 2>/dev/null)
      phys=$(cd "$cwd" 2>/dev/null && pwd -P)
      # The top level must contain cwd: a .git file or core.worktree can point elsewhere
      case "$phys/" in "${top%/}/"*) ;; *) top="" ;; esac
      if [ -z "$top" ]; then
        rm -f "$marker"
        return 0
      fi
      check_changed "$top" "$marker" "$cwd" "$payload"
      rc=$?
      rm -f "$marker"
      return "$rc"
      ;;
  esac
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  # The report travels on stdout out of the subshell; only a real guard hit
  # (status 2) reaches stderr. Status 0 with output is the skip notice (JSON),
  # passed on to stdout. Any other failure stays silent, exit 0.
  report=$(bash_file_check_main 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 2 ] && [ -n "$report" ]; then
    printf '%s\n' "$report" >&2
    exit 2
  fi
  [ "$rc" -eq 0 ] && [ -n "$report" ] && printf '%s\n' "$report"
  exit 0
fi

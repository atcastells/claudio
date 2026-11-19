#!/bin/bash
# orchestrator-guard: in Orchestrate mode the main session plans and decides; the
# integrator agent does the work. PreToolUse on Write|Edit|MultiEdit|NotebookEdit|Bash.
# Acts only when the session's orch marker exists.
# Main session (no agent_id), exit 2 = block. Allowed there:
#   - writes under a chain: .sdlc/<slug>/ of the repo that holds cwd (found by
#     walking up, so a cd into .sdlc/ does not matter), or an existing chain of
#     another repo (.sdlc/<slug>/ with intent, spec, plan or context.md). The
#     chain written becomes the session's active chain (lib/chain.sh);
#   - plain read-only git (status, diff, log, blame, show), also as git -C <dir>;
#   - git add, commit and push, always answered with permissionDecision "ask";
#   - calibrate.sh and the orchestrate clean.sh;
#   no chaining, substitution or redirection.
# Agents (agent_id set): git add/commit/push are blocked; an Edit/Write of a file
# another agent of the active chain edited in the last hour gets a warning
# (stdout JSON, exit 0): re-read it first.

. "$(dirname "$0")/lib/mode.sh"
. "$(dirname "$0")/lib/chain.sh"

payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
mode_is_orch "$sid" || exit 0
aid=$(printf '%s' "$payload" | jq -r '.agent_id // ""' 2>/dev/null)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)

block() {
  printf '%s\n' "BLOCKED by orchestrator-guard: Orchestrate mode, the main session does not $1.
Delegate it to the integrator agent (it edits, runs tests and launches the other agents) and read the artifact it returns. Allowed here: writing under .sdlc/<slug>/ (this repo's or the active chain's), read-only git, git add/commit/push (the developer confirms). /orchestrate off leaves the mode." >&2
  exit 2
}

# git_words <cmd>: prints "<verb> <rest>" of a git command, skipping one -C <dir>;
# returns 1 when it is not git
git_words() {
  local w1 w2 w3 rest
  read -r w1 w2 rest <<< "$1"
  [ "$w1" = git ] || return 1
  if [ "$w2" = -C ]; then read -r w3 w2 rest <<< "$rest"; [ -n "$w3" ] || return 1; fi
  printf '%s %s\n' "$w2" "$rest"
}

# --- Agents --------------------------------------------------------------
if [ -n "$aid" ]; then
  case "$tool" in
    Bash)
      if gw=$(git_words "$cmd"); then
        case "${gw%% *}" in add|commit|push)
          printf '%s\n' "BLOCKED by orchestrator-guard: in Orchestrate mode the integrator and its agents do not write to git. Report what is ready in your artifact; the main session commits with the developer's confirmation." >&2
          exit 2 ;;
        esac
      fi
      ;;
    Write|Edit|MultiEdit|NotebookEdit)
      chain=$(chain_active "$sid") || exit 0
      printf '%s' "$aid" | grep -qE '^[A-Za-z0-9_-]+$' || exit 0
      f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
      [ -n "$f" ] || exit 0
      case "$f" in /*) ;; *) [ -n "$cwd" ] && f="${cwd%/}/$f" || exit 0 ;; esac
      case "$f" in "$chain"/*) exit 0 ;; esac
      dir="$chain/work/.edits"
      mkdir -p "$dir" 2>/dev/null || exit 0
      key=$(printf '%s' "$f" | cksum | tr ' ' '-')
      rec="$dir/$key"
      other=""
      if [ -f "$rec" ] && [ ! -L "$rec" ] && [ -n "$(find "$rec" -mmin -60 2>/dev/null)" ]; then
        other=$(head -n 1 "$rec" 2>/dev/null)
      fi
      [ -L "$rec" ] && rm -f "$rec"
      printf '%s\n' "$aid" > "$rec" 2>/dev/null
      if [ -n "$other" ] && [ "$other" != "$aid" ]; then
        jq -n --arg c "orchestrator-guard: another agent of this chain edited $(basename "$f") in the last hour. Read the file again right before this edit and keep its changes; mention the shared file in your report." \
          '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$c}}'
      fi
      ;;
  esac
  exit 0
fi

# --- Main session --------------------------------------------------------
case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit)
    f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
    [ -n "$f" ] && [ -n "$cwd" ] || block "edit files"
    case "$f" in /*) ;; *) f="${cwd%/}/$f" ;; esac
    case "/$f/" in */../*|*/./*) block "edit files outside .sdlc/<slug>/" ;; esac
    # Physical path: the deepest existing directory resolved, the rest appended
    d=$(dirname "$f")
    while [ ! -d "$d" ]; do d=$(dirname "$d"); done
    pd=$(cd "$d" 2>/dev/null && pwd -P) || block "edit files outside .sdlc/<slug>/"
    tail="${f#"$d"}"
    pf="${pd%/}$tail"
    chain=$(printf '%s' "$pf" | sed -nE 's#^(.*/\.sdlc/[a-z0-9-]+)/.+$#\1#p')
    [ -n "$chain" ] || block "edit files outside .sdlc/<slug>/"
    case "$chain" in */.sdlc/*/.sdlc/*) block "edit files outside .sdlc/<slug>/" ;; esac
    root=$(sdlc_root "$cwd")
    if [ -n "$root" ] && [ "$chain" = "$root/.sdlc/$(basename "$chain")" ]; then
      chain_set "$sid" "$chain"; exit 0
    fi
    chain_ok "$chain" || block "edit files outside .sdlc/<slug>/ (another repo's chain must already hold intent, spec, plan or context.md)"
    chain_set "$sid" "$chain"
    exit 0
    ;;
  Bash)
    case "$cmd" in *[\;\&\|\`\$\>\<\(\)]*|*$'\n'*) block "run commands (only plain git and the orchestrate scripts)" ;; esac
    read -r w1 w2 rest <<< "$cmd"
    if [ "$w1" = bash ]; then
      case "$w2" in
        "~/.claude/skills/sdlc/calibrate.sh"|"$HOME/.claude/skills/sdlc/calibrate.sh") exit 0 ;;
        "~/.claude/skills/orchestrate/clean.sh"|"$HOME/.claude/skills/orchestrate/clean.sh") exit 0 ;;
      esac
    fi
    gw=$(git_words "$cmd") || block "run commands, explore or run tests"
    verb="${gw%% *}"
    case "$verb" in
      status|diff|log|blame|show)
        case " ${gw#* } " in *" --ext-diff"*|*" --output"*|*" --textconv"*) block "run git with external tools" ;; esac
        exit 0 ;;
      add|commit|push)
        case " ${gw#* } " in *" --no-verify"*|*" -n "*|*" --force"*|*" -f "*) block "skip git hooks or force a push" ;; esac
        # Always the developer's call, also for git -C forms no permission rule matches
        jq -n --arg r "Orchestrate mode: git $verb from the main session needs the developer's confirmation." \
          '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask", permissionDecisionReason:$r}}'
        exit 0 ;;
      *) block "run git $verb" ;;
    esac
    ;;
esac
exit 0

#!/bin/bash
# orchestrator-guard: in Orchestrate mode the main session plans and decides; the
# integrator agent does the work. PreToolUse on Write|Edit|MultiEdit|NotebookEdit|Bash.
# Blocks (exit 2) only when the session's orch marker exists and the call comes from
# the main session (no agent_id). Allowed there: writes under <cwd>/.sdlc/<slug>/ and
# read-only git (status, diff, log, blame, show) and calibrate.sh, with no chaining
# or redirection.

. "$(dirname "$0")/lib/mode.sh"

payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
mode_is_orch "$sid" || exit 0
aid=$(printf '%s' "$payload" | jq -r '.agent_id // ""' 2>/dev/null)
[ -n "$aid" ] && exit 0
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)

block() {
  printf '%s\n' "BLOCKED by orchestrator-guard: Orchestrate mode, the main session does not $1.
Delegate it to the integrator agent (it edits, runs tests and launches the other agents) and read the artifact it returns. Allowed here: writing under .sdlc/<slug>/ and read-only git. /orchestrate off leaves the mode." >&2
  exit 2
}

case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit)
    f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
    [ -n "$f" ] && [ -n "$cwd" ] || block "edit files"
    case "$f" in /*) ;; *) f="${cwd%/}/$f" ;; esac
    case "/$f/" in */../*|*/./*) block "edit files outside .sdlc/<slug>/" ;; esac
    base="${cwd%/}/.sdlc/"
    rel="${f#"$base"}"
    [ "$rel" != "$f" ] || block "edit files outside .sdlc/<slug>/"
    printf '%s' "$rel" | grep -qE '^[a-z0-9-]+/.+' || block "edit files outside .sdlc/<slug>/"
    # A symlinked directory must still resolve inside the repo's .sdlc/
    d=$(dirname "$f")
    while [ ! -d "$d" ]; do d=$(dirname "$d"); done
    pd=$(cd "$d" 2>/dev/null && pwd -P) || block "edit files outside .sdlc/<slug>/"
    pc=$(cd "$cwd" 2>/dev/null && pwd -P) || block "edit files outside .sdlc/<slug>/"
    case "$pd/" in "$pc"/.sdlc/*) exit 0 ;; esac
    block "edit files outside .sdlc/<slug>/"
    ;;
  Bash)
    cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)
    case "$cmd" in *[\;\&\|\`\$\>\<\(\)]*|*$'\n'*) block "run commands (only plain read-only git)" ;; esac
    read -r w1 w2 rest <<< "$cmd"
    # Estimating the plan needs calibrate.sh, which only reads
    if [ "$w1" = bash ]; then
      case "$w2" in "~/.claude/skills/sdlc/calibrate.sh"|"$HOME/.claude/skills/sdlc/calibrate.sh") exit 0 ;; esac
    fi
    [ "$w1" = git ] || block "run commands, explore or run tests"
    case "$w2" in status|diff|log|blame|show) ;; *) block "run git $w2" ;; esac
    case " $rest " in *" --ext-diff"*|*" --output"*|*" --textconv"*) block "run git with external tools" ;; esac
    exit 0
    ;;
esac
exit 0

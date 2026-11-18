#!/bin/bash
# Scenarios: hooks/orchestrator-guard.sh blocks main-session edits and commands in
# Orchestrate mode, and nothing else.
#   usage: orchestrator-guard-test.sh <hooks-dir> <case>
#   cases: main-edit sub-edit sdlc-write git-read no-marker
set -uo pipefail
hooks="$1"; c="$2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
repo="$tmp/repo"; mkdir -p "$repo/.sdlc/demo" "$repo/src"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
# run <want-exit> <label> <payload-json>
run() {
  local out rc
  out=$(printf '%s' "$3" | bash "$hooks/orchestrator-guard.sh" 2>&1); rc=$?
  [ "$rc" = "$1" ] || fail "$2: exit $rc, expected $1 ($out)"
  if [ "$1" = 2 ]; then case "$out" in *integrator*) ;; *) fail "$2: message does not name the integrator" ;; esac; fi
}
p() { # p <tool> <input-json> [agent_id]
  jq -nc --arg t "$1" --argjson i "$2" --arg cwd "$repo" --arg a "${3:-}" \
    '{hook_event_name:"PreToolUse", session_id:"s1", cwd:$cwd, tool_name:$t, tool_input:$i}
     + (if $a == "" then {} else {agent_id:$a, agent_type:"integrator"} end)'
}
: > "$tmp/claudio-orch-s1"

case "$c" in
  main-edit)
    run 2 "Edit src" "$(p Edit "{\"file_path\":\"$repo/src/a.ts\"}")"
    run 2 "Write relative src" "$(p Write '{"file_path":"src/a.ts"}')"
    run 2 "NotebookEdit" "$(p NotebookEdit "{\"notebook_path\":\"$repo/n.ipynb\"}")"
    run 2 "Edit .sdlc escape with .." "$(p Edit "{\"file_path\":\"$repo/.sdlc/demo/../../src/a.ts\"}")"
    run 2 "Edit .sdlc root file" "$(p Edit "{\"file_path\":\"$repo/.sdlc/x.md\"}")"
    run 2 "Edit other repo .sdlc" "$(p Edit '{"file_path":"/elsewhere/.sdlc/demo/plan.md"}')"
    ;;
  sub-edit)
    run 0 "subagent Edit src" "$(p Edit "{\"file_path\":\"$repo/src/a.ts\"}" agent-1)"
    run 0 "subagent Bash tests" "$(p Bash '{"command":"cargo test"}' agent-1)"
    ;;
  sdlc-write)
    run 0 "Write plan" "$(p Write "{\"file_path\":\"$repo/.sdlc/demo/plan.md\"}")"
    run 0 "Write relative context" "$(p Edit '{"file_path":".sdlc/demo/context.md"}')"
    run 0 "Write decision" "$(p Write "{\"file_path\":\"$repo/.sdlc/demo/decisions/001-x.md\"}")"
    ;;
  git-read)
    run 0 "git log" "$(p Bash '{"command":"git log --oneline -5"}')"
    run 0 "git diff --stat" "$(p Bash '{"command":"git diff --stat"}')"
    run 0 "git status" "$(p Bash '{"command":"  git status --short"}')"
    run 2 "cargo test" "$(p Bash '{"command":"cargo test"}')"
    run 0 "calibrate estimates" "$(p Bash '{"command":"bash ~/.claude/skills/sdlc/calibrate.sh ."}')"
    run 2 "other script under ~/.claude" "$(p Bash '{"command":"bash ~/.claude/evals/run.sh"}')"
    run 2 "calibrate path traversal" "$(p Bash '{"command":"bash ~/.claude/skills/sdlc/../../x.sh"}')"
    run 2 "git log chained" "$(p Bash '{"command":"git log; npm test"}')"
    run 2 "git log piped" "$(p Bash '{"command":"git log | sh"}')"
    run 2 "git log subshell" "$(p Bash '{"command":"git log $(npm test)"}')"
    run 2 "git diff to file" "$(p Bash '{"command":"git diff > src/a.patch"}')"
    run 2 "git checkout" "$(p Bash '{"command":"git checkout main"}')"
    run 2 "git with -c" "$(p Bash '{"command":"git -c core.pager=sh log"}')"
    run 2 "git diff ext-diff" "$(p Bash '{"command":"git diff --ext-diff"}')"
    run 2 "newline" "$(p Bash '{"command":"git log\nnpm test"}')"
    ;;
  no-marker)
    rm -f "$tmp/claudio-orch-s1"
    run 0 "no marker Edit" "$(p Edit "{\"file_path\":\"$repo/src/a.ts\"}")"
    run 0 "no marker Bash" "$(p Bash '{"command":"cargo test"}')"
    : > "$tmp/claudio-orch-s1"
    run 0 "Read is not blocked" "$(p Read "{\"file_path\":\"$repo/src/a.ts\"}")"
    run 0 "bad session id" "$(jq -nc --arg cwd "$repo" '{session_id:"../x", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:"src/a.ts"}}')"
    ;;
esac
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

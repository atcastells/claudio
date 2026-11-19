#!/bin/bash
# Scenarios: hooks/orchestrator-guard.sh blocks main-session edits and commands in
# Orchestrate mode, and nothing else.
#   usage: orchestrator-guard-test.sh <hooks-dir> <case>
#   cases: main-edit sub-edit sdlc-write git-read no-marker cross-chain git-write shared-edit
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
p() { # p <tool> <input-json> [agent_id] [cwd]
  jq -nc --arg t "$1" --argjson i "$2" --arg cwd "${4:-$repo}" --arg a "${3:-}" \
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
  cross-chain)
    other="$tmp/other"; mkdir -p "$other/.sdlc/k1/work"; : > "$other/.sdlc/k1/plan.md"
    mkdir -p "$other/.sdlc/empty"
    run 0 "Write another repo's chain" "$(p Write "{\"file_path\":\"$other/.sdlc/k1/context.md\"}")"
    [ "$(head -n 1 "$tmp/claudio-orch-s1")" = "$(cd "$other/.sdlc/k1" && pwd -P)" ] || fail "active chain not recorded in the marker"
    run 2 "another repo's dir without chain files" "$(p Write "{\"file_path\":\"$other/.sdlc/empty/plan.md\"}")"
    run 2 "another repo's code" "$(p Edit "{\"file_path\":\"$other/src/a.rs\"}")"
    mkdir -p "$repo/.sdlc/demo/sub"
    run 0 "cwd inside .sdlc, own chain" "$(p Write "{\"file_path\":\"$repo/.sdlc/demo/plan.md\"}" "" "$repo/.sdlc/demo/sub")"
    mkdir -p "$repo/src/deep"
    run 0 "cwd in a subdirectory" "$(p Write "{\"file_path\":\"$repo/.sdlc/demo/context.md\"}" "" "$repo/src/deep")"
    run 2 "nested .sdlc in a chain" "$(p Write "{\"file_path\":\"$repo/.sdlc/demo/x/.sdlc/y/plan.md\"}")"
    ;;
  git-write)
    run 0 "git -C status" "$(p Bash '{"command":"git -C /elsewhere status --short"}')"
    run 0 "git -C log" "$(p Bash '{"command":"git -C ../repo-b log --oneline -3"}')"
    run 2 "git -C checkout" "$(p Bash '{"command":"git -C ../repo-b checkout main"}')"
    run 0 "git add" "$(p Bash '{"command":"git add src/a.ts"}')"
    o=$(p Bash '{"command":"git -C /elsewhere commit -F m.txt"}' | bash "$hooks/orchestrator-guard.sh" 2>/dev/null)
    [ "$(printf '%s' "$o" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)" = ask ] || fail "git -C commit does not ask the developer: $o"
    run 0 "git commit -F" "$(p Bash '{"command":"git commit -F .sdlc/demo/work/commit.txt"}')"
    run 0 "git -C push" "$(p Bash '{"command":"git -C /elsewhere push -u origin feat/x"}')"
    run 2 "git commit --no-verify" "$(p Bash '{"command":"git commit --no-verify -F m.txt"}')"
    run 2 "git push --force" "$(p Bash '{"command":"git push --force"}')"
    run 2 "git commit message with substitution" "$(p Bash '{"command":"git commit -m \"x $(id)\""}')"
    run 2 "agent git commit" "$(p Bash '{"command":"git commit -F m.txt"}' agent-1)"
    run 2 "agent git -C add" "$(p Bash '{"command":"git -C /x add ."}' agent-1)"
    run 0 "agent git status" "$(p Bash '{"command":"git status"}' agent-1)"
    run 0 "clean script" "$(p Bash '{"command":"bash ~/.claude/skills/orchestrate/clean.sh .sdlc/demo/work/T1-x.md"}')"
    ;;
  shared-edit)
    : > "$repo/.sdlc/demo/plan.md"
    printf '%s\n' "$(cd "$repo/.sdlc/demo" && pwd -P)" > "$tmp/claudio-orch-s1"
    o1=$(p Edit "{\"file_path\":\"$repo/src/mod.rs\"}" agent-1 | bash "$hooks/orchestrator-guard.sh" 2>&1)
    [ -z "$o1" ] || fail "first agent warned: $o1"
    o2=$(p Edit "{\"file_path\":\"$repo/src/mod.rs\"}" agent-1 | bash "$hooks/orchestrator-guard.sh" 2>&1)
    [ -z "$o2" ] || fail "same agent warned: $o2"
    o3=$(p Edit "{\"file_path\":\"$repo/src/mod.rs\"}" agent-2 | bash "$hooks/orchestrator-guard.sh" 2>&1); rc=$?
    [ "$rc" = 0 ] || fail "second agent blocked (exit $rc)"
    case "$o3" in *additionalContext*"Read the file again"*) ;; *) fail "second agent not warned: $o3" ;; esac
    o4=$(p Edit "{\"file_path\":\"$repo/src/other.rs\"}" agent-2 | bash "$hooks/orchestrator-guard.sh" 2>&1)
    [ -z "$o4" ] || fail "unshared file warned: $o4"
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

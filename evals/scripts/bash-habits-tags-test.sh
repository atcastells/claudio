#!/bin/bash
# Scenarios: hooks/bash-habits.sh reminds once per agent to use the tags index
# (or LSP) when it greps an identifier in a repo that has ./tags.
#   usage: bash-habits-tags-test.sh <path-to-hook>
set -uo pipefail
hook="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
repo="$tmp/repo"; mkdir -p "$repo/src"; git -C "$repo" init -q
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }
run() { # run <agent_id> <command> [cwd]
  jq -n --arg a "$1" --arg c "$2" --arg cwd "${3:-$repo}" \
    '{hook_event_name:"PostToolUse", tool_name:"Bash", session_id:"s1", agent_id:$a, cwd:$cwd, tool_input:{command:$c}}' | bash "$hook"
}
hint() { printf '%s' "$1" | grep -q 'tags index'; }

o=$(run a1 'grep -rn "fn station_layout" crates'); hint "$o" && fail a "hint without a tags file: $o"
printf 'station_layout\tcrates/a.rs\t/^fn station_layout/\n' > "$repo/tags"
rm -f "$tmp"/claudio-tags-hint-*
o=$(run a1 'grep -rn "fn station_layout" crates'); hint "$o" || fail b "fn grep not flagged"
o=$(run a1 'rg -n "AccessDress" godot'); hint "$o" && fail c "second hint to the same agent"
o=$(run a2 "cd $repo; rg -n 'AccessDress' godot" /); hint "$o" || fail d "cd form for a new agent not flagged"
o=$(run a3 "rg -n 'hatch|door|lamp' godot"); hint "$o" && fail e "free-text grep flagged: $o"
o=$(run a4 "rg '^station_layout\t' tags"); hint "$o" && fail f "lookup in tags flagged: $o"
o=$(run a5 'git log --oneline | grep station_layout'); hint "$o" && fail g "grep on a pipe flagged: $o"
o=$(run a6 'grep -n "ind_marking_band" kiln/materials.toml'); hint "$o" && fail h "config grep flagged: $o"
o=$(run a7 'grep -rn "access_dress" godot/station'); hint "$o" || fail h2 "snake_case identifier not flagged"
printf '%s' "$o" | jq -e '.hookSpecificOutput.hookEventName=="PostToolUse"' >/dev/null || fail i "output is not hook JSON"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }

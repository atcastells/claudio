#!/bin/bash
# Scenarios for hooks/bash-habits.sh. Exit 0 = every scenario behaved.
#   usage: bash-habits-test.sh <path-to-hook>
set -uo pipefail
hook="$1"
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }
# run <event> <tool> <command> -> stdout of the hook
run() {
  jq -n --arg e "$1" --arg t "$2" --arg c "$3" '{hook_event_name:$e, tool_name:$t, tool_input:{command:$c}}' | bash "$hook"
}
has_test() { printf '%s' "$1" | grep -q 'Test output went to no file'; }
has_edit() { printf '%s' "$1" | grep -q 'A script rewrote a file'; }

o=$(run PostToolUse Bash 'cargo test -p astra_sim offer'); has_test "$o" || fail a "bare cargo test not flagged"
o=$(run PostToolUse Bash 'cargo test -p x 2>&1 | tee .sdlc/s/review/t.log | tail -40'); [ -z "$o" ] || fail b "tee flagged: $o"
o=$(run PostToolUse Bash 'cargo test --workspace > /tmp/t.log 2>&1'); [ -z "$o" ] || fail c "redirect to file flagged: $o"
o=$(run PostToolUse Bash 'cargo test -q 2>&1 | tail -20'); has_test "$o" || fail d "tail only not flagged"
o=$(run PostToolUse Bash 'cargo test -q >/dev/null 2>&1'); has_test "$o" || fail e "/dev/null counted as a file"
o=$(run PostToolUse Bash 'cargo test --no-run'); [ -z "$o" ] || fail f "--no-run flagged"
o=$(run PostToolUse Bash 'npm test 2>&1 | tail -5'); has_test "$o" || fail g "npm test not flagged"
o=$(run PostToolUse Bash 'git status --short'); [ -z "$o" ] || fail h "git flagged: $o"
o=$(run PreToolUse Bash 'cargo test'); [ -z "$o" ] || fail i "PreToolUse not ignored"
o=$(run PostToolUse Read 'cargo test'); [ -z "$o" ] || fail j "other tool not ignored"
py=$'python3 - <<\'EOF\'\np=\'src/a.rs\'; s=open(p).read()\nopen(p,\'w\').write(s.replace(\'a\',\'b\'))\nEOF'
o=$(run PostToolUse Bash "$py"); has_edit "$o" || fail k "python rewrite not flagged"
pyt=$'S=$(mktemp -d); python3 - <<\'EOF\'\nopen(\'/tmp/x\',\'w\').write(\'1\')\nEOF'
o=$(run PostToolUse Bash "$pyt"); [ -z "$o" ] || fail l "temp-file script flagged: $o"
o=$(run PostToolUse Bash "perl -pi -e 's/a/b/' src/lib.rs"); has_edit "$o" || fail m "perl -pi not flagged"
o=$(run PostToolUse Bash "python3 - <<'EOF'
import json; print(json.load(open('a.json')))
EOF"); [ -z "$o" ] || fail n "read-only script flagged: $o"
o=$(run PostToolUse Bash 'cargo test -p x'); printf '%s' "$o" | jq -e '.hookSpecificOutput.hookEventName=="PostToolUse"' >/dev/null || fail o "output is not hook JSON"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }

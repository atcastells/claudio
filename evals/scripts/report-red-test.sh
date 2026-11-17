#!/bin/bash
# Scenarios for the implementer Red/Mutation evidence line and the TASK id hint
# of hooks/subagent-report-check.sh. Exit 0 = every scenario behaved.
#   usage: report-red-test.sh <path-to-hook>
set -uo pipefail
hook="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }

n=0
# run <message> -> exit code of the hook (stderr in $tmp/err); fresh agent_id each time
run() {
  n=$((n+1))
  jq -n --arg m "$1" --arg id "ag$n" \
    '{hook_event_name:"PreToolUse", tool_name:"SubagentHandback", agent_type:"implementer", agent_id:$id, tool_input:{message:$m}}' \
    | bash "$hook" >"$tmp/out" 2>"$tmp/err"
}

head=$'TASK: demo/T1\nRESULT: done\n'
tail=$'\nDeviation cause: none'
arrow='→'

run "${head}Red: bash t.sh $arrow 1 failed: expected 2, got 0$tail"; rc=$?
[ "$rc" -eq 0 ] || fail a "Red with output: expected 0, got $rc"

run "${head}Mutation: removed the guard $arrow test x failed$tail"; rc=$?
[ "$rc" -eq 0 ] || fail b "Mutation with output: expected 0, got $rc"

run "${head}Test: bash t.sh $arrow green$tail"; rc=$?
[ "$rc" -eq 2 ] || fail c "no Red line: expected 2, got $rc"
grep -q "Red: <command>" "$tmp/err" || fail c "stderr lacks the Red message"

run "${head}Red: x $arrow not seen$tail"; rc=$?
[ "$rc" -eq 2 ] || fail d "not seen: expected 2, got $rc"

run "${head}Red: x $arrow none$tail"; rc=$?
[ "$rc" -eq 2 ] || fail e "none: expected 2, got $rc"

run "${head}Red: x $arrow N/A$tail"; rc=$?
[ "$rc" -eq 2 ] || fail e2 "N/A: expected 2, got $rc"

run "${head}Red: x $arrow   $tail"; rc=$?
[ "$rc" -eq 2 ] || fail e3 "blank after arrow: expected 2, got $rc"

run "${head}Red: x without arrow$tail"; rc=$?
[ "$rc" -eq 2 ] || fail e4 "no arrow: expected 2, got $rc"

run $'TASK: d/A1\nRESULT: done\nRed: x → failed\nDeviation cause: none'; rc=$?
[ "$rc" -eq 2 ] || fail f "TASK d/A1: expected 2, got $rc"
grep -q 'T<n>' "$tmp/err" || fail f "stderr lacks the T<n> hint"
grep -q 'Task cell' "$tmp/err" || fail f "stderr lacks the Task cell hint"

run $'TASK: demo/T3b\nRESULT: done\nRed: x → failed\nDeviation cause: none'; rc=$?
[ "$rc" -eq 0 ] || fail g "T3b: expected 0, got $rc"

n=$((n+1))
jq -n --arg m "${head}Red: bash t.sh $arrow 1 failed$tail" --arg id "ag$n" \
  '{hook_event_name:"PreToolUse", tool_name:"SubagentHandback", agent_type:"implementer", agent_id:$id, tool_input:{message:$m}}' \
  | LC_ALL=C bash "$hook" >"$tmp/out" 2>"$tmp/err"; rc=$?
[ "$rc" -eq 0 ] || fail h "LC_ALL=C with output: expected 0, got $rc"

n=$((n+1))
jq -n --arg m "${head}Red: x $arrow not seen$tail" --arg id "ag$n" \
  '{hook_event_name:"PreToolUse", tool_name:"SubagentHandback", agent_type:"implementer", agent_id:$id, tool_input:{message:$m}}' \
  | LC_ALL=C bash "$hook" >"$tmp/out" 2>"$tmp/err"; rc=$?
[ "$rc" -eq 2 ] || fail i "LC_ALL=C not seen: expected 2, got $rc"

# Text after the arrow that opens with an admission is not red
for t in 'not seen (test already passed)' 'none.' 'N/A, passed before' 'no failing output was seen' 'passed' 'None seen' 'green before the change'; do
  run "${head}Red: t.sh $arrow $t$tail"; rc=$?
  [ "$rc" -eq 2 ] || fail l "Red: → '$t': expected 2, got $rc"
done
# ...but real failing output that mentions those words is
for t in '1 failed, 3 passed' 'NoneType has no attribute x' 'nothing returned: expected 3'; do
  run "${head}Red: t.sh $arrow $t$tail"; rc=$?
  [ "$rc" -eq 0 ] || fail m "Red: → '$t': expected 0, got $rc"
done

# Punctuation after the id is not a phase
run $'TASK: demo/T3:\nRESULT: done\nRed: bash t.sh '"$arrow"$' 1 failed\nDeviation cause: none'; rc=$?
[ "$rc" -eq 0 ] || fail n "TASK: demo/T3: expected 0, got $rc"

# A phase glued to the id is not a T<n> id
run $'TASK: demo/T3-red\nRESULT: done\nRed: bash t.sh '"$arrow"$' 1 failed\nDeviation cause: none'; rc=$?
[ "$rc" -eq 2 ] || fail k "TASK: demo/T3-red: expected 2, got $rc"

# A blocked task may stop before any test exists: no Red line required
run $'TASK: demo/T1\nRESULT: blocked\nBlocked on: which schema to use\nDeviation cause: none'; rc=$?
[ "$rc" -eq 0 ] || fail j "blocked without Red: expected 0, got $rc"

[ "$fails" -eq 0 ] && echo "report red scenarios: all passed" || echo "report red scenarios: $fails failed"
[ "$fails" -eq 0 ]

#!/bin/bash
# Checks EVALS_ONLY in run.sh and the affected-cases selection of
# evals-on-config-change.sh.
#   usage: evals-only-test.sh <path to run.sh>
set -uo pipefail
runsh="$(cd "$(dirname "${1:?run.sh path}")" && pwd)/$(basename "$1")"
hook="$(cd "$(dirname "$runsh")/.." && pwd)/hooks/evals-on-config-change.sh"
tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { [ "$2" = "$3" ] || { echo "FAIL: $1: got '$2', expected '$3'"; fail=1; }; }

src="$tmp/src"
mkdir -p "$src/evals/cases" "$src/hooks" "$tmp/home"
cp "$runsh" "$src/evals/run.sh"
printf 'hello\n' > "$src/hooks/foo.sh"
printf 'hello\n' > "$src/hooks/bar.sh"
printf '1.0.0\n' > "$src/VERSION"
jq -n --arg f "{root}/hooks/foo.sh" '{name:"foo file",kind:"file_contains",file:$f,contains:"hello"}' > "$src/evals/cases/a.json"
jq -n '{name:"foo hook",kind:"file_contains",hook:"foo.sh",file:"{root}/VERSION",contains:"1"}' > "$src/evals/cases/b.json"
jq -n --arg f "{root}/hooks/bar.sh" '{name:"bar file",kind:"file_contains",file:$f,contains:"hello"}' > "$src/evals/cases/c.json"
printf '%s\n' "$src" > "$tmp/home/source"

counts() { printf '%s\n' "$1" | sed -n 's/^PASS: \([0-9]*\)   FAIL: \([0-9]*\).*/\1\/\2/p'; }
run() { env -u WORKFLOW_PROFILE -u EVALS_RESULT_JSON -u EVALS_REPO -u EVALS_ONLY "$@" bash "$src/evals/run.sh" 2>&1; }

ok "no filter" "$(counts "$(run)")" "3/0"
ok "only a c" "$(counts "$(run EVALS_ONLY='a c')")" "2/0"
ok "only unknown" "$(counts "$(run EVALS_ONLY='zzz')")" "0/0"

# The hook is silent on green, so selection shows through a case that fails
# only when it is selected: c names bar.sh and now fails.
jq -n --arg f "{root}/hooks/bar.sh" '{name:"bar file",kind:"file_contains",file:$f,contains:"nope"}' > "$src/evals/cases/c.json"
hookrun() { jq -n --arg p "$1" '{tool_input:{file_path:$p}}' | env -u CLAUDE_EVALS_RUNNING -u EVALS_ONLY -u WORKFLOW_PROFILE WORKFLOW_HOME="$tmp/home" bash "$hook" 2>&1; }
out=$(hookrun "$src/hooks/foo.sh"); rc=$?
ok "foo.sh edit runs a b only" "$rc" "0"
out=$(hookrun "$src/hooks/bar.sh"); rc=$?
ok "bar.sh edit runs c only" "$rc/$(printf '%s\n' "$out" | grep -c '^PASS: 0   FAIL: 1')" "2/1"
out=$(hookrun "$src/VERSION"); rc=$?
ok "VERSION edit runs all" "$rc/$(printf '%s\n' "$out" | grep -c '^PASS: 2   FAIL: 1')" "2/1"

[ "$fail" -eq 0 ] && echo "all passed"
exit "$fail"

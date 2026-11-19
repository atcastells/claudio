#!/bin/bash
# Scenarios: subagent-report-check on integrator reports (Orchestrate mode artifacts).
#   usage: report-integrator-test.sh <hooks-dir> <case>
#   cases: no-artifact missing-file missing-field good findings-missing findings-present summary
set -uo pipefail
hooks="$1"; c="$2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
repo="$tmp/repo"; mkdir -p "$repo/.sdlc/demo/work"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
art() { # art <file> <omit-field>
  { echo ---
    for k in task from kind result data cost regen persist files evidence; do
      [ "$k" = "${2:-}" ] && continue
      case $k in task) echo "task: demo/T1" ;; data) echo "data: decision" ;; result) echo "result: done" ;; *) echo "$k: x" ;; esac
    done
    echo ---; echo "## Summary"; echo "ok"; } > "$1"
}
stop() { # stop <message> -> exit code
  jq -n --arg m "$1" --arg cwd "$repo" \
    '{hook_event_name:"SubagentStop", agent_type:"integrator", agent_id:"ag1", cwd:$cwd, last_assistant_message:$m}' \
    | bash "$hooks/subagent-report-check.sh" >/dev/null 2>"$tmp/err"
}
case "$c" in
  no-artifact)
    stop $'task: demo/T1\nresult: done\nAll good.'; rc=$?
    [ "$rc" = 2 ] || fail "no ARTIFACT line: exit $rc"
    grep -q 'ARTIFACT:' "$tmp/err" || fail "message does not ask for ARTIFACT:"
    ;;
  missing-file)
    stop 'ARTIFACT: .sdlc/demo/work/T1-result.md'; rc=$?
    [ "$rc" = 2 ] || fail "missing file: exit $rc"
    grep -q 'does not exist' "$tmp/err" || fail "message does not say the file is missing"
    stop 'ARTIFACT: .sdlc/demo/../../etc/T1.md'; rc=$?
    [ "$rc" = 2 ] || fail "path outside work/: exit $rc"
    ;;
  missing-field)
    art "$repo/.sdlc/demo/work/T1-result.md" data
    stop 'ARTIFACT: .sdlc/demo/work/T1-result.md'; rc=$?
    [ "$rc" = 2 ] || fail "missing data field: exit $rc"
    grep -q "data" "$tmp/err" || fail "message does not name the field"
    ;;
  good)
    art "$repo/.sdlc/demo/work/T1-result.md"
    stop $'ARTIFACT: .sdlc/demo/work/T1-result.md\ntask: demo/T1'; rc=$?
    [ "$rc" = 0 ] || fail "good artifact: exit $rc ($(cat "$tmp/err"))"
    ;;
  findings-missing)
    art "$repo/.sdlc/demo/work/T8-result.md"; echo "Findings: .sdlc/demo/review/findings.md" >> "$repo/.sdlc/demo/work/T8-result.md"
    stop 'ARTIFACT: .sdlc/demo/work/T8-result.md'; rc=$?
    [ "$rc" = 2 ] || fail "cited findings.md missing: exit $rc"
    grep -q 'findings.md' "$tmp/err" || fail "message does not name findings.md"
    ;;
  findings-present)
    art "$repo/.sdlc/demo/work/T8-result.md"; echo "Findings: .sdlc/demo/review/findings.md" >> "$repo/.sdlc/demo/work/T8-result.md"
    mkdir -p "$repo/.sdlc/demo/review"; echo "# Findings" > "$repo/.sdlc/demo/review/findings.md"
    stop 'ARTIFACT: .sdlc/demo/work/T8-result.md'; rc=$?
    [ "$rc" = 0 ] || fail "findings.md present: exit $rc ($(cat "$tmp/err"))"
    ;;
  summary)
    a="$repo/.sdlc/demo/work/T2-result.md"
    art "$a"; sed -i.bak '/^## Summary/,$d' "$a"; echo "## Detail" >> "$a"; echo "x" >> "$a"
    stop 'ARTIFACT: .sdlc/demo/work/T2-result.md'; rc=$?
    [ "$rc" = 2 ] || fail "no summary: exit $rc"
    grep -q 'Summary' "$tmp/err" || fail "message does not name the summary"
    art "$a"; for i in $(seq 1 16); do echo "line $i" >> "$a"; done
    stop 'ARTIFACT: .sdlc/demo/work/T2-result.md'; rc=$?
    [ "$rc" = 2 ] || fail "17-line summary: exit $rc"
    grep -q '15' "$tmp/err" || fail "message does not give the limit"
    art "$a"; for i in $(seq 1 12); do echo "line $i" >> "$a"; done; printf '\n## Detail\n' >> "$a"; for i in $(seq 1 40); do echo "d $i" >> "$a"; done
    stop 'ARTIFACT: .sdlc/demo/work/T2-result.md'; rc=$?
    [ "$rc" = 0 ] || fail "13-line summary and long detail: exit $rc ($(cat "$tmp/err"))"
    ;;
esac
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

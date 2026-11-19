#!/bin/bash
# Scenario: plan-resume, on resume in Orchestrate mode, reads the active chain
# (another repo) and lists the delegated tasks with no artifact back.
#   usage: orchestrate-resume-test.sh <hooks-dir>
set -uo pipefail
hooks="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
chain="$tmp/repo-b/.sdlc/k1"; mkdir -p "$chain/work" "$tmp/repo-a"
cat > "$chain/plan.md" <<'P'
## Tasks
| # | Task | Runs on | Status |
|---|------|---------|--------|
| T1 | a | integrator | done |
| T2 | b | integrator | in progress |
| T3 | c | integrator | in progress |
| T4 | d | integrator | pending |
P
: > "$chain/work/T2-result.md"; : > "$chain/work/T4-brief.md"
pchain=$(cd "$chain" && pwd -P)
printf '%s\n' "$pchain" > "$tmp/claudio-orch-s1"
out=$(jq -nc --arg c "$tmp/repo-a" '{hook_event_name:"SessionStart", source:"resume", session_id:"s1", cwd:$c}' | bash "$hooks/plan-resume.sh" 2>/dev/null)
case "$out" in *"session was resumed"*) ;; *) fail "no resume notice: $out" ;; esac
case "$out" in *"no artifact back"*"T3"*) ;; *) fail "T3 (in progress, no artifact) not listed: $out" ;; esac
case "$out" in *"T4 (brief: "*) ;; *) fail "T4 (brief, no artifact) not listed with its brief" ;; esac
case "$out" in *"back (the agent stopped): T2"*|*", T2"*) fail "T2 has its result and was listed" ;; esac
case "$out" in *"T2 (in progress)"*) ;; *) fail "open rows of the active chain not listed" ;; esac
rm -f "$tmp/claudio-orch-s1"
out=$(jq -nc --arg c "$tmp/repo-a" '{hook_event_name:"SessionStart", source:"resume", session_id:"s1", cwd:$c}' | bash "$hooks/plan-resume.sh" 2>/dev/null)
[ -z "$out" ] || fail "outside the mode it read another repo: $out"
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

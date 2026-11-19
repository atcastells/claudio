#!/bin/bash
# Scenarios: hooks/task-actuals.sh keeps the plan row's Status in Orchestrate
# mode: "in progress" when the main session launches the row, the artifact's
# result at the integrator's SubagentStop. Main rows and nested tags untouched.
#   usage: plan-status-test.sh <hooks-dir>
set -uo pipefail
hooks="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" CLAUDE_SDLC_ACTUALS="$tmp/machine.jsonl"
repo="$tmp/repo"; c="$repo/.sdlc/demo"; mkdir -p "$c/work"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
plan() { # plan <status line>
  cat > "$c/plan.md" <<P
# Plan: demo

- **Status**: $1

| # | Task | Files | Runs on | Est | Status |
|---|------|-------|---------|-----|--------|
| T1 | first, joined by ; && \| | a.rs | claude | 5m/500k | pending |
| T2 | second | b.rs | claude | 5m/500k | done (cause: none) |
| T3 | main's own | plan.md | main | 1m/50k | pending |
| T10 | tenth | c.rs | claude | 5m/500k | pending |
P
}
row() { grep -E "^\| $1 \|" "$c/plan.md" | awk -F'|' '{gsub(/^ +| +$/, "", $(NF-1)); print $(NF-1)}'; }
launch() { # launch <prompt> [agent_id]
  jq -nc --arg p "$1" --arg cwd "$repo" --arg a "${2:-}" \
    '{hook_event_name:"PreToolUse", session_id:"s1", cwd:$cwd, tool_name:"Agent", tool_input:{subagent_type:"integrator", prompt:$p}}
     + (if $a == "" then {} else {agent_id:$a} end)' | bash "$hooks/task-actuals.sh" >/dev/null 2>&1
}
stopas() { # stopas <agent> <task> <report>
  local t="$tmp/tr-$2.jsonl"
  printf '%s\n' "{\"type\":\"user\",\"timestamp\":\"2026-11-19T10:00:00Z\",\"message\":{\"content\":\"[sdlc:demo/$2 est=5m/500k] do it\"}}" \
    "{\"type\":\"assistant\",\"timestamp\":\"2026-11-19T10:03:00Z\",\"message\":{\"id\":\"m1\",\"model\":\"claude-sonnet-5-5\",\"usage\":{\"input_tokens\":1000}}}" > "$t"
  jq -nc --arg cwd "$repo" --arg t "$t" --arg m "$3" --arg a "$1" \
    '{hook_event_name:"SubagentStop", session_id:"s1", cwd:$cwd, agent_type:$a, agent_id:("id-" + $a),
      agent_transcript_path:$t, last_assistant_message:$m}' | bash "$hooks/task-actuals.sh" >/dev/null 2>&1
}
stop() { # stop <task> <result>
  local t="$tmp/tr-$1.jsonl"
  printf '%s\n' "{\"type\":\"user\",\"timestamp\":\"2026-11-19T10:00:00Z\",\"message\":{\"content\":\"[sdlc:demo/$1 est=5m/500k] do it\"}}" \
    "{\"type\":\"assistant\",\"timestamp\":\"2026-11-19T10:03:00Z\",\"message\":{\"id\":\"m1\",\"model\":\"claude-opus-5-5\",\"usage\":{\"input_tokens\":1000}}}" > "$t"
  printf '%s\n' '---' "task: demo/$1" "result: $2" '---' '## Summary' 'ok' > "$c/work/$1.md"
  jq -nc --arg cwd "$repo" --arg t "$t" --arg m "ARTIFACT: .sdlc/demo/work/$1.md" \
    '{hook_event_name:"SubagentStop", session_id:"s1", cwd:$cwd, agent_type:"integrator", agent_id:"ag1",
      agent_transcript_path:$t, last_assistant_message:$m}' | bash "$hooks/task-actuals.sh" >/dev/null 2>&1
}
: > "$tmp/claudio-orch-s1"

plan "draft"
launch '[sdlc:demo/T1 est=5m/500k] go'
[ "$(row T1)" = pending ] || fail "draft plan: T1 became '$(row T1)'"

plan "APPROVED BY ENGINEER"
launch '[sdlc:demo/T1 est=5m/500k] go'
[ "$(row T1)" = "in progress" ] || fail "launch: T1 is '$(row T1)'"
grep -qF 'joined by ; && \|' "$c/plan.md" || fail "escaped pipe in a cell lost"
[ "$(row T10)" = pending ] || fail "T10 touched by T1"
launch '[sdlc:demo/T2 est=5m/500k] again'
[ "$(row T2)" = "done (cause: none)" ] || fail "done row reset to '$(row T2)'"
launch '[sdlc:demo/T3 est=5m/500k] main'
[ "$(row T3)" = pending ] || fail "main row changed to '$(row T3)'"
launch '[sdlc:demo/T10a est=1m/100k] nested' agent-1
[ "$(row T10)" = pending ] || fail "nested launch changed T10"

stop T1 done
[ "$(row T1)" = done ] || fail "stop done: T1 is '$(row T1)'"
launch '[sdlc:demo/T10 est=5m/500k] go'; stop T10 blocked
[ "$(row T10)" = blocked ] || fail "stop blocked: T10 is '$(row T10)'"
stop T10 needs-decision
[ "$(row T10)" = needs-decision ] || fail "needs-decision: T10 is '$(row T10)'"
[ "$(sed -n 1p "$c/plan.md")" = "# Plan: demo" ] || fail "plan header changed"

plan "APPROVED BY ENGINEER"
cat >> "$c/plan.md" <<P
| T13 | verify | — | verifier | 5m/500k | in progress |
| T14 | review | — | reviewer | 5m/500k | in progress |
| T15 | review | — | reviewer | 5m/500k | in progress |
P
stopas reviewer T14 $'## Findings\n[IMPORTANT] x demonstration: y'
[ "$(row T14)" = done ] || fail "reviewer without RESULT: T14 is '$(row T14)'"
stopas verifier T13 $'Verdict\nRESULT: blocked'
[ "$(row T13)" = blocked ] || fail "verifier blocked: T13 is '$(row T13)'"
stopas reviewer T15a $'RESULT: done'
[ "$(row T15)" = "in progress" ] || fail "nested T15a closed T15"

rm -f "$tmp/claudio-orch-s1"; plan "APPROVED"
launch '[sdlc:demo/T1 est=5m/500k] go'
[ "$(row T1)" = pending ] || fail "outside Orchestrate mode T1 became '$(row T1)'"

if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

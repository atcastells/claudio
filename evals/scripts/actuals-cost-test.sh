#!/bin/bash
# Scenarios: task-actuals writes the measured cost into an integrator's artifact,
# adding the nested agents it launched (tasks T<n>a, T<n>b...).
#   usage: actuals-cost-test.sh <hooks-dir> written|nested
set -uo pipefail
hooks="$1"; c="$2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" HOME="$tmp/home" CLAUDE_SDLC_ACTUALS="$tmp/machine.jsonl"
repo="$tmp/repo"; mkdir -p "$repo/.sdlc/demo/work" "$HOME"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
art="$repo/.sdlc/demo/work/T1-result.md"
printf -- '---\ntask: demo/T1\nkind: result\nresult: done\ndata: decision\ncost:\nregen: not-reproducible\nevidence: [a:1]\n---\n## Summary\nok\n' > "$art"
tr="$tmp/integrator.jsonl"
jq -nc '{type:"user", timestamp:"2026-11-18T10:00:00.000Z", message:{content:"[sdlc:demo/T1 est=10m/500k] do it"}}' > "$tr"
jq -nc '{type:"assistant", timestamp:"2026-11-18T10:10:00.000Z", message:{id:"m1", model:"claude-opus-5-5", usage:{input_tokens:100000, cache_read_input_tokens:100000, output_tokens:0}}}' >> "$tr"
if [ "$c" = nested ]; then
  printf '%s\n' '{"task":"T1a","runs_on":"implementer","ktok":300,"usd_min":0.5,"min":3,"agent_id":"n1"}' \
    '{"task":"T1b","runs_on":"scout","ktok":50,"usd_min":0.01,"min":1,"agent_id":"n2"}' \
    '{"task":"T2","runs_on":"integrator","ktok":999,"usd_min":9,"min":9,"agent_id":"x"}' > "$repo/.sdlc/demo/actuals.jsonl"
fi
jq -nc --arg cwd "$repo" --arg t "$tr" '{hook_event_name:"SubagentStop", agent_type:"integrator", agent_id:"ag1", cwd:$cwd,
  agent_transcript_path:$t, last_assistant_message:"ARTIFACT: .sdlc/demo/work/T1-result.md\ntask: demo/T1"}' \
  | bash "$hooks/task-actuals.sh"
line=$(awk 'NR>1 && /^---$/ {exit} /^cost:/ {print}' "$art")
case "$c" in
  written)
    # own usage: 100k input at $4/M + 100k cache read at $0.20/M = $0.42
    case "$line" in "cost: {tokens_k: 200, usd_min: 0.42, minutes: 10, agents: 1}") ;; *) fail "cost line: '$line'" ;; esac
    grep -q '^## Summary' "$art" || fail "body lost"
    # stamping again rewrites, never appends
    jq -nc --arg cwd "$repo" --arg t "$tr" '{hook_event_name:"SubagentStop", agent_type:"integrator", agent_id:"ag1", cwd:$cwd,
      agent_transcript_path:$t, last_assistant_message:"ARTIFACT: .sdlc/demo/work/T1-result.md"}' | bash "$hooks/task-actuals.sh"
    [ "$(grep -c '^cost:' "$art")" = 1 ] || fail "cost stamped twice"
    ;;
  nested)
    case "$line" in "cost: {tokens_k: 550, usd_min: 0.93, minutes: 10, agents: 3}") ;; *) fail "nested cost line: '$line'" ;; esac
    ;;
esac
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

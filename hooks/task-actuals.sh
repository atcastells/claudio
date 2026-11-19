#!/bin/bash
# task-actuals: records the real minutes and tokens of a delegated plan task so
# calibrate.sh can compare them with the estimate. Playbook rule: actuals
# calibrate estimates, not people.
# One script, branches on hook_event_name:
#   SubagentStop: reads the subagent transcript, finds the tag
#     [sdlc:<slug>/<task> est=<min>m/<ktok>k] in the prompt and appends one JSON
#     line to .sdlc/<slug>/actuals.jsonl (only if that directory already exists).
#     The directory is the one of the repo holding cwd, else the session's active
#     chain (lib/chain.sh) when its name is <slug>: in Orchestrate mode the chain
#     may live in another repo. The machine-level log gets the line either way.
#   PostToolUse: after an Edit/Write of .sdlc/<slug>/plan.md (or a Bash command
#     that names it, e.g. a python3 or sed edit of its Status), measures the rows
#     whose "Runs on" is main: "in progress" appends a start line, "done" appends
#     the closing line (same schema) with minutes and tokens from the main
#     transcript between both timestamps. Other runners are ignored.
#   PreToolUse (Agent|Task, Orchestrate mode, main session): a plan row
#     [sdlc:<slug>/T<n> ...] launched with an approved plan gets Status
#     "in progress"; at SubagentStop the row gets the integrator artifact's
#     result (done, blocked, needs-decision), or another agent's RESULT line. Only rows not run by
#     main and with no letter (nested T5a are not plan rows).
# Output tokens are not recorded: transcripts store usage at stream start.
# Never blocks and never prints: any missing or bad input exits 0 silently.

. "$(dirname "$0")/lib/report.sh"
. "$(dirname "$0")/lib/leak-patterns.sh"
. "$(dirname "$0")/lib/mode.sh"
. "$(dirname "$0")/lib/chain.sh"

payload=$(cat)
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)

# append_log <log> <lines> <agent_id>: appends under a mkdir lock. When the
# agent_id is already in the log, rewrites it first without that agent's lines
# (a report sent back stops the same subagent again). Silent; gives up after
# ~5 s without removing a lock that is not ours.
append_log() {
  local log="$1" lines="$2" aid="$3" lock="$1.lock" n=0 tmp
  while ! mkdir "$lock" 2>/dev/null; do
    # A lock older than a minute was left by a killed hook (timeout is 10 s)
    [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null && continue
    n=$((n+1)); [ "$n" -ge 50 ] && return 0
    sleep 0.1
  done
  if [ -n "$aid" ] && [ -f "$log" ] && grep -qF -- "$aid" "$log" 2>/dev/null; then
    tmp=$(mktemp "$log.XXXXXX" 2>/dev/null)
    if [ -n "$tmp" ]; then
      if jq -R -r --arg id "$aid" '(try fromjson catch null) as $o
          | if ($o | type) == "object" and $o.agent_id == $id then empty else . end' \
          "$log" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$log" 2>/dev/null || rm -f "$tmp"
      else
        rm -f "$tmp"
      fi
    fi
  fi
  printf '%s\n' "$lines" >> "$log" 2>/dev/null
  rmdir "$lock" 2>/dev/null
  return 0
}

# machine_append <lines> <cwd> <agent_id>: the closing lines (not "start") plus
# "repo", in the machine-level log
machine_append() {
  local lines="$1" cwd="$2" aid="$3" mlog mdir mine
  mlog="${CLAUDE_SDLC_ACTUALS:-$HOME/.claude/actuals.jsonl}"
  mdir=$(dirname "$mlog")
  if [ ! -d "$mdir" ]; then
    [ "$mdir" = "$HOME/.claude" ] && return 0
    mkdir -p "$mdir" 2>/dev/null || return 0
  fi
  mine=$(printf '%s\n' "$lines" | jq -c --arg repo "$(basename "$cwd")" \
    'select(.event != "start") | . + {repo: $repo}' 2>/dev/null)
  [ -n "$mine" ] || return 0
  append_log "$mlog" "$mine" "$aid"
  return 0
}

# set_status <plan.md> <task> <status>: rewrites the Status cell of the task's
# row in the plan table. Leaves main rows, a row already in that status, and a
# done row asked for "in progress" alone. Silent.
set_status() {
  local plan="$1" task="$2" st="$3" tmp
  [ -f "$plan" ] && [ ! -L "$plan" ] || return 0
  tmp=$(mktemp "$plan.XXXXXX" 2>/dev/null) || return 0
  if awk -v t="$task" -v s="$st" '
      function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
      function unesc(x,  i) { while ((i = index(x, "\001")) > 0) x = substr(x, 1, i - 1) "\\|" substr(x, i + 1); return x }
      { line = $0; gsub(/\\\|/, "\001", line); n = split(line, c, "|") }
      !hdr && line ~ /^\|[ \t]*#[ \t]*\|/ {
        for (i = 2; i < n; i++) { x = trim(c[i]); if (x == "Status") si = i; if (x == "Runs on") ri = i }
        hdr = 1; print; next }
      hdr && si && !done_row && line ~ /^\|/ && trim(c[2]) == t {
        r = ri ? tolower(trim(c[ri])) : ""; cur = tolower(trim(c[si]))
        if (r !~ /^main/ && index(cur, s) != 1 && !(s == "in progress" && cur ~ /^done/)) {
          c[si] = " " s " "; out = c[1]; for (i = 2; i <= n; i++) out = out "|" c[i]
          print unesc(out); done_row = 1; next }
      }
      { print }' "$plan" > "$tmp" && ! cmp -s "$tmp" "$plan"; then
    mv "$tmp" "$plan" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
  return 0
}

# pre_tool_use: Orchestrate main session launching a plan row
pre_tool_use() {
  local sid cwd tag slug task chain st
  [ -z "$(printf '%s' "$payload" | jq -r '.agent_id // empty' 2>/dev/null)" ] || return 0
  sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
  mode_is_orch "$sid" || return 0
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  tag=$(printf '%s' "$payload" | jq -r '.tool_input.prompt // ""' 2>/dev/null \
    | sed -nE '1,3s/.*\[sdlc:([a-z0-9-]+)\/(T[0-9]+) est=[^]]*\].*/\1 \2/p' | head -n 1)
  [ -n "$tag" ] || return 0
  slug="${tag% *}"; task="${tag#* }"
  chain=$(chain_dir "$cwd" "$slug" "$sid") || return 0
  st=$(grep -m 1 -E '^- \*\*Status\*\*:' "$chain/plan.md" 2>/dev/null)
  case "$st" in *APPROVED*|*approved*) ;; *) return 0 ;; esac
  set_status "$chain/plan.md" "$task" "in progress"
  return 0
}

subagent_stop() {
  local cwd agent aid tpath report out slug logf line sid chain
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  aid=$(printf '%s' "$payload" | jq -r '.agent_id // empty' 2>/dev/null)
  agent=$(printf '%s' "$payload" | jq -r '.agent_type // empty' 2>/dev/null)
  tpath=$(printf '%s' "$payload" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
  report=$(subagent_report "$payload")
  [ -n "$cwd" ] && [ -n "$tpath" ] && [ -r "$tpath" ] || return 0

  out=$(jq -Rn -c --arg agent "$agent" --arg report "$report" --argjson pats "$(leak_patterns_json)" '
    def ts: sub("\\.[0-9]+"; "") | fromdateiso8601;
    def r1: (. * 10 | round) / 10;
    def dev($a; $e): (($a - $e) / $e * 100 | round);
    def redact: reduce $pats[] as $p (.; gsub($p; "[redacted]"));
    [inputs | fromjson? | select(type == "object")] as $l
    | ([$l[] | select(.type == "user")] | first) as $u
    | ($u.message.content
       | if type == "string" then .
         elif type == "array" then [.[] | select(.type? == "text") | .text] | join("\n")
         else "" end) as $prompt
    | ($prompt | capture("\\[sdlc:(?<slug>[a-z0-9-]+)/(?<task>T[0-9]+[a-z]?) est=(?<m>[0-9]+(?:\\.[0-9]+)?)m/(?<k>[0-9]+(?:\\.[0-9]+)?)k\\]")) as $tag
    | ($tag.m | tonumber) as $em | ($tag.k | tonumber) as $ek
    | select($em > 0 and $ek > 0)
    | [$l[] | select(.timestamp? | type == "string") | .timestamp] as $t
    | ([$l[] | select(.type == "assistant" and (.message.id? | type == "string"))]
       | group_by(.message.id) | map(last)) as $msgs
    | ([$msgs[] | .message.usage | (.input_tokens // 0) + (.output_tokens // 0)
        + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)] | add // 0) as $tok
    # usd_min: a floor, output tokens are not in transcripts. $/M tokens
    # (input, output, cache read); cache writes at 1.25x input; unknown model = null
    | {"claude-fable-5-2": [8, 40, 0.2], "claude-opus-5-5": [4, 20, 0.2],
       "claude-sonnet-5-5": [2, 10, 0.1], "claude-haiku-5-5": [0.1, 0.5, 0.01]} as $price
    | ([$msgs[] | ($price[.message.model? // ""]) as $p
        | if $p == null then null else .message.usage
          | ((.input_tokens // 0) * $p[0] + (.output_tokens // 0) * $p[1]
             + (.cache_creation_input_tokens // 0) * $p[0] * 1.25
             + (.cache_read_input_tokens // 0) * $p[2]) / 1000000 end]) as $usds
    | (if ($usds | length) > 0 and ($usds | all(. != null))
       then ($usds | add * 100 | round / 100) else null end) as $usd
    # Active minutes: the span minus the waits for a new prompt (a user
    # message that is not a tool result, over 5 min after the previous line),
    # e.g. an integrator continued with SendMessage after the developer replied
    | ([$l[] | select(.timestamp? | type == "string")
        | {s: (.timestamp | ts),
           p: (.type == "user" and ((.message.content? | type) == "string"))}]) as $e
    | ([range(1; $e | length) as $i
        | ($e[$i].s - $e[$i - 1].s) as $g
        | select($e[$i].p and $g > 300) | $g] | add // 0) as $idle
    | (((($t | last | ts) - ($t | first | ts)) - $idle) / 60 | r1) as $min
    | (($tok / 1000) | round) as $ktok
    | dev($min; $em) as $dm | dev($ktok; $ek) as $dt
    | ($report | capture("Deviation cause:[ \t]*(?<c>[^\n]*)").c // ""
       | sub("^\\s+"; "") | sub("\\s+$"; "") | redact | .[0:200]) as $cause
    | {slug: $tag.slug,
       rec: {task: $tag.task, runs_on: $agent,
             model: ([$l[] | select(.type == "assistant") | .message.model? // empty] | first // ""),
             est_min: $em, est_ktok: $ek, min: $min, ktok: $ktok, usd_min: $usd,
             dev_min_pct: $dm, dev_tok_pct: $dt,
             flag: (($dm | fabs) > 50 or ($dt | fabs) > 50), cause: $cause,
             date: ($t | last | .[0:10])}}
  ' "$tpath" 2>/dev/null) || return 0
  [ -n "$out" ] || return 0

  slug=$(printf '%s' "$out" | jq -r '.slug' 2>/dev/null)
  [ -n "$slug" ] || return 0
  line=$(printf '%s' "$out" | jq -c --arg id "$aid" '.rec + (if $id == "" then {} else {agent_id: $id} end)' 2>/dev/null) || return 0
  [ -n "$line" ] || return 0
  sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
  chain=$(chain_dir "$cwd" "$slug" "$sid") || { machine_append "$line" "$cwd" "$aid"; return 0; }
  logf="$chain/actuals.jsonl"
  append_log "$logf" "$line" "$aid"
  machine_append "$line" "$(dirname "$(dirname "$chain")")" "$aid"
  if [ "$agent" = integrator ]; then
    stamp_cost "$chain" "$slug" "$logf" "$line" "$report"
  fi
  plan_result "$chain" "$slug" "$(printf '%s' "$line" | jq -r '.task' 2>/dev/null)" "$report" "$agent"

  return 0
}

# artifact_of <chain> <slug> <report>: the integrator's artifact in the chain
artifact_of() {
  local apath
  apath=$(printf '%s\n' "$3" | sed -nE 's/^[[:space:]]*ARTIFACT:[[:space:]]*([^[:space:]]+).*/\1/p' | head -n 1)
  printf '%s' "$apath" | grep -qE "(^|/)\.sdlc/$2/work/[A-Za-z0-9_.-]+\.md$" || return 1
  [ -f "$1/work/$(basename "$apath")" ] && [ ! -L "$1/work/$(basename "$apath")" ] || return 1
  printf '%s\n' "$1/work/$(basename "$apath")"
}

# plan_result <chain> <slug> <task> <report> <agent>: the result into the plan
# row. Integrator: its artifact's result. Any other agent run as a plan row:
# the report's RESULT line, done when it has none (reviewers report findings).
plan_result() {
  local art res
  printf '%s' "$3" | grep -qE '^T[0-9]+$' || return 0
  mode_is_orch "$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)" || return 0
  if [ "${5:-integrator}" != integrator ]; then
    res=$(printf '%s\n' "$4" | sed -nE 's/^[[:space:]]*RESULT:[[:space:]]*(done|blocked|needs-decision).*/\1/p' | head -n 1)
    set_status "$1/plan.md" "$3" "${res:-done}"
    return 0
  fi
  art=$(artifact_of "$1" "$2" "$4") || return 0
  res=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } /^result:/ { sub(/^result:[ \t]*/, ""); print $1; exit }' "$art")
  case "$res" in done|blocked|needs-decision) set_status "$1/plan.md" "$3" "$res" ;; esac
  return 0
}

# stamp_cost <chain> <slug> <log> <record> <report>: Orchestrate mode. Writes
# "cost: {tokens_k, usd_min, minutes, agents}" into the integrator's artifact:
# its own record plus the nested agents it tagged T<n>a, T<n>b... Rewrites the
# frontmatter's cost line, never appends. Silent on any problem.
stamp_cost() {
  local chain="$1" slug="$2" log="$3" rec="$4" report="$5" art cost tmp
  # Relative to the chain's repo, or absolute when the chain lives elsewhere
  art=$(artifact_of "$chain" "$slug" "$report") || return 0
  cost=$(jq -R -r -n --argjson own "$rec" '
    [inputs | fromjson? | select(type == "object")] as $all
    | ($own.task | sub("[a-z]$"; "")) as $base
    | [$all[] | select((.task? // "") | test("^" + $base + "[a-z]$"))] as $nested
    | ([$own] + $nested) as $r
    | ([$r[] | .usd_min] | if all(. != null) then (add * 100 | round / 100 | tostring) else "null" end) as $usd
    | "cost: {tokens_k: \([$r[] | .ktok // 0] | add), usd_min: \($usd), minutes: \($own.min), agents: \($r | length)}"
  ' "$log" 2>/dev/null) || return 0
  [ -n "$cost" ] || return 0
  tmp=$(mktemp "$art.XXXXXX" 2>/dev/null) || return 0
  if awk -v c="$cost" 'NR == 1 { fm = ($0 == "---") } fm && NR > 1 && $0 == "---" { fm = 0 }
      fm && /^cost:/ { print c; skip = 1; next } skip && /^[[:space:]]/ { next } { skip = 0; print }' "$art" > "$tmp"; then
    mv "$tmp" "$art" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
  return 0
}

post_tool_use() {
  local cwd tool fpath tpath now logf lsrc tsrc out
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  tool=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)
  fpath=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  tpath=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)
  case "$tool" in
    Edit|Write|MultiEdit) ;;
    Bash)
      # The plan's Status edited from a script (python3, sed -i...): the plan
      # is named in the command, or the command runs in the chain and names
      # plan.md. Same measuring path as an Edit.
      local bcmd chain
      bcmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)
      printf '%s' "$bcmd" | grep -q 'plan\.md' || return 0
      fpath=$(printf '%s' "$bcmd" | grep -oE '[^[:space:]"'"'"';|&]*\.sdlc/[a-z0-9-]+/plan\.md' | head -n 1)
      if [ -z "$fpath" ]; then
        chain=$(printf '%s' "$bcmd" | grep -oE '[^[:space:]"'"'"';|&]*\.sdlc/[a-z0-9-]+' | head -n 1)
        [ -n "$chain" ] || case "$cwd" in */.sdlc/*) chain=$(printf '%s' "$cwd" | sed -nE 's#^(.*/\.sdlc/[a-z0-9-]+).*$#\1#p') ;; esac
        [ -n "$chain" ] || return 0
        fpath="$chain/plan.md"
      fi
      ;;
    *) return 0 ;;
  esac
  [ -n "$fpath" ] || return 0
  case "$fpath" in /*) ;; *) [ -n "$cwd" ] && fpath="$cwd/$fpath" || return 0 ;; esac
  printf '%s' "$fpath" | grep -Eq '/\.sdlc/[a-z0-9-]+/plan\.md$' || return 0
  [ -r "$fpath" ] && [ -n "$cwd" ] || return 0
  local rdir rcwd
  rdir=$(cd "$(dirname "$fpath")" 2>/dev/null && pwd -P) || return 0
  rcwd=$(sdlc_root "$cwd") || rcwd=$(cd "$cwd" 2>/dev/null && pwd -P) || return 0
  # The plan of this repo, or the session's active chain (another repo)
  case "$rdir/" in
    "$rcwd"/*) ;;
    *) [ "$rdir" = "$(chain_active "$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)")" ] || return 0 ;;
  esac
  now=${TASK_ACTUALS_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  logf="$(dirname "$fpath")/actuals.jsonl"
  # --rawfile, not --arg: a main transcript is several MB, above ARG_MAX
  lsrc=/dev/null; [ -r "$logf" ] && lsrc="$logf"
  tsrc=/dev/null; [ -n "$tpath" ] && [ -r "$tpath" ] && tsrc="$tpath"

  out=$(jq -Rn -c --arg now "$now" --argjson pats "$(leak_patterns_json)" --rawfile log "$lsrc" --rawfile tr "$tsrc" '
    def ts: sub("\\.[0-9]+"; "") | fromdateiso8601;
    def r1: (. * 10 | round) / 10;
    def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
    def redact: reduce $pats[] as $p (.; gsub($p; "[redacted]"));
    def cells: split("|") | .[1:-1] | map(trim);
    def dev($a; $e): (($a - $e) / $e * 100 | round);
    def cell($c; $i): if $i == null then "" else ($c[$i] // "") end;
    [inputs] as $lines
    | ($log | split("\n") | map(fromjson? | select(type == "object"))) as $recs
    | ($tr | split("\n") | map(fromjson? | select(type == "object"))) as $tl
    | ([$lines | to_entries[] | select(.value | contains("| # |"))] | first) as $h
    | select($h != null)
    | ($h.value | cells) as $hc
    | ($hc | index("Runs on")) as $ri | ($hc | index("Est")) as $ei | ($hc | index("Status")) as $si
    | select($ri != null and $si != null)
    | ($now | ts) as $n
    | $lines[($h.key + 1):][] | select(startswith("|"))
    | cells as $c
    | select(($c[0] // "") | test("^T[0-9]+[a-z]?$"))
    | $c[0] as $task
    | select(cell($c; $ri) | ascii_downcase | startswith("main"))
    | cell($c; $si) as $st
    | [$recs[] | select(.task == $task)] as $mine
    | ($mine | length > 0 and (last | .event? == "start")) as $open
    | ($mine | any(.[]; .event? != "start")) as $closed
    | if ($st | test("^in progress"; "i")) and ($open | not) and ($closed | not)
      then {task: $task, event: "start", ts: $now}
      elif ($st | test("^done"; "i")) and $open then
        ($mine | last | .ts | ts) as $s
        | (cell($c; $ei) | (capture("^(?<m>[0-9]+(?:\\.[0-9]+)?)m/(?<k>[0-9]+(?:\\.[0-9]+)?)(?<u>[kM])$") // null)) as $e
        | (if $e == null then null else ($e.m | tonumber) end) as $em
        | (if $e == null then null else ($e.k | tonumber) * (if $e.u == "M" then 1000 else 1 end) end) as $ek
        | [$tl[] | select(.type == "assistant"
            and ((.timestamp? | type) == "string")
            and ((try (.timestamp | ts) catch null) as $x | $x != null and $x >= $s and $x <= $n))] as $w
        | ([$w[] | select((.message.id? | type) == "string")] | group_by(.message.id) | map(last)) as $msgs
        | ([$msgs[] | .message.usage | (.input_tokens // 0) + (.output_tokens // 0)
            + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)] | add // 0) as $tok
        # usd_min: same price table and floor as subagent_stop
        | {"claude-fable-5-2": [8, 40, 0.2], "claude-opus-5-5": [4, 20, 0.2],
           "claude-sonnet-5-5": [2, 10, 0.1], "claude-haiku-5-5": [0.1, 0.5, 0.01]} as $price
        | ([$msgs[] | ($price[.message.model? // ""]) as $p
            | if $p == null then null else .message.usage
              | ((.input_tokens // 0) * $p[0] + (.output_tokens // 0) * $p[1]
                 + (.cache_creation_input_tokens // 0) * $p[0] * 1.25
                 + (.cache_read_input_tokens // 0) * $p[2]) / 1000000 end]) as $usds
        | (if ($usds | length) > 0 and ($usds | all(. != null))
           then ($usds | add * 100 | round / 100) else null end) as $usd
        | ((($n - $s) / 60) | r1) as $min
        | (($tok / 1000) | round) as $ktok
        | (if $em != null and $em > 0 then dev($min; $em) else null end) as $dm
        | (if $ek != null and $ek > 0 then dev($ktok; $ek) else null end) as $dt
        | {task: $task, runs_on: "main",
           model: ([$w[] | .message.model? // empty] | first // ""),
           est_min: $em, est_ktok: $ek, min: $min, ktok: $ktok, usd_min: $usd,
           dev_min_pct: $dm, dev_tok_pct: $dt,
           flag: ((($dm // 0) | fabs) > 50 or (($dt // 0) | fabs) > 50),
           cause: (($st | capture("cause:[ \t]*(?<c>.*)") // {c: ""}) | .c | trim | sub("\\)$"; "") | trim | redact | .[0:200]),
           date: $now[0:10]}
      else empty end
  ' "$fpath" 2>/dev/null) || return 0
  [ -n "$out" ] || return 0
  append_log "$logf" "$out" ""
  machine_append "$out" "$cwd" ""
  return 0
}

case "$event" in
  PreToolUse) pre_tool_use ;;
  SubagentStop) subagent_stop ;;
  PostToolUse) post_tool_use ;;
  *) ;;
esac
exit 0

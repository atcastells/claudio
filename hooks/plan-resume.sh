#!/bin/bash
# plan-resume: after a compaction, points the session back at the open tasks
# of every .sdlc/<slug>/plan.md. Playbook rule: the Status column is the live
# task list and the resume point.
# SessionStart hook (matcher: compact|resume). Output = additionalContext; never blocks.
# The repo is cwd, or the one above it when cwd is inside .sdlc/. In Orchestrate mode
# it also reads the active chain, which may live in another repo, and lists the
# delegated tasks that never came back: a work/T<n>-brief.md or an "in progress"
# row with no T<n>-result|finding|decision-request artifact in work/. A hook
# cannot relaunch an agent; the main session does, from that list.

. "$(dirname "$0")/lib/mode.sh"
. "$(dirname "$0")/lib/chain.sh"

payload=$(cat)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
src=$(printf '%s' "$payload" | jq -r '.source // empty' 2>/dev/null)
# cwd itself, or the repo above it when cwd is inside .sdlc/ (no wider walk)
proj=""
if [ -n "$cwd" ] && [ -d "$cwd/.sdlc" ]; then proj="$cwd"
else case "$cwd" in */.sdlc/*|*/.sdlc) proj=$(sdlc_root "$cwd") || proj="" ;; esac; fi
active=""
mode_is_orch "$sid" && active=$(chain_active "$sid")
[ -n "$proj" ] || [ -n "$active" ] || exit 0

plans=()
[ -n "$proj" ] && plans+=("$proj"/.sdlc/*/plan.md)
if [ -n "$active" ] && [ -f "$active/plan.md" ]; then
  case "$active/plan.md" in "$proj"/.sdlc/*) [ -n "$proj" ] || plans+=("$active/plan.md") ;; *) plans+=("$active/plan.md") ;; esac
fi

lines=()
for plan in "${plans[@]}"; do
  [ -f "$plan" ] || continue
  # Task rows: | T<n> | ... | <status> |  — the last non-empty cell is the status.
  # With a "## Tasks" heading only that section counts: "Estimate vs actual"
  # also has T<n> rows.
  scoped=0; grep -q '^## Tasks' "$plan" && scoped=1
  open=$(awk -F'|' -v scoped="$scoped" '
    /^## / { intasks = ($0 ~ /^## Tasks/) }
    (!scoped || intasks) && $1 ~ /^[[:space:]]*$/ && $2 ~ /^[[:space:]]*T[0-9]+[a-z]?[[:space:]]*$/ {
      id = $2; n = NF; while (n > 2 && $n ~ /^[[:space:]]*$/) n--; st = $n
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id); gsub(/^[[:space:]]+|[[:space:]]+$/, "", st)
      if (tolower(st) !~ /^done/) out = out (out ? ", " : "") id " (" st ")"
    }
    END { print out }' "$plan")
  shown="$plan"; [ -n "$proj" ] && shown="${plan#"$proj"/}"
  [ -n "$open" ] && lines+=("$shown: $open")
done

pending=""
if [ -n "$active" ] && [ -d "$active/work" ]; then
  ids=$( { for b in "$active"/work/T*-brief.md; do [ -f "$b" ] && basename "$b" | sed -nE 's/^(T[0-9]+)-brief\.md$/\1/p'; done
           [ -f "$active/plan.md" ] && awk -F'|' '$2 ~ /^[[:space:]]*T[0-9]+[[:space:]]*$/ { id=$2; n=NF; while (n > 2 && $n ~ /^[[:space:]]*$/) n--; st=tolower($n)
             gsub(/[[:space:]]/, "", id); if (st ~ /^[[:space:]]*in progress/) print id }' "$active/plan.md"; } | sort -u)
  for id in $ids; do
    back=0
    for a in "$active/work/$id"-result*.md "$active/work/$id"-finding*.md "$active/work/$id"-decision-request*.md; do
      [ -f "$a" ] && back=1
    done
    [ "$back" = 1 ] && continue
    b=""; [ -f "$active/work/$id-brief.md" ] && b=" (brief: $active/work/$id-brief.md)"
    pending="$pending${pending:+, }$id$b"
  done
fi
[ ${#lines[@]} -eq 0 ] && [ -z "$pending" ] && exit 0

case "$src" in resume) what="the session was resumed" ;; *) what="context was compacted" ;; esac
ctx="Claudio: $what. Resume from the Status column of the plan, not from memory."
[ ${#lines[@]} -gt 0 ] && ctx="$ctx Open tasks:
$(printf -- '- %s\n' "${lines[@]}")"
[ -n "$pending" ] && ctx="$ctx
Orchestrate, active chain $active: delegated tasks with no artifact back (the agent stopped): $pending. Relaunch each with the integrator now, same tag and brief, telling it to continue from the files already changed."
jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'

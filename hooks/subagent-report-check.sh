#!/bin/bash
# subagent-report-check: sends a verifier/reviewer/implementer report back when
# it lacks its header or an IMPORTANT finding lacks its demonstration.
# Playbook rule: an Important finding carries how to demonstrate the failure.
# Two events. PreToolUse on SubagentHandback checks tool_input.message before
# the report leaves; it blocks at most once per agent (marker file
# ${TMPDIR:-/tmp}/claudio-report-<agent_id>; no agent_id, or one not matching [A-Za-z0-9_-]+, = never blocks).
# SubagentStop checks last_assistant_message, except when the transcript holds
# a SubagentHandback call (already checked on PreToolUse).
# Exit 2 = the subagent keeps working and fixes its report.

payload=$(cat)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)
agent_id=$(printf '%s' "$payload" | jq -r '.agent_id // ""' 2>/dev/null)
tpath=$(printf '%s' "$payload" | jq -r '.agent_transcript_path // ""' 2>/dev/null)
pre=false
agent=$(printf '%s' "$payload" | jq -r '.agent_type // ""' 2>/dev/null)
active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)
report=$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null)

case "$agent" in
  verifier) header='^[[:space:]]*VERDICT: (green|amber|red)'; want='VERDICT: green | amber | red' ;;
  reviewer) header='^[[:space:]]*PASS: (bugs|security|conformance)'; want='PASS: bugs | security | conformance' ;;
  implementer) header='^[[:space:]]*TASK: [a-z0-9-]+/T[0-9]+[a-z]?([[:space:]:.,*]|$)'; want='TASK: <slug>/T<n>' ;;
  integrator) header='^[[:space:]]*ARTIFACT: '; want='ARTIFACT: .sdlc/<slug>/work/<file>.md' ;;
  *) exit 0 ;;
esac
if [ "$tool" = SubagentHandback ]; then
  pre=true
  report=$(printf '%s' "$payload" | jq -r '.tool_input.message // ""' 2>/dev/null)
  [[ "$agent_id" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
  marker="${TMPDIR:-/tmp}/claudio-report-$agent_id"
  [ -e "$marker" ] && exit 0
elif [ -n "$tool" ]; then
  exit 0
else
  # SubagentStop: the handback was already checked on PreToolUse
  [ -n "$tpath" ] && [ -r "$tpath" ] && grep -q '"name":"SubagentHandback"' "$tpath" && exit 0
  # Already sent back once: let it stop rather than loop
  [ "$active" = true ] && exit 0
fi

problems=()
if ! printf '%s\n' "$report" | grep -qaE "$header"; then
  if [ "$agent" = implementer ]; then
    problems+=("no '$want' line (task IDs are T<n> with an optional letter, e.g. T3b; phases go in the Task cell, not the ID)")
  else
    problems+=("no '$want' line")
  fi
fi
if [ "$agent" = implementer ]; then
  red_ok=false
  while IFS= read -r line; do
    after=${line#*→}
    after=$(printf '%s' "$after" | tr '[:upper:]' '[:lower:]' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Output that opens with an admission ("not seen", "none.", "passed") is not red
    case "$after" in
      ""|"not seen"*|"n/a"*|"no"|"no"[!a-z]*|"none"|"none"[!a-z]*|"pass"|"pass"[!a-z]*|"passed"*|"green"*) ;;
      *) red_ok=true; break ;;
    esac
  done < <(printf '%s\n' "$report" | grep -aE '^[[:space:]]*(Red|Mutation): .*→')
  # A blocked task may stop before any test exists
  printf '%s\n' "$report" | grep -qaE '^[[:space:]]*RESULT: blocked([[:space:]]|$)' && red_ok=true
  [ "$red_ok" = true ] || problems+=("no 'Red: <command> → <failing output>' or 'Mutation: <what was broken> → <failing output>' line with literal output")
  printf '%s\n' "$report" | grep -qaE '^[[:space:]]*RESULT: (done|blocked)([[:space:]]|$)' || problems+=("no 'RESULT: done | blocked' line")
  printf '%s\n' "$report" | grep -qaE '^[[:space:]]*Deviation cause: .+' || problems+=("no 'Deviation cause:' line (use 'none' if there was no deviation)")
  printf '%s\n' "$report" | grep -qaE '^[[:space:]]*Attempts: [0-9]+' || problems+=("no 'Attempts: <n>' line (how many times the task's test ran)")
fi
if [ "$agent" = integrator ]; then
  # Orchestrate mode: the report points to an artifact that exists, with its header
  apath=$(printf '%s\n' "$report" | sed -nE 's/^[[:space:]]*ARTIFACT:[[:space:]]*([^[:space:]]+).*/\1/p' | head -n 1)
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)
  if [ -n "$apath" ]; then
    if ! printf '%s' "$apath" | grep -qE '^\.sdlc/[a-z0-9-]+/work/[A-Za-z0-9_.-]+\.md$' || [ "${apath#*..}" != "$apath" ]; then
      problems+=("ARTIFACT path '$apath' is not .sdlc/<slug>/work/<file>.md")
    elif [ -z "$cwd" ] || [ ! -f "$cwd/$apath" ]; then
      problems+=("ARTIFACT file $apath does not exist: write it from ~/.claude/skills/sdlc/templates/artifact.md")
    else
      front=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$cwd/$apath")
      for k in task kind result data regen evidence; do
        printf '%s\n' "$front" | grep -qE "^$k:[[:space:]]*[^[:space:]]" || problems+=("the artifact's frontmatter lacks '$k:'")
      done
      # Review findings it cites must be on disk (reviewers cannot write them)
      slug=$(printf '%s' "$apath" | cut -d/ -f2)
      if { printf '%s\n' "$report"; cat "$cwd/$apath"; } 2>/dev/null | grep -qaF 'review/findings.md' \
         && [ ! -f "$cwd/.sdlc/$slug/review/findings.md" ]; then
        problems+=("the artifact cites review/findings.md but .sdlc/$slug/review/findings.md does not exist: write the reviewers' findings there (one section per pass, each with its demonstration)")
      fi
    fi
  fi
fi
missing=$(printf '%s\n' "$report" | grep -aF '[IMPORTANT]' | grep -avF 'demonstration:')
[ -n "$missing" ] && problems+=("[IMPORTANT] without 'demonstration:':
$missing")

[ ${#problems[@]} -eq 0 ] && exit 0
[ "$pre" = true ] && : > "$marker"
{
  printf 'subagent-report-check: the %s report does not follow its format:\n' "$agent"
  printf -- '- %s\n' "${problems[@]}"
  printf 'Fix the report. A finding you cannot demonstrate goes under "Unconfirmed".\n'
} >&2
exit 2

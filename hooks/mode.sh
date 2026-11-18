#!/bin/bash
# mode: per-session mode switches. /vibe turns Vibe on, /vibe off returns to Spec;
# /orchestrate turns Orchestrate on, /orchestrate off turns it off (independent of
# Spec/Vibe). UserPromptSubmit toggles the session markers; SessionStart re-injects
# the notices after compact/resume and clears the markers on startup/clear. Never
# echoes the prompt. Always exit 0.

. "$(dirname "$0")/lib/mode.sh"

ON="Claudio: this session is in Vibe mode (/vibe off returns to Spec). Follow ~/.claude/skills/vibe/SKILL.md (read it again after a compaction): read .sdlc/map.md and the open .sdlc/vibe/*.md first. Small, non-final changes open no .sdlc/<slug>/ and need no approval; promote an idea to intent.md when it settles. Git stays with the developer; credentials, the release rule and verifying before claiming still apply."
OFF="Claudio: this session is back in Spec mode: the full artifact chain applies (intent, spec, approved plan)."
ORCH_ON="Claudio: this session is in Orchestrate mode (/orchestrate off turns it off). Follow ~/.claude/skills/orchestrate/SKILL.md (read it again after a compaction): you plan, delegate every task to the integrator agent, read only the header and summary of the artifact it returns, and decide what to persist. You do not explore, edit or run tests; a hook blocks it outside .sdlc/<slug>/. Meant for Fable 5.2 chosen at session start."
ORCH_OFF="Claudio: Orchestrate mode is off: the main session works as usual."

emit() {
  jq -n --arg e "$1" --arg c "$2" \
    '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
}

payload=$(cat)
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
marker=$(mode_marker "$sid") || exit 0
omarker=$(orch_marker "$sid") || exit 0

# toggle <marker> <first word after the command> <on text> <off text>
toggle() {
  if [ "$2" = off ]; then
    rm -f "$1" 2>/dev/null
    [ -e "$1" ] && exit 0
    emit UserPromptSubmit "$4"
  else
    # Never write through a planted link (shared /tmp): remove, then create exclusively
    rm -f "$1"
    ( set -C; : > "$1" ) 2>/dev/null || exit 0
    emit UserPromptSubmit "$3"
  fi
}

case "$event" in
  UserPromptSubmit)
    first=$(printf '%s' "$payload" | jq -r '.prompt // "" | split("\n")[0]' 2>/dev/null)
    first="${first#"${first%%[![:space:]]*}"}"
    first="${first%"${first##*[![:space:]]}"}"
    for cmd in vibe orchestrate; do
      rest="${first#/$cmd}"
      [ "$first" = "/$cmd" ] || [ "${rest# }" != "$rest" ] || continue
      read -r word _ <<< "$rest"
      if [ "$cmd" = vibe ]; then toggle "$marker" "$word" "$ON" "$OFF"
      else toggle "$omarker" "$word" "$ORCH_ON" "$ORCH_OFF"; fi
      exit 0
    done
    ;;
  SessionStart)
    src=$(printf '%s' "$payload" | jq -r '.source // ""' 2>/dev/null)
    case "$src" in
      compact|resume)
        ctx=""
        [ -e "$marker" ] && ctx="$ON"
        [ -e "$omarker" ] && ctx="${ctx:+$ctx }$ORCH_ON"
        [ -n "$ctx" ] && emit SessionStart "$ctx"
        ;;
      startup|clear) rm -f "$marker" "$omarker" ;;
    esac
    ;;
esac
exit 0

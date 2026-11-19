#!/bin/bash
# mode: per-session mode switches. /vibe turns Vibe on, /vibe off returns to Spec;
# /orchestrate turns Orchestrate on, /orchestrate off turns it off (independent of
# Spec/Vibe). /orchestrate <dir of .sdlc/<slug>> also records the active chain
# (lib/chain.sh); /orchestrate allow-test <file> lets agents of this session
# weaken that test file for 30 minutes (test-guard reads the list). Only a typed
# prompt reaches this hook, so a model cannot grant itself the exception. UserPromptSubmit toggles the session markers; SessionStart re-injects
# the notices after compact/resume and clears the markers on startup/clear. Never
# echoes the prompt. Always exit 0.

. "$(dirname "$0")/lib/mode.sh"
. "$(dirname "$0")/lib/chain.sh"

ON="Claudio: this session is in Vibe mode (/vibe off returns to Spec). Follow ~/.claude/skills/vibe/SKILL.md (read it again after a compaction): read .sdlc/map.md and the open .sdlc/vibe/*.md first. Small, non-final changes open no .sdlc/<slug>/ and need no approval; promote an idea to intent.md when it settles. Git stays with the developer; credentials, the release rule and verifying before claiming still apply."
OFF="Claudio: this session is back in Spec mode: the full artifact chain applies (intent, spec, approved plan)."
ORCH_ON="Claudio: this session is in Orchestrate mode (/orchestrate off turns it off). Follow ~/.claude/skills/orchestrate/SKILL.md (read it again after a compaction): you plan, delegate every task to the integrator agent, read only the header and summary of the artifact it returns, and decide what to persist. You do not explore, edit or run tests; a hook blocks it outside the chain (.sdlc/<slug>/, also another repo's), read-only git and git add/commit/push. Meant for a main session on a stronger model than the integrator (Opus 5.5)."
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

# same_model: a note when the main session already runs the integrator's model,
# read from the last assistant turn of the transcript (empty when unknown)
same_model() {
  local tp m
  tp=$(printf '%s' "$payload" | jq -r '.transcript_path // ""' 2>/dev/null)
  [ -n "$tp" ] && [ -r "$tp" ] || return 0
  m=$(tail -n 400 "$tp" 2>/dev/null | jq -r 'select(.type? == "assistant") | .message.model? // empty' 2>/dev/null | tail -n 1)
  case "$m" in claude-opus*) printf ' Note: this main session runs %s, the integrator'"'"'s model, so the cost split of the mode does not apply; its gain here is a short main context. Fable 5.2 at session start restores it.' "$m" ;; esac
}

# allow_test "<rest of the prompt line>": appends "<epoch> <file>" to the
# session's allow list (never through a link)
allow_test() {
  local f list
  read -r _ f _ <<< "$1"
  list="${marker%/claudio-mode-*}/claudio-allow-$sid"
  if ! printf '%s' "$f" | grep -qE '^[A-Za-z0-9_./~-]+$' || printf '/%s/' "$f" | grep -qF '/../'; then
    emit UserPromptSubmit "Claudio: /orchestrate allow-test needs one test file path (letters, digits, . _ - /). Nothing was allowed."
    return 0
  fi
  [ -L "$list" ] && rm -f "$list"
  printf '%s %s\n' "$(date +%s)" "$f" >> "$list" 2>/dev/null || return 0
  emit UserPromptSubmit "Claudio: the developer allows weakening the test file $f for 30 minutes (test-guard lets any agent of this session edit it). Tell the agent that edits it; say in the report what was removed and why."
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
      if [ "$cmd" = vibe ]; then toggle "$marker" "$word" "$ON" "$OFF"; exit 0; fi
      if [ "$word" = allow-test ]; then allow_test "$rest"; exit 0; fi
      if [ "$word" != off ] && [ "$word" != on ] && [ -n "$word" ]; then
        ( toggle "$omarker" on "$ORCH_ON" "$ORCH_OFF" ) >/dev/null
        chain=$(cd "${word/#\~/$HOME}" 2>/dev/null && pwd -P)
        if chain_ok "$chain"; then
          chain_set "$sid" "$chain"
          emit UserPromptSubmit "$ORCH_ON Active chain: $chain$(same_model)"
        else
          emit UserPromptSubmit "$ORCH_ON No active chain recorded: the argument is not a .sdlc/<slug>/ directory with intent, spec, plan or context.md. Writing the chain's plan.md records it.$(same_model)"
        fi
        exit 0
      fi
      if [ "$word" = off ]; then toggle "$omarker" off "$ORCH_ON" "$ORCH_OFF"
      else toggle "$omarker" "" "$ORCH_ON$(same_model)" "$ORCH_OFF"; fi
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
      startup|clear) rm -f "$marker" "$omarker" "${marker%/claudio-mode-*}/claudio-allow-$sid" ;;
    esac
    ;;
esac
exit 0

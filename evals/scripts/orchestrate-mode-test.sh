#!/bin/bash
# Scenarios: /orchestrate marker (hooks/lib/mode.sh) and hooks/mode.sh toggling it.
#   usage: orchestrate-mode-test.sh <hooks-dir> lib|hook
set -uo pipefail
hooks="$1"; part="${2:-hook}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }

if [ "$part" = lib ]; then
  # shellcheck disable=SC1091
  . "$hooks/lib/mode.sh" 2>/dev/null || { echo "  FAIL cannot source mode.sh"; exit 1; }
  out=$(orch_marker "abc-123_X"); rc=$?
  [ "$rc" = 0 ] || fail "valid id: rc=$rc"
  [ "$out" = "$tmp/claudio-orch-abc-123_X" ] || fail "valid id: path '$out'"
  for bad in "" "../x" "a b" "a/b"; do
    out=$(orch_marker "$bad"); rc=$?
    [ "$rc" = 1 ] || fail "invalid id '$bad': rc=$rc"
    [ -z "$out" ] || fail "invalid id '$bad': output '$out'"
    mode_is_orch "$bad" && fail "invalid id '$bad': mode_is_orch true"
  done
  mode_is_orch s1 && fail "mode_is_orch true without marker"
  : > "$tmp/claudio-orch-s1"
  mode_is_orch s1 || fail "mode_is_orch false with marker"
  mode_is_vibe s1 && fail "orch marker makes mode_is_vibe true"
  : > "$tmp/claudio-mode-s2"
  mode_is_orch s2 && fail "vibe marker makes mode_is_orch true"
  if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
  exit 1
fi

run_hook() {
  local payload
  payload=$(jq -n --arg e "$1" --arg s "$2" --arg p "$3" --arg src "$4" \
    '{hook_event_name:$e, session_id:$s, prompt:$p, source:$src}')
  OUT=$(printf '%s' "$payload" | bash "$hooks/mode.sh" 2>/dev/null); rc=$?
  [ "$rc" = 0 ] || fail "$1/$2: exit $rc"
}
prompt() { run_hook UserPromptSubmit "$1" "$2" ""; }
start() { run_hook SessionStart "$1" "" "$2"; }
orch="$tmp/claudio-orch-s1"; vibe="$tmp/claudio-mode-s1"

prompt s1 "/orchestrate"
[ -e "$orch" ] || fail "/orchestrate: marker not created"
[ ! -e "$vibe" ] || fail "/orchestrate: vibe marker created"
case "$OUT" in *"Orchestrate mode"*integrator*) ;; *) fail "/orchestrate: output lacks the mode notice" ;; esac

prompt s1 "/orchestrate off"
[ ! -e "$orch" ] || fail "/orchestrate off: marker still there"
case "$OUT" in *"Orchestrate mode is off"*) ;; *) fail "/orchestrate off: output lacks the off notice" ;; esac

prompt s1 "/orchestrated"
[ -z "$OUT" ] || fail "/orchestrated: output '$OUT'"
[ ! -e "$orch" ] || fail "/orchestrated: marker created"

# Vibe and Orchestrate are independent
: > "$vibe"
prompt s1 "/orchestrate"
[ -e "$vibe" ] || fail "/orchestrate removed the vibe marker"
prompt s1 "/vibe off"
[ -e "$orch" ] || fail "/vibe off removed the orch marker"

start s1 compact
case "$OUT" in *"Orchestrate mode"*) ;; *) fail "compact: lacks Orchestrate notice" ;; esac
: > "$vibe"
start s1 resume
case "$OUT" in *"Orchestrate mode"*) ;; *) fail "resume with both: lacks Orchestrate notice" ;; esac
case "$OUT" in *"Vibe mode"*) ;; *) fail "resume with both: lacks Vibe notice" ;; esac
printf '%s' "$OUT" | jq -e . >/dev/null 2>&1 || fail "resume with both: output is not one JSON object"
start s1 clear
[ ! -e "$orch" ] || fail "clear: orch marker kept"
[ ! -e "$vibe" ] || fail "clear: vibe marker kept"
: > "$orch"
start s1 startup
[ ! -e "$orch" ] || fail "startup: orch marker kept"

prompt s3 "/orchestrate ZXQ-SECRET-PROMPT"
case "$OUT" in *ZXQ-SECRET-PROMPT*) fail "output echoes the prompt" ;; esac

victim="$tmp/victim"; printf 'keep' > "$victim"
ln -s "$victim" "$tmp/claudio-orch-s7"
prompt s7 "/orchestrate"
[ "$(cat "$victim")" = keep ] || fail "symlinked marker: target was truncated"

if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

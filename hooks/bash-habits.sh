#!/bin/bash
# bash-habits: two reminders after a Bash call, never a block.
# Measured in ASTRA (13-19 Nov 2026): 2-12% of the implementers' test runs kept
# their output in a file, and 40-65% of their edits were python/perl scripts
# rewriting repo files instead of Edit.
# PostToolUse(Bash). Prints hookSpecificOutput.additionalContext JSON, exit 0.
#   1. A test run whose output goes to no file (no tee, no > file): keep it in
#      a file and read more from there instead of running it again.
#   2. A python/perl/ruby script that rewrites a file, with no temp path in
#      the command: edit repo files with Edit or Write.
# Any other event or tool, or a parse error: silent, exit 0.

payload=$(cat)
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)
[ "$event" = PostToolUse ] && [ "$tool" = Bash ] || exit 0
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -n "$cmd" ] || exit 0

notes=()

test_re='(^|[;&|(]|[[:space:]])(cargo (test|nextest)|npm (run )?test|pnpm (run )?test|yarn test|pytest|python3? -m pytest|go test|gradle(w)? test|\./gradlew test|mvn test|npx (jest|vitest)|jest|vitest|flutter test|dart test|dotnet test|bun test)([[:space:]]|$)'
if printf '%s' "$cmd" | grep -qE "$test_re"; then
  if ! printf '%s' "$cmd" | grep -qE -- '--no-run|--list([[:space:]]|$)|--collect-only'; then
    # a file sink: tee, or a redirect to something other than /dev/null or an fd
    if ! printf '%s' "$cmd" | grep -qE '\|[[:space:]]*tee[[:space:]]|(^|[^0-9&<>])(&>|>>?)[[:space:]]*[^&[:space:]/]|(&>|>>?)[[:space:]]*/[^d]|(&>|>>?)[[:space:]]*/d[^e]'; then
      notes+=("Test output went to no file. Next run: \`<command> 2>&1 | tee <log> | tail -40\`, then read more of the log with grep or Read instead of running the test again.")
    fi
  fi
fi

if printf '%s' "$cmd" | grep -qE '(python3?|perl|ruby)([[:space:]]+-[A-Za-z]+)*[[:space:]]+(-[[:space:]]*<<|-e|-pi|-0pi|-i)'; then
  if printf '%s' "$cmd" | grep -qE "write_text\(|\.write\(|open\([^)]*['\"][wa]['\"]|-0?pi|-i[[:space:]]"; then
    if ! printf '%s' "$cmd" | grep -qE 'mktemp|TMPDIR|/tmp/|/var/folders/|scratchpad|claudio-'; then
      notes+=("A script rewrote a file. Edit repo files with Edit or Write: hooks check those and the change is visible; scripts are for temp files.")
    fi
  fi
fi

[ ${#notes[@]} -gt 0 ] || exit 0
msg="bash-habits: ${notes[*]}"
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$m}}'
exit 0

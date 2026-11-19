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
#   3. grep/rg of an identifier (fn/func/def/class/struct... Name, or a bare
#      CamelCase / snake_case word) over the tree when the repo has a ./tags
#      index: look it up there (or with LSP) first. Once per agent or session.
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

# 3. Symbol grep with a tags index at the repo root
first=$(printf '%s' "$cmd" | sed -E 's/^(cd [^;&]*(;|&&)[[:space:]]*)//')
case "$first" in
  grep\ *|rg\ *|egrep\ *)
    if printf '%s' "$first" | grep -qE "(fn|func|def|class|struct|enum|trait|impl|signal|const)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*|[\"' ](\\b)?([A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*|[a-z][a-z0-9]*_[a-z0-9_]+)(\\b)?[\"' ]" \
       && ! printf '%s' "$first" | grep -qE "[[:space:]]tags([[:space:]]|$)" \
       && ! printf '%s' "$first" | grep -qE "\.(toml|md|ron|json|ya?ml|txt|log|csv)([[:space:]\"']|$)|--type[= ](toml|md|json|yaml)|-g ['\"]?\*\.(toml|md|ron|json)"; then
      cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)
      dir=$(printf '%s' "$cmd" | sed -nE 's/^cd[[:space:]]+([^;&[:space:]]+).*/\1/p')
      [ -n "$dir" ] && [ -d "$dir" ] || dir="$cwd"
      root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
      who=$(printf '%s' "$payload" | jq -r '(.agent_id // .session_id // "") | tostring' 2>/dev/null)
      mark="${TMPDIR:-/tmp}/claudio-tags-hint-$who"
      if [ -n "$root" ] && [ -s "$root/tags" ] && printf '%s' "$who" | grep -qE '^[A-Za-z0-9_-]+$' && [ ! -e "$mark" ]; then
        : > "$mark" 2>/dev/null
        notes+=("This repo has a tags index ($root/tags). Look a symbol up there first (\`rg '^Name\\t' tags\`, or the LSP tool for definition and references); grep stays for free text, config and docs.")
      fi
    fi ;;
esac

[ ${#notes[@]} -gt 0 ] || exit 0
msg="bash-habits: ${notes[*]}"
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$m}}'
exit 0

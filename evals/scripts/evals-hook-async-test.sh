#!/usr/bin/env bash
# usage: evals-hook-async-test.sh <repo root>
# The evals-on-config-change hook is registered async-rewake with a 600 s
# timeout, in the template and in a clean install.
set -u
root="${1:?usage: $0 <repo root>}"
fail=0

check() { # <label> <settings.json>
  local ok
  ok=$(jq -r '[.hooks.PostToolUse[]?
      | select(.matcher == "Write|Edit|MultiEdit|NotebookEdit")
      | .hooks[]?
      | select((.command // "") | contains("evals-on-config-change.sh"))
      | (.asyncRewake == true and .timeout == 600)] | (length > 0 and all)' "$2" 2>/dev/null)
  if [ "$ok" != "true" ]; then
    echo "FAIL: $1: evals hook entry lacks asyncRewake=true and timeout=600" >&2
    fail=1
  fi
}

check "template" "$root/settings.template.json"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
HOME="$tmp" WORKFLOW_INSTALL_NO_VERIFY=1 "$root/install.sh" --no-profile >/dev/null 2>&1
if [ -f "$tmp/.claude/settings.json" ]; then
  check "clean install" "$tmp/.claude/settings.json"
else
  echo "FAIL: clean install: no settings.json produced" >&2
  fail=1
fi

[ "$fail" -eq 0 ] && echo "all passed"
exit "$fail"

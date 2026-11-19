#!/bin/bash
# Checks a settings file: git add/commit/push are in permissions.ask, not deny
# (the developer confirms each one); the history-rewriting verbs stay denied.
#   usage: git-ask-test.sh <settings.json>
set -uo pipefail
f="$1"; fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
for r in "git commit *" "git commit" "git push *" "git push" "git add *" "git add"; do
  jq -e --arg r "Bash($r)" '.permissions.ask | index($r)' "$f" >/dev/null 2>&1 || fail "$r not in ask"
  jq -e --arg r "Bash($r)" '.permissions.deny | index($r)' "$f" >/dev/null 2>&1 && fail "$r still in deny"
done
for r in "git reset *" "git rebase *" "git clean *"; do
  jq -e --arg r "Bash($r)" '.permissions.deny | index($r)' "$f" >/dev/null 2>&1 || fail "$r not in deny"
done
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

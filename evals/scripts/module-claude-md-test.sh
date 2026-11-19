#!/bin/bash
# Scenarios for the module CLAUDE.md checks of skills/repo-setup/check.sh.
#   usage: module-claude-md-test.sh <path-to-check.sh>
set -uo pipefail
check="$1"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }
mk() { mkdir -p "$1" && cd "$1" && git init -q . && printf '# R\n' > CLAUDE.md && cd - >/dev/null; }
run() { WORKFLOW_HOME="$tmp/none" CLAUDE_GLOBAL_MD="$tmp/none.md" bash "$check" "$1" 2>&1; }

r="$tmp/a"; mk "$r"; mkdir -p "$r/crates/x" "$r/node_modules/y"
seq 1 31 | sed 's/^/l/' > "$r/crates/x/CLAUDE.md"
seq 1 40 > "$r/node_modules/y/CLAUDE.md"
o=$(run "$r")
printf '%s' "$o" | grep -q 'WARN  module CLAUDE.md over 30 lines: crates/x/CLAUDE.md' || fail a "long module file not warned"
printf '%s' "$o" | grep -q 'node_modules' && fail b "node_modules not skipped"
printf '%s' "$o" | grep -q 'WARN  no AGENTS.md symlink next to CLAUDE.md' || fail c "root AGENTS.md not warned"
printf '%s' "$o" | grep -q 'WARN  no AGENTS.md symlink next to crates/x/CLAUDE.md' || fail d "module AGENTS.md not warned"

r="$tmp/b"; mk "$r"; mkdir -p "$r/crates/x"; printf '# x\n' > "$r/crates/x/CLAUDE.md"
( cd "$r" && ln -s CLAUDE.md AGENTS.md && cd crates/x && ln -s CLAUDE.md AGENTS.md )
o=$(run "$r")
printf '%s' "$o" | grep -q 'WARN  module CLAUDE.md\|WARN  no AGENTS.md' && fail e "clean repo warned: $(printf '%s' "$o" | grep WARN)"
printf '%s' "$o" | grep -q 'PASS  module CLAUDE.md files: 1' || fail f "module count not reported"

r="$tmp/c"; mk "$r"; printf 'copy\n' > "$r/AGENTS.md"
o=$(run "$r")
printf '%s' "$o" | grep -q 'WARN  AGENTS.md is not a symlink to CLAUDE.md' || fail g "regular AGENTS.md not warned"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }

#!/bin/bash
# Scenarios: repo-setup check.sh warns when CLAUDE.md names LSP but Rust has no
# LSP server for agents, and when it names a tags index that is missing.
#   usage: check-symbols-test.sh <check.sh>
set -uo pipefail
check="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; mkdir -p "$repo" "$tmp/bin"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
printf '%s\n' '# R' '## Buscar símbolos' 'Para Rust, la herramienta LSP; el índice `tags` (regenerar con `scripts/tags.sh`).' > "$repo/CLAUDE.md"
: > "$repo/Cargo.toml"
echo '{}' > "$tmp/settings.json"
out() { CLAUDE_USER_SETTINGS="$tmp/settings.json" CLAUDE_GLOBAL_MD="$tmp/none.md" PATH="$1" bash "$check" "$repo" 2>&1; }
o=$(out "/usr/bin:/bin")
printf '%s' "$o" | grep -q 'WARN  CLAUDE.md names LSP' || fail "no LSP server not warned"
printf '%s' "$o" | grep -q 'WARN  CLAUDE.md names a tags index' || fail "missing tags not warned"
echo '{"enabledPlugins":{"rust-analyzer-lsp@claude-plugins-official":true}}' > "$tmp/settings.json"
printf '#!/bin/sh\n' > "$tmp/bin/rust-analyzer"; chmod +x "$tmp/bin/rust-analyzer"
printf 'x\tsrc/a.rs\t1\n' > "$repo/tags"
o=$(out "$tmp/bin:/usr/bin:/bin")
printf '%s' "$o" | grep -q 'PASS  LSP for Rust' || fail "plugin and binary not passed"
printf '%s' "$o" | grep -q 'PASS  tags index present' || fail "tags present not passed"
rm "$repo/Cargo.toml"
o=$(out "/usr/bin:/bin")
printf '%s' "$o" | grep -q 'LSP' && fail "LSP checked without Cargo.toml"
[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }

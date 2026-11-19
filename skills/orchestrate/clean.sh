#!/bin/bash
# clean: the one delete Orchestrate mode allows. Removes each argument only if,
# with its parent resolved physically, it lies inside .sdlc/<slug>/work/ or is a
# claudio-* scratch path directly in ${TMPDIR:-/tmp} or /tmp. Session markers
# (claudio-mode-, -orch-, -allow-, -bash-, -report-) are never removed. A
# symlink is removed as a link, never followed. Refused paths are listed and
# make it exit 1; nothing else is touched.
#   usage: bash ~/.claude/skills/orchestrate/clean.sh <path>...
[ "$#" -gt 0 ] || { echo "usage: clean.sh <path>..." >&2; exit 2; }
tmps=()
for t in "${TMPDIR:-/tmp}" /tmp; do
  p=$(cd "$t" 2>/dev/null && pwd -P) && tmps+=("$p")
done
rc=0
for a in "$@"; do
  case "/$a/" in */../*|*/./*) echo "refused (.. or .): $a" >&2; rc=1; continue ;; esac
  a="${a%/}"
  [ -e "$a" ] || [ -L "$a" ] || { echo "not found: $a" >&2; continue; }
  parent=$(cd "$(dirname "$a")" 2>/dev/null && pwd -P) || { echo "refused: $a" >&2; rc=1; continue; }
  name=$(basename "$a")
  full="$parent/$name"
  ok=0
  case "$full" in */.sdlc/*/work/*) printf '%s' "$full" | grep -qE '/\.sdlc/[a-z0-9-]+/work/.+' && ok=1 ;; esac
  case "$full" in */.sdlc/*/work/*/.sdlc/*) ok=0 ;; esac
  for t in "${tmps[@]}"; do
    [ "$parent" = "$t" ] || continue
    case "$name" in
      claudio-mode-*|claudio-orch-*|claudio-allow-*|claudio-bash-*|claudio-report-*) ;;
      claudio-?*) ok=1 ;;
    esac
  done
  if [ "$ok" = 1 ]; then
    rm -rf -- "$full" && echo "removed: $a"
  else
    echo "refused (only .sdlc/<slug>/work/ and \$TMPDIR/claudio-*): $a" >&2; rc=1
  fi
done
exit "$rc"

# Sourced library: where the artifact chain of a session lives. No exit, no side
# effects except chain_set. Needs lib/mode.sh (orch_marker).
#   sdlc_root <dir>       prints the physical directory holding .sdlc/ for <dir>:
#                         the part before /.sdlc/ when <dir> is inside a chain,
#                         else the nearest ancestor with a .sdlc/ (at most 12
#                         levels); returns 1 when there is none
#   chain_ok <dir>        0 when <dir> is an existing .sdlc/<slug> directory
#                         holding intent.md, spec.md, plan.md or context.md
#   chain_active <sid>    prints the active chain of an Orchestrate session (the
#                         first line of its marker) when chain_ok; else returns 1
#   chain_set <sid> <dir> records <dir> as the active chain; the marker must
#                         already exist (the mode is on). Silent.
#   chain_dir <cwd> <slug> <sid>  prints the directory of <slug>: the one under
#                         sdlc_root <cwd>, else the active chain when its name is
#                         <slug>; returns 1 when neither exists

sdlc_root() {
  local d="${1:-}" n=0
  [ -n "$d" ] || return 1
  case "$d" in */.sdlc/*|*/.sdlc) d="${d%%/.sdlc/*}"; d="${d%/.sdlc}" ;; esac
  d=$(cd "$d" 2>/dev/null && pwd -P) || return 1
  while [ "$n" -lt 12 ]; do
    [ -d "$d/.sdlc" ] && { printf '%s\n' "$d"; return 0; }
    [ "$d" = / ] && return 1
    d=$(dirname "$d"); n=$((n+1))
  done
  return 1
}

chain_ok() {
  local d="${1:-}"
  [ -n "$d" ] && [ -d "$d" ] && [ ! -L "$d" ] || return 1
  printf '%s' "$d" | grep -qE '/\.sdlc/[a-z0-9-]+$' || return 1
  [ -f "$d/intent.md" ] || [ -f "$d/spec.md" ] || [ -f "$d/plan.md" ] || [ -f "$d/context.md" ]
}

chain_active() {
  local m c
  m=$(orch_marker "${1:-}") || return 1
  [ -f "$m" ] && [ ! -L "$m" ] || return 1
  IFS= read -r c < "$m" 2>/dev/null || [ -n "$c" ] || return 1
  chain_ok "$c" || return 1
  printf '%s\n' "$c"
}

chain_set() {
  local m="" d="${2:-}" tmp
  m=$(orch_marker "${1:-}") || return 0
  [ -f "$m" ] && [ ! -L "$m" ] || return 0
  chain_ok "$d" || return 0
  [ "$(head -n 1 "$m" 2>/dev/null)" = "$d" ] && return 0
  tmp=$(mktemp "$m.XXXXXX" 2>/dev/null) || return 0
  printf '%s\n' "$d" > "$tmp" && mv -f "$tmp" "$m" 2>/dev/null || rm -f "$tmp"
  return 0
}

chain_dir() {
  local root a
  printf '%s' "${2:-}" | grep -qE '^[a-z0-9-]+$' || return 1
  if root=$(sdlc_root "${1:-}") && [ -d "$root/.sdlc/$2" ]; then
    printf '%s\n' "$root/.sdlc/$2"; return 0
  fi
  a=$(chain_active "${3:-}") || return 1
  [ "$(basename "$a")" = "$2" ] || return 1
  printf '%s\n' "$a"
}

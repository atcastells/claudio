# Sourced library: per-session mode markers (Vibe, Orchestrate). No exit, no side effects.
#   mode_marker <session_id>  prints the Vibe marker path; returns 1 (no output) on an invalid id
#   mode_is_vibe <session_id> returns 0 only when the id is valid and the marker exists
#   orch_marker / mode_is_orch: the same for Orchestrate, an independent marker

mode_marker() {
  case "${1:-}" in
    ""|*[!A-Za-z0-9_-]*) return 1 ;;
  esac
  local base="${TMPDIR:-/tmp}"
  base="${base%/}"
  printf '%s\n' "$base/claudio-mode-$1"
}

mode_is_vibe() {
  case "${1:-}" in
    ""|*[!A-Za-z0-9_-]*) return 1 ;;
  esac
  local base="${TMPDIR:-/tmp}"
  [ -e "${base%/}/claudio-mode-$1" ]
}

orch_marker() {
  case "${1:-}" in
    ""|*[!A-Za-z0-9_-]*) return 1 ;;
  esac
  local base="${TMPDIR:-/tmp}"
  base="${base%/}"
  printf '%s\n' "$base/claudio-orch-$1"
}

mode_is_orch() {
  case "${1:-}" in
    ""|*[!A-Za-z0-9_-]*) return 1 ;;
  esac
  local base="${TMPDIR:-/tmp}"
  [ -e "${base%/}/claudio-orch-$1" ]
}

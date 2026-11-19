#!/bin/bash
# Scenarios: skills/orchestrate/clean.sh deletes only inside .sdlc/<slug>/work/
# and $TMPDIR/claudio-* scratch paths, never a session marker or a link target.
#   usage: orchestrate-clean-test.sh <clean.sh>
set -uo pipefail
clean="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp/t"; mkdir -p "$TMPDIR"
repo="$tmp/repo"; mkdir -p "$repo/.sdlc/demo/work/logs" "$repo/src" "$repo/.sdlc/demo/review"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
: > "$repo/.sdlc/demo/work/T1-result.md"; : > "$repo/.sdlc/demo/work/logs/a.log"
: > "$repo/src/keep.rs"; : > "$repo/.sdlc/demo/review/T1.log"
mkdir -p "$TMPDIR/claudio-test-x"; : > "$TMPDIR/claudio-test-x/a.log"
: > "$TMPDIR/claudio-orch-s1"; : > "$TMPDIR/other"
ln -s "$repo/src" "$repo/.sdlc/demo/work/link"

bash "$clean" "$repo/.sdlc/demo/work/T1-result.md" "$repo/.sdlc/demo/work/logs" >/dev/null 2>&1 || fail "work files refused"
[ -e "$repo/.sdlc/demo/work/T1-result.md" ] && fail "work file kept"
[ -e "$repo/.sdlc/demo/work/logs" ] && fail "work dir kept"
bash "$clean" "$TMPDIR/claudio-test-x" >/dev/null 2>&1 || fail "tmp scratch refused"
[ -e "$TMPDIR/claudio-test-x" ] && fail "tmp scratch kept"
bash "$clean" "$repo/.sdlc/demo/work/link" >/dev/null 2>&1 || fail "link refused"
[ -e "$repo/src/keep.rs" ] || fail "link target deleted"
for bad in "$repo/src" "$repo/src/keep.rs" "$repo/.sdlc/demo/review/T1.log" "$repo/.sdlc/demo/work" \
           "$TMPDIR/claudio-orch-s1" "$TMPDIR/other" "$repo/.sdlc/demo/work/../../demo/review"; do
  bash "$clean" "$bad" >/dev/null 2>&1 && fail "accepted $bad"
  [ -e "$bad" ] || fail "deleted $bad"
done
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

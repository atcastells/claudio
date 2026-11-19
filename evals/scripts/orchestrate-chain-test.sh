#!/bin/bash
# Scenarios for Orchestrate 3.5.0 in hooks/mode.sh and hooks/test-guard.sh:
#   chain       /orchestrate <chain dir> records the active chain; a bad dir does not
#   allow-test  /orchestrate allow-test <file> lets test-guard pass that file only,
#               for 30 minutes, also through bash-file-check's payload
#   model       /orchestrate notes when the main session already runs Opus
#   usage: orchestrate-chain-test.sh <hooks-dir> chain|allow-test|model
set -uo pipefail
hooks="$1"; c="$2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
prompt() { # prompt <text> [transcript]
  OUT=$(jq -nc --arg p "$1" --arg t "${2:-}" '{hook_event_name:"UserPromptSubmit", session_id:"s1", prompt:$p, transcript_path:$t}' \
    | bash "$hooks/mode.sh" 2>/dev/null)
}
chain="$tmp/repo-b/.sdlc/k1"; mkdir -p "$chain"; : > "$chain/plan.md"
pchain=$(cd "$chain" && pwd -P)

case "$c" in
  chain)
    prompt "/orchestrate $chain"
    [ -e "$tmp/claudio-orch-s1" ] || fail "marker not created"
    [ "$(head -n 1 "$tmp/claudio-orch-s1" 2>/dev/null)" = "$pchain" ] || fail "chain not recorded"
    case "$OUT" in *"Active chain: $pchain"*) ;; *) fail "notice lacks the chain: $OUT" ;; esac
    prompt "/orchestrate $tmp/repo-b"
    [ -s "$tmp/claudio-orch-s1" ] && fail "a dir that is not a chain was recorded"
    case "$OUT" in *"No active chain"*) ;; *) fail "no notice for a bad chain: $OUT" ;; esac
    prompt "/orchestrate on"
    case "$OUT" in *"No active chain"*) fail "/orchestrate on read as a path" ;; esac
    prompt "/orchestrate off"
    [ -e "$tmp/claudio-orch-s1" ] && fail "off left the marker"
    ;;
  allow-test)
    edit() { # edit <file> [session]
      jq -nc --arg f "$1" --arg s "${2:-s1}" '{session_id:$s, tool_name:"Edit",
        tool_input:{file_path:$f, old_string:"expect(a).toBe(1)\nexpect(b).toBe(2)", new_string:"expect(a).toBe(1)"}}' \
        | bash "$hooks/test-guard.sh" >/dev/null 2>&1
    }
    edit /r/tests/regen.test.ts && fail "weakening passed before any approval"
    prompt "/orchestrate allow-test tests/regen.test.ts"
    case "$OUT" in *"allows weakening"*) ;; *) fail "no notice: $OUT" ;; esac
    edit /r/tests/regen.test.ts || fail "approved file still blocked"
    edit /r/tests/other.test.ts && fail "another file passed"
    edit /r/tests/regen.test.ts s2 && fail "another session passed"
    printf '%s tests/old.test.ts\n' "$(( $(date +%s) - 3600 ))" >> "$tmp/claudio-allow-s1"
    edit /r/tests/old.test.ts && fail "an approval older than 30 minutes passed"
    prompt "/orchestrate allow-test ../../etc/x"
    grep -q 'etc/x' "$tmp/claudio-allow-s1" && fail "a path with .. was recorded"
    jq -nc '{hook_event_name:"SessionStart", session_id:"s1", source:"startup"}' | bash "$hooks/mode.sh" >/dev/null 2>&1
    [ -e "$tmp/claudio-allow-s1" ] && fail "startup kept the allow list"
    grep -q 'session_id:\$sid' "$hooks/bash-file-check.sh" || fail "bash-file-check does not pass session_id to the guards"
    ;;
  model)
    tr="$tmp/t.jsonl"
    jq -nc '{type:"assistant", message:{model:"claude-opus-5-5"}}' > "$tr"
    prompt "/orchestrate" "$tr"
    case "$OUT" in *"integrator's model"*) ;; *) fail "no note on Opus: $OUT" ;; esac
    jq -nc '{type:"assistant", message:{model:"claude-fable-5-2"}}' > "$tr"
    prompt "/orchestrate off"; prompt "/orchestrate" "$tr"
    case "$OUT" in *"integrator's model"*) fail "note on Fable" ;; esac
    grep -q "Fable 5.2 chosen at session start" "$hooks/mode.sh" && fail "notice still assumes Fable"
    ;;
esac
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1

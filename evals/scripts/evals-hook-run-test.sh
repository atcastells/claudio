#!/bin/bash
# Test for hooks/evals-on-config-change.sh: usage <path-to-hook> [mode]
# modes: report
hook="${1:?usage: evals-hook-run-test.sh <hook> [mode]}"
mode="${2:-report}"

unset CLAUDE_EVALS_RUNNING CLAUDE_PROJECT_DIR EVALS_SKIP_REPO WORKFLOW_PROFILE

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

repo="$tmp/repo"
mkdir -p "$repo/hooks" "$repo/evals" "$tmp/home"
(cd "$repo" && git init -q) || fail "git init"
top=$(cd "$repo" && git rev-parse --show-toplevel)
printf '%s' "$top" > "$tmp/home/source"
echo '#!/bin/bash' > "$repo/hooks/x.sh"
echo 'x' > "$repo/README.md"

payload_hook=$(jq -n --arg p "$top/hooks/x.sh" '{tool_input:{file_path:$p}}')
payload_other=$(jq -n --arg p "$tmp/elsewhere.txt" '{tool_input:{file_path:$p}}')

run_hook() { # $1 payload; sets code, out, err
  WORKFLOW_HOME="$tmp/home" HOME="$tmp/fakehome" bash "$hook" <<<"$1" >"$tmp/out" 2>"$tmp/err"
  code=$?
}

closing="a control that is not verified is not a control."

case "$mode" in
  report)
    # red suite: 60 FAIL lines
    cat > "$repo/evals/run.sh" <<'EOF'
#!/bin/bash
echo "ran" >> "$(dirname "$0")/ran.log"
for i in $(seq 1 60); do echo "case $i   FAIL (exit=1)"; done
echo "PASS: 0   FAIL: 60"
exit 1
EOF
    run_hook "$payload_hook"
    [ "$code" -eq 2 ] || fail "red: expected exit 2, got $code"
    head -n1 "$tmp/err" | grep -qx "EVALS RED after modifying x.sh." || fail "red: header missing: $(head -n1 "$tmp/err")"
    n=$(grep -c 'FAIL (exit=1)' "$tmp/err")
    [ "$n" -eq 40 ] || fail "red: expected 40 FAIL lines, got $n"
    grep -q 'case 1   FAIL' "$tmp/err" || fail "red: first FAIL line missing"
    grep -q 'case 41   FAIL' "$tmp/err" && fail "red: more than 40 lines kept"
    grep -qx "PASS: 0   FAIL: 60" "$tmp/err" || fail "red: PASS summary line missing"
    grep -q "$closing" "$tmp/err" || fail "red: closing sentence missing"
    [ ! -s "$tmp/out" ] || fail "red: stdout not empty"

    # a passing case whose name contains FAIL is not reported as a failure
    cat > "$repo/evals/run.sh" <<'EOF'
#!/bin/bash
echo "check.sh: a FAIL line in the name                         PASS"
echo "real case                                                 FAIL (exit=1, expected=0)"
echo "PASS: 1   FAIL: 1"
exit 1
EOF
    run_hook "$payload_hook"
    [ "$code" -eq 2 ] || fail "status column: expected exit 2, got $code"
    grep -q 'a FAIL line in the name' "$tmp/err" && fail "status column: a passing case was reported"
    grep -q 'real case' "$tmp/err" || fail "status column: the failing case is missing"

    # green suite: silent
    cat > "$repo/evals/run.sh" <<'EOF'
#!/bin/bash
echo "PASS: 5   FAIL: 0"
exit 0
EOF
    run_hook "$payload_hook"
    [ "$code" -eq 0 ] || fail "green: expected exit 0, got $code"
    [ ! -s "$tmp/out" ] || fail "green: stdout not empty"
    [ ! -s "$tmp/err" ] || fail "green: stderr not empty: $(cat "$tmp/err")"

    # non-config file: suite never runs
    rm -f "$repo/evals/ran.log"
    cat > "$repo/evals/run.sh" <<'EOF'
#!/bin/bash
echo "ran" >> "$(dirname "$0")/ran.log"
exit 1
EOF
    run_hook "$payload_other"
    [ "$code" -eq 0 ] || fail "other: expected exit 0, got $code"
    [ ! -e "$repo/evals/ran.log" ] || fail "other: suite ran for a non-config file"
    ;;
  coalesce)
    export TMPDIR="$tmp/tmpd"
    mkdir -p "$TMPDIR"
    suite="$top/evals/run.sh"
    key=$(printf '%s' "$suite" | cksum | cut -d' ' -f1)
    lock="$tmp/home/locks/$key"
    log="$repo/evals/runs.log"
    cat > "$suite" <<'EOF'
#!/bin/bash
sleep 2
echo "run" >> "$(dirname "$0")/runs.log"
n=$(wc -l < "$(dirname "$0")/runs.log" | tr -d ' ')
if [ "${STUB_EXIT:-0}" -ne 0 ]; then
  echo "case run$n   FAIL (exit=1)"
  echo "PASS: 0   FAIL: 1"
fi
exit "${STUB_EXIT:-0}"
EOF
    runs() { [ -f "$log" ] && wc -l < "$log" | tr -d ' ' || echo 0; }
    now() { perl -MTime::HiRes=time -e 'printf "%.3f", time'; }
    bg_hook() { # $1 payload, $2 tag; background run, exit code in $tmp/code.$2
      ( WORKFLOW_HOME="$tmp/home" HOME="$tmp/fakehome" bash "$hook" <<<"$1" >"$tmp/out.$2" 2>"$tmp/err.$2"; echo $? > "$tmp/code.$2" ) &
    }

    # (1) second invocation during a run returns fast and silent; 2 runs in total
    rm -f "$log"
    bg_hook "$payload_hook" a
    sleep 0.3
    t0=$(now)
    run_hook "$payload_hook"
    t1=$(now)
    [ "$code" -eq 0 ] || fail "coalesce: second invocation exit $code"
    [ ! -s "$tmp/out" ] && [ ! -s "$tmp/err" ] || fail "coalesce: second invocation not silent"
    perl -e 'exit(($ARGV[1]-$ARGV[0]) < 1 ? 0 : 1)' "$t0" "$t1" || fail "coalesce: second invocation took >= 1s"
    wait
    [ "$(cat "$tmp/code.a")" -eq 0 ] || fail "coalesce: first invocation exit $(cat "$tmp/code.a")"
    [ "$(runs)" -eq 2 ] || fail "coalesce(1): expected 2 runs, got $(runs)"
    [ ! -e "$lock" ] || fail "coalesce(1): lock left behind"

    # (2) three invocations during one run -> 2 runs
    rm -f "$log"
    bg_hook "$payload_hook" a
    sleep 0.3
    bg_hook "$payload_hook" b
    sleep 0.3
    bg_hook "$payload_hook" c
    wait
    [ "$(runs)" -eq 2 ] || fail "coalesce(2): expected 2 runs, got $(runs)"
    [ ! -e "$lock" ] || fail "coalesce(2): lock left behind"

    # (3) stale lock with a dead pid is taken over
    rm -f "$log"
    sh -c 'exit 0' & deadpid=$!
    wait "$deadpid"
    mkdir -p "$(dirname "$lock")"; mkdir "$lock"
    printf '%s' "$deadpid" > "$lock/pid"
    run_hook "$payload_hook"
    [ "$code" -eq 0 ] || fail "coalesce(3): exit $code"
    [ "$(runs)" -eq 1 ] || fail "coalesce(3): expected 1 run, got $(runs)"
    # (4) lock gone after the run
    [ ! -e "$lock" ] || fail "coalesce(4): lock left behind after takeover"

    # (5) symlink at the lock path: no run, target untouched
    rm -f "$log"
    mkdir "$tmp/target"
    echo keep > "$tmp/target/marker"
    mkdir -p "$(dirname "$lock")"; ln -s "$tmp/target" "$lock"
    run_hook "$payload_hook"
    [ "$code" -eq 0 ] || fail "coalesce(5): exit $code"
    [ "$(runs)" -eq 0 ] || fail "coalesce(5): suite ran through a symlink"
    [ "$(ls "$tmp/target")" = "marker" ] || fail "coalesce(5): symlink target modified"
    [ -L "$lock" ] || fail "coalesce(5): symlink removed"
    rm -f "$lock"

    # (6) red: report comes from the last run only
    rm -f "$log"
    export STUB_EXIT=1
    bg_hook "$payload_hook" a
    sleep 0.3
    run_hook "$payload_hook"
    wait
    unset STUB_EXIT
    [ "$(cat "$tmp/code.a")" -eq 2 ] || fail "coalesce(6): expected exit 2, got $(cat "$tmp/code.a")"
    [ "$(runs)" -eq 2 ] || fail "coalesce(6): expected 2 runs, got $(runs)"
    head -n1 "$tmp/err.a" | grep -qx "EVALS RED after modifying x.sh." || fail "coalesce(6): header missing"
    grep -q 'case run2   FAIL' "$tmp/err.a" || fail "coalesce(6): last run FAIL line missing"
    grep -q 'case run1   FAIL' "$tmp/err.a" && fail "coalesce(6): first run reported"
    [ ! -e "$lock" ] || fail "coalesce(6): lock left behind"

    # (7) the lock lives in WORKFLOW_HOME/locks, mode 700, never in TMPDIR
    rm -f "$log"
    run_hook "$payload_hook"
    [ -d "$tmp/home/locks" ] || fail "coalesce(7): no locks dir in WORKFLOW_HOME"
    perm=$(stat -f %Lp "$tmp/home/locks" 2>/dev/null || stat -c %a "$tmp/home/locks")
    [ "$perm" = 700 ] || fail "coalesce(7): locks dir mode $perm, want 700"
    [ -z "$(ls -A "$TMPDIR")" ] || fail "coalesce(7): something written to TMPDIR"

    # (8) a stale lock whose pid file is a symlink: nothing written through it
    rm -f "$log"
    mkdir -p "$lock"
    echo keep > "$tmp/pidtarget"
    ln -s "$tmp/pidtarget" "$lock/pid"
    run_hook "$payload_hook"
    [ "$(cat "$tmp/pidtarget")" = keep ] || fail "coalesce(8): wrote through the pid symlink"
    rm -rf "$lock"

    # (9) a locks dir left group/world-writable is tightened to 700
    chmod 777 "$tmp/home/locks"
    rm -f "$log"
    run_hook "$payload_hook"
    perm=$(stat -f %Lp "$tmp/home/locks" 2>/dev/null || stat -c %a "$tmp/home/locks")
    [ "$perm" = 700 ] || fail "coalesce(9): locks dir mode $perm after run, want 700"
    [ "$(runs)" -eq 1 ] || fail "coalesce(9): expected 1 run, got $(runs)"
    ;;
  robust)
    export TMPDIR="$tmp/tmpd"
    mkdir -p "$TMPDIR"
    suite="$top/evals/run.sh"
    key=$(printf '%s' "$suite" | cksum | cut -d' ' -f1)
    locks="$tmp/home/locks"
    lock="$locks/$key"
    log="$repo/evals/runs.log"
    cat > "$suite" <<'EOF'
#!/bin/bash
d=$(dirname "$0")
echo $$ > "$d/stub.pid"
echo "run" >> "$d/runs.log"
[ -n "${STUB_EXEC_SLEEP:-}" ] && exec sleep "$STUB_EXEC_SLEEP"
[ -n "${STUB_SLEEP:-}" ] && sleep "$STUB_SLEEP"
if [ -n "${STUB_CRASH:-}" ]; then echo "jq: command not found" >&2; exit 127; fi
[ -n "${STUB_TOUCH_PENDING:-}" ] && touch "$STUB_TOUCH_PENDING/pending"
n=$(wc -l < "$d/runs.log" | tr -d ' ')
if [ "${STUB_EXIT:-0}" -ne 0 ]; then
  echo "case run$n   FAIL (exit=1)"
  echo "PASS: 0   FAIL: 1"
fi
exit "${STUB_EXIT:-0}"
EOF
    runs() { [ -f "$log" ] && wc -l < "$log" | tr -d ' ' || echo 0; }
    now() { perl -MTime::HiRes=time -e 'printf "%.3f", time'; }
    age_file() { perl -e '$t = time - $ARGV[0]; utime $t, $t, $ARGV[1]' "$1" "$2"; }
    bgpids=""
    cleanup_bg() { for p in $bgpids; do kill "$p" 2>/dev/null; done; }
    trap 'cleanup_bg; rm -rf "$tmp"' EXIT
    fakehook="$tmp/evals-on-config-change-fake.sh"
    printf '#!/bin/bash\nwhile :; do sleep 1; done\n' > "$fakehook"

    # (1a) the pid of a live unrelated process does not hold the lock
    rm -f "$log"
    sleep 30 & other=$!; bgpids="$bgpids $other"
    mkdir -p "$locks"; chmod 700 "$locks"; mkdir "$lock"
    printf '%s' "$other" > "$lock/pid"
    run_hook "$payload_hook"
    kill "$other" 2>/dev/null
    [ "$code" -eq 0 ] || fail "robust(1a): exit $code"
    [ "$(runs)" -eq 1 ] || fail "robust(1a): unrelated live pid held the lock, runs=$(runs)"
    [ ! -e "$lock" ] || fail "robust(1a): lock left behind"

    # (1b) a fresh lock with a live hook-like pid is live: pending, no run
    rm -f "$log"
    bash "$fakehook" & fake=$!; bgpids="$bgpids $fake"
    sleep 0.3
    mkdir "$lock"; printf '%s' "$fake" > "$lock/pid"
    run_hook "$payload_hook"
    [ "$code" -eq 0 ] || fail "robust(1b): exit $code"
    [ "$(runs)" -eq 0 ] || fail "robust(1b): live holder ignored, runs=$(runs)"
    [ -e "$lock/pending" ] || fail "robust(1b): pending not set"

    # (1c) the same lock with a pid file 12 min old is stale
    rm -f "$lock/pending"
    age_file 720 "$lock/pid"
    run_hook "$payload_hook"
    [ "$code" -eq 0 ] || fail "robust(1c): exit $code"
    [ "$(runs)" -eq 1 ] || fail "robust(1c): old pid file still held the lock, runs=$(runs)"
    kill "$fake" 2>/dev/null
    [ ! -e "$lock" ] || fail "robust(1c): lock left behind"

    # (1d) a pid-less lock dir just created is live; aged 10 s it is taken over
    rm -f "$log"
    mkdir "$lock"
    run_hook "$payload_hook"
    [ "$code" -eq 0 ] || fail "robust(1d): exit $code"
    [ "$(runs)" -eq 0 ] || fail "robust(1d): fresh pid-less lock ignored, runs=$(runs)"
    age_file 10 "$lock"
    run_hook "$payload_hook"
    [ "$(runs)" -eq 1 ] || fail "robust(1d): aged pid-less lock not taken over, runs=$(runs)"
    [ ! -e "$lock" ] || fail "robust(1d): lock left behind"

    # (2) after a takeover the pid file holds the new pid
    rm -f "$log"
    sh -c 'exit 0' & deadpid=$!
    wait "$deadpid"
    mkdir "$lock"; printf '%s' "$deadpid" > "$lock/pid"
    export STUB_SLEEP=2
    WORKFLOW_HOME="$tmp/home" HOME="$tmp/fakehome" bash "$hook" <<<"$payload_hook" >"$tmp/out.a" 2>"$tmp/err.a" &
    hp=$!; bgpids="$bgpids $hp"
    sleep 0.8
    [ "$(cat "$lock/pid" 2>/dev/null)" = "$hp" ] || fail "robust(2): pid file is '$(cat "$lock/pid" 2>/dev/null)', want $hp"
    wait "$hp"
    unset STUB_SLEEP

    # (3) an invocation in the release window still causes a second run
    rm -f "$log"
    export STUB_SLEEP=1
    EVALS_HOOK_TEST_PAUSE=1.5 WORKFLOW_HOME="$tmp/home" HOME="$tmp/fakehome" bash "$hook" <<<"$payload_hook" >"$tmp/out.a" 2>"$tmp/err.a" &
    hp=$!; bgpids="$bgpids $hp"
    sleep 1.7
    run_hook "$payload_hook"
    [ "$code" -eq 0 ] || fail "robust(3): window invocation exit $code"
    wait "$hp"
    unset STUB_SLEEP
    [ "$(runs)" -eq 2 ] || fail "robust(3): expected 2 runs, got $(runs)"
    [ ! -e "$lock" ] || fail "robust(3): lock left behind"
    ls "$locks" | grep -q released && fail "robust(3): released dir left behind"

    # (4) TERM stops the suite and releases the lock
    rm -f "$log" "$repo/evals/stub.pid"
    export STUB_EXEC_SLEEP=5
    WORKFLOW_HOME="$tmp/home" HOME="$tmp/fakehome" bash "$hook" <<<"$payload_hook" >"$tmp/out.a" 2>"$tmp/err.a" &
    hp=$!; bgpids="$bgpids $hp"
    sleep 0.8
    stubpid=$(cat "$repo/evals/stub.pid" 2>/dev/null)
    t0=$(now)
    kill -TERM "$hp"
    wait "$hp"
    t1=$(now)
    unset STUB_EXEC_SLEEP
    perl -e 'exit(($ARGV[1]-$ARGV[0]) < 1 ? 0 : 1)' "$t0" "$t1" || fail "robust(4): hook took >= 1s to exit after TERM"
    [ -n "$stubpid" ] || fail "robust(4): stub never started"
    sleep 0.2
    kill -0 "$stubpid" 2>/dev/null && { kill "$stubpid" 2>/dev/null; fail "robust(4): stub still running"; }
    [ ! -e "$lock" ] || fail "robust(4): lock left behind"

    # (5) a crash with no summary reports the exit code and the last lines
    rm -f "$log"
    export STUB_CRASH=1
    run_hook "$payload_hook"
    unset STUB_CRASH
    [ "$code" -eq 2 ] || fail "robust(5): expected exit 2, got $code"
    grep -q 'exited 127' "$tmp/err" || fail "robust(5): exit code missing: $(cat "$tmp/err")"
    grep -q 'jq: command not found' "$tmp/err" || fail "robust(5): diagnostic line missing"

    # (6) an unusable locks dir runs the suite without a lock
    rm -f "$log"
    rm -rf "$locks"; echo x > "$locks"
    export STUB_EXIT=1
    run_hook "$payload_hook"
    unset STUB_EXIT
    [ "$code" -eq 2 ] || fail "robust(6): expected exit 2, got $code"
    [ "$(runs)" -eq 1 ] || fail "robust(6): expected 1 run, got $(runs)"
    rm -f "$locks"

    # (7) edits after the third run: red says so, green stays silent
    rm -f "$log"
    export STUB_TOUCH_PENDING="$lock" STUB_EXIT=1
    run_hook "$payload_hook"
    [ "$code" -eq 2 ] || fail "robust(7): expected exit 2, got $code"
    [ "$(runs)" -eq 3 ] || fail "robust(7): expected 3 runs, got $(runs)"
    grep -qx "Edits after the third run are not covered: edit again to rerun." "$tmp/err" || fail "robust(7): cap line missing"
    [ ! -e "$lock" ] || fail "robust(7): lock left behind"
    rm -f "$log"
    export STUB_EXIT=0
    run_hook "$payload_hook"
    unset STUB_TOUCH_PENDING STUB_EXIT
    [ "$code" -eq 0 ] || fail "robust(7): green exit $code"
    [ ! -s "$tmp/err" ] || fail "robust(7): green not silent: $(cat "$tmp/err")"
    [ "$(runs)" -eq 3 ] || fail "robust(7): green expected 3 runs, got $(runs)"
    ;;
  *) fail "unknown mode: $mode" ;;
esac

echo "all passed"

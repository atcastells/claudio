#!/bin/bash
# Scenarios for hooks/bash-file-check.sh, one mode per argument: quiet (default:
# marker and changed-file listing), guards, dispatch (task-actuals; the evals
# hook never runs), limits, gitsafe, failure (event, marker symlink, names, id).
# Usage: bash-file-check-test.sh <path-to-hook> [mode]
# Prints "all passed" and exits 0 when every scenario behaves.

hook="$1"
[ -n "$hook" ] || { echo "usage: $0 <path-to-hook>" >&2; exit 2; }
case "$hook" in /*) ;; *) hook="$PWD/$hook" ;; esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work/tmp"
mkdir -p "$TMPDIR"

fail=0
check() { # name, condition result (0 = ok)
  if [ "$2" -ne 0 ]; then echo "FAIL: $1" >&2; fail=1; fi
}

repo="$work/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.invalid
git -C "$repo" config user.name t
printf 'ignored.txt\n' >"$repo/.gitignore"
printf 'one\n' >"$repo/tracked.txt"
printf 'old\n' >"$repo/aged.txt"
git -C "$repo" add -A
git -C "$repo" commit -q -m init

pre() { # id, cwd
  jq -n --arg id "$1" --arg cwd "$2" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_use_id:$id,cwd:$cwd,tool_input:{command:"x"}}' |
    bash "$hook"
}
post() { # id, cwd
  jq -n --arg id "$1" --arg cwd "$2" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_use_id:$id,cwd:$cwd,tool_input:{command:"x"}}' |
    bash "$hook"
}

if [ "${2:-quiet}" = dispatch ]; then
  # Dispatch scenarios: changed plan.md rows reach task-actuals; evals-on-config-change never runs.
  unset CLAUDE_EVALS_RUNNING
  export CLAUDE_SDLC_ACTUALS="$work/machine.jsonl"
  export WORKFLOW_HOME="$work/nohome"
  printf '{"type":"assistant","timestamp":"2026-10-20T10:01:00.000Z","message":{"id":"m1","model":"model-main","usage":{"input_tokens":1,"output_tokens":1}}}\n' >"$work/transcript.jsonl"

  postx() { # id, cwd
    jq -n --arg id "$1" --arg cwd "$2" --arg t "$work/transcript.jsonl" \
      '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_use_id:$id,cwd:$cwd,session_id:"s1",transcript_path:$t,tool_input:{command:"x"}}' |
      bash "$hook"
  }
  mkrepo() { # name -> creates $work/<name>, sets $r (resolved toplevel)
    mkdir -p "$work/$1"
    git -C "$work/$1" init -q
    git -C "$work/$1" config user.email t@example.invalid
    git -C "$work/$1" config user.name t
    r=$(cd "$work/$1" && git rev-parse --show-toplevel)
  }
  setrow() { # file, from, to
    sed "s/| $2 |\$/| $3 |/" "$1" >"$1.tmp" && cat "$1.tmp" >"$1" && rm -f "$1.tmp"
  }

  # 1. plan.md main row: start line, then closing line
  mkrepo d1
  mkdir -p "$r/.sdlc/x"
  printf '# Plan\n\n| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |\n|---|---|---|---|---|---|---|---|---|\n| T1 | One | a | t | R1 | main | - | 5m/400k | pending |\n' >"$r/.sdlc/x/plan.md"
  git -C "$r" add -A
  git -C "$r" commit -q -m init
  log="$r/.sdlc/x/actuals.jsonl"
  pre d1a "$r"; sleep 1
  setrow "$r/.sdlc/x/plan.md" pending 'in progress'
  postx d1a "$r" >/dev/null 2>&1; rc=$?
  check "plan start: exit 0 (got $rc)" "$rc"
  check "plan start: start line written" "$(jq -e '.task=="T1" and .event=="start"' "$log" >/dev/null 2>&1; echo $?)"
  pre d1b "$r"; sleep 1
  setrow "$r/.sdlc/x/plan.md" 'in progress' 'done (cause: none)'
  postx d1b "$r" >/dev/null 2>&1; rc=$?
  check "plan done: exit 0 (got $rc)" "$rc"
  check "plan done: closing line on main" "$(tail -n 1 "$log" | jq -e '.task=="T1" and .runs_on=="main"' >/dev/null 2>&1; echo $?)"

  # 2. the evals hook never runs: a copy of the hook dir holds a stub that
  # would block (exit 2) and log; a config-like change must leave it untouched
  hookdir="$work/d2-hooks"
  mkdir -p "$hookdir"
  cp "$hook" "$hookdir/bash-file-check.sh"
  for g in credential-guard test-guard task-actuals; do
    [ -f "$(dirname "$hook")/$g.sh" ] && cp "$(dirname "$hook")/$g.sh" "$hookdir/$g.sh"
  done
  [ -d "$(dirname "$hook")/lib" ] && cp -R "$(dirname "$hook")/lib" "$hookdir/lib"
  stub="$work/d2-stub-log"; : >"$stub"
  printf '#!/bin/bash\necho ran >>"%s"\nexit 2\n' "$stub" >"$hookdir/evals-on-config-change.sh"
  mkrepo d2
  mkdir -p "$r/hooks" "$r/evals" "$work/d2-home"
  printf '%s' "$r" >"$work/d2-home/source"
  printf '#!/bin/bash\nexit 1\n' >"$r/evals/run.sh"
  printf 'echo a\n' >"$r/hooks/a.sh"
  git -C "$r" add -A
  git -C "$r" commit -q -m init
  export WORKFLOW_HOME="$work/d2-home"
  realhook="$hook"; hook="$hookdir/bash-file-check.sh"
  pre d2a "$r"; sleep 1
  printf 'echo b\n' >>"$r/hooks/a.sh"; printf 'echo c\n' >"$r/hooks/b.sh"
  out=$(postx d2a "$r" 2>&1 >/dev/null); rc=$?
  check "config change: exit 0 (got $rc)" "$rc"
  check "config change: evals stub never ran" "$([ ! -s "$stub" ]; echo $?)"

  # 3. neither plan nor config: nothing dispatched
  mkrepo d4
  printf 'x\n' >"$r/seed.txt"; git -C "$r" add -A; git -C "$r" commit -q -m init
  pre d4a "$r"; sleep 1
  printf 'hello\n' >"$r/notes.txt"
  out=$(postx d4a "$r" 2>&1 >/dev/null); rc=$?
  check "plain file: exit 0 (got $rc)" "$rc"
  check "plain file: evals stub never ran" "$([ ! -s "$stub" ]; echo $?)"
  check "plain file: no actuals" "$([ ! -e "$r/.sdlc" ]; echo $?)"
  hook="$realhook"

  [ "$fail" -eq 0 ] && { echo "all passed"; exit 0; }
  exit 1
fi

if [ "${2:-quiet}" = failure ]; then
  # Failure-event scenarios: PostToolUseFailure, marker symlink, hostile names, bad id.
  cred="squ_$(printf 'c0ffee12%.0s' 1 2 3 4 5)"
  mkr() { # name -> sets $r
    mkdir -p "$work/$1"
    git -C "$work/$1" init -q
    git -C "$work/$1" config user.email t@example.invalid
    git -C "$work/$1" config user.name t
    printf 'seed\n' >"$work/$1/seed.txt"
    git -C "$work/$1" add -A; git -C "$work/$1" commit -q -m init
    r=$(cd "$work/$1" && pwd -P)
  }
  mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }

  # 1. write then non-zero exit: PostToolUseFailure is checked like PostToolUse
  mkr f1
  pre f1a "$r"; sleep 1
  printf 'key=%s\n' "$cred" >"$r/new.txt"
  out=$(jq -n --arg id f1a --arg cwd "$r" \
    '{hook_event_name:"PostToolUseFailure",tool_name:"Bash",tool_use_id:$id,cwd:$cwd,tool_input:{command:"x"},error:"Exit code 1"}' |
    bash "$hook" 2>&1 >/dev/null); rc=$?
  check "failure event: exit 2 (got $rc)" "$([ "$rc" -eq 2 ]; echo $?)"
  check "failure event: names file and guard" "$(printf '%s' "$out" | grep -q 'new.txt.*credential-guard'; echo $?)"
  check "failure event: never prints the value" "$(printf '%s' "$out" | grep -qF "$cred"; [ $? -ne 0 ]; echo $?)"
  check "failure event: marker removed" "$([ ! -e "$TMPDIR/claudio-bash-f1a" ]; echo $?)"

  # 1b. only skipped files on a failure event: the context names that event
  mkr f1b
  pre f1b "$r"; sleep 1
  for i in $(seq -w 1 51); do printf 'plain %s\n' "$i" >"$r/p$i.txt"; done
  out=$(jq -n --arg id f1b --arg cwd "$r" \
    '{hook_event_name:"PostToolUseFailure",tool_name:"Bash",tool_use_id:$id,cwd:$cwd,tool_input:{command:"x"},error:"Exit code 1"}' |
    bash "$hook" 2>/dev/null); rc=$?
  check "failure skip: exit 0 (got $rc)" "$([ "$rc" -eq 0 ]; echo $?)"
  check "failure skip: context names PostToolUseFailure" "$(printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName=="PostToolUseFailure"' >/dev/null 2>&1; echo $?)"

  # 2. a symlink planted at the marker path is not followed by touch
  mkr f2
  echo victim >"$work/victim.txt"
  touch -t 202001010000 "$work/victim.txt"
  before=$(mtime "$work/victim.txt")
  ln -s "$work/victim.txt" "$TMPDIR/claudio-bash-f2a"
  pre f2a "$r"
  after=$(mtime "$work/victim.txt")
  check "marker symlink: target mtime unchanged ($before vs $after)" "$([ "$before" = "$after" ]; echo $?)"
  check "marker symlink: marker is a regular file" "$([ -f "$TMPDIR/claudio-bash-f2a" ] && [ ! -L "$TMPDIR/claudio-bash-f2a" ]; echo $?)"

  # 3. a name with ESC and LF is printed with ? in their place
  mkr f3
  pre f3a "$r"; sleep 1
  nm=$(printf 'a\033b\nc.txt')
  printf 'key=%s\n' "$cred" >"$r/$nm"
  post f3a "$r" 2>"$work/f3err" >/dev/null; rc=$?
  err=$(cat "$work/f3err")
  check "hostile name: exit 2 (got $rc)" "$([ "$rc" -eq 2 ]; echo $?)"
  check "hostile name: ? in place of ESC and LF" "$(printf '%s' "$err" | grep -qF 'a?b?c.txt'; echo $?)"
  check "hostile name: no raw ESC in stderr" "$(LC_ALL=C grep -q "$(printf '\033')" "$work/f3err"; [ $? -ne 0 ]; echo $?)"

  # 4. an id with a newline is rejected: no marker
  mkr f4
  before=$(ls -A "$TMPDIR" | wc -l)
  pre "$(printf 'a\nb')" "$r"; rc=$?
  after=$(ls -A "$TMPDIR" | wc -l)
  check "newline id: exit 0 (got $rc)" "$rc"
  check "newline id: no marker created" "$([ "$before" -eq "$after" ]; echo $?)"

  [ "$fail" -eq 0 ] && { echo "all passed"; exit 0; }
  exit 1
fi

if [ "${2:-quiet}" = guards ]; then
  # Guard scenarios: a tracked or new file changed with real shell, then checked.
  cred="squ_$(printf 'c0ffee12%.0s' 1 2 3 4 5)"
  n=0
  scenario() { # name, expected rc, stderr pattern ("" = none), setup-and-write command (run in repo)
    local name="$1" want="$2" pat="$3" cmd="$4" r id out rc
    n=$((n + 1)); id="g$n"; r="$work/g$n"
    mkdir -p "$r"
    git -C "$r" init -q
    git -C "$r" config user.email t@example.invalid
    git -C "$r" config user.name t
    (cd "$r" && eval "$SETUP")
    git -C "$r" add -A
    git -C "$r" commit -q -m init
    pre "$id" "$r"; sleep 1
    (cd "$r" && eval "$cmd")
    out=$(post "$id" "$r" 2>&1 >/dev/null); rc=$?
    check "$name: exit $want (got $rc)" "$([ "$rc" -eq "$want" ]; echo $?)"
    if [ -n "$pat" ]; then
      check "$name: stderr matches $pat" "$(printf '%s' "$out" | grep -q -e "$pat"; echo $?)"
      check "$name: names the file" "$(printf '%s' "$out" | grep -q 'already written'; echo $?)"
    fi
    check "$name: never prints the value" "$(printf '%s' "$out" | grep -qF "$cred"; [ $? -ne 0 ]; echo $?)"
  }

  SETUP='printf "one\n" >app.txt'
  scenario "credential added to tracked file" 2 "app.txt.*credential-guard" "printf 'key=$cred\n' >>app.txt"
  scenario "credential in new untracked file" 2 "new.txt.*credential-guard" "printf 'key=$cred\n' >new.txt"
  SETUP="printf 'key=$cred\n' >app.txt"
  scenario "credential already committed, unrelated line" 0 "" "printf 'more\n' >>app.txt"
  SETUP='printf "one\n" >app.txt'
  scenario "placeholder value" 0 "" "printf 'key=squ_example_value\n' >>app.txt"

  SETUP='printf "it(\"a\", () => {\n  expect(1).toBe(1);\n});\n" >foo.test.js'
  scenario "skip added in test file" 2 "foo.test.js.*test-guard" "sed 's/it(/it.skip(/' foo.test.js >foo.tmp && cat foo.tmp >foo.test.js && rm foo.tmp"
  scenario "assertion removed in test file" 2 "foo.test.js.*test-guard" "printf 'it(\"a\", () => {\n});\n' >foo.test.js"
  scenario "test commented out" 2 "foo.test.js.*test-guard" "printf '// it(\"a\", () => {\n//   expect(1).toBe(1);\n// });\n' >foo.test.js"
  scenario "assertion added in test file" 0 "" "printf 'it(\"b\", () => {\n  expect(2).toBe(2);\n});\n' >>foo.test.js"

  [ "$fail" -eq 0 ] && { echo "all passed"; exit 0; }
  exit 1
fi

if [ "${2:-quiet}" = limits ]; then
  # Limit scenarios: only 50 changed files per command and files up to 1 MB are checked.
  cred="squ_$(printf 'c0ffee12%.0s' 1 2 3 4 5)"
  n=0
  skipline='bash-file-check: skipped [0-9]* changed files (over 50 per command or over 1 MB); they were not checked.'
  limit_scenario() { # name, expected rc, pattern in stderr ("" = none), mode, command (run in a fresh repo)
    # mode: ctx = skip line as additionalContext on stdout; err = skip line in stderr; noskip = no skip line; silent = nothing at all
    local name="$1" want="$2" pat="$3" mode="$4" cmd="$5" r id out err rc
    n=$((n + 1)); id="l$n"; r="$work/l$n"
    mkdir -p "$r"
    git -C "$r" init -q
    git -C "$r" config user.email t@example.invalid
    git -C "$r" config user.name t
    printf 'seed\n' >"$r/seed.txt"
    git -C "$r" add -A
    git -C "$r" commit -q -m init
    pre "$id" "$r"; sleep 1
    (cd "$r" && eval "$cmd")
    out=$(post "$id" "$r" 2>"$work/err"); rc=$?
    err=$(cat "$work/err")
    check "$name: exit $want (got $rc)" "$([ "$rc" -eq "$want" ]; echo $?)"
    if [ -n "$pat" ]; then
      check "$name: stderr names $pat" "$(printf '%s' "$err" | grep -q -e "$pat"; echo $?)"
    fi
    case "$mode" in
      ctx)
        check "$name: stdout additionalContext has the skip line" "$(printf '%s' "$out" | jq -e --arg s "skipped 1 changed files (over 50 per command or over 1 MB); they were not checked." '.hookSpecificOutput.hookEventName=="PostToolUse" and (.hookSpecificOutput.additionalContext | contains($s))' >/dev/null 2>&1; echo $?)" ;;
      err)
        check "$name: stderr has the skip line" "$(printf '%s' "$err" | grep -q -e "$skipline"; echo $?)"
        check "$name: stdout empty" "$([ -z "$out" ]; echo $?)" ;;
      noskip)
        check "$name: no skip line" "$(printf '%s%s' "$out" "$err" | grep -q -e 'skipped'; [ $? -ne 0 ]; echo $?)" ;;
      silent)
        check "$name: stdout empty" "$([ -z "$out" ]; echo $?)"
        check "$name: stderr empty" "$([ -z "$err" ]; echo $?)" ;;
    esac
    check "$name: never prints the value" "$(printf '%s%s' "$out" "$err" | grep -qF "$cred"; [ $? -ne 0 ]; echo $?)"
  }
  mk() { # count, credential file number (0 = none)
    local i
    for i in $(seq -w 1 "$1"); do
      if [ "$((10#$i))" -eq "$2" ]; then printf 'key=%s\n' "$cred" >"f$i.txt"; else printf 'plain %s\n' "$i" >"f$i.txt"; fi
    done
  }

  limit_scenario "51st file has a credential" 0 "" ctx "mk 51 51"
  limit_scenario "2 MB file with a credential" 0 "" ctx "{ printf 'key=%s\n' '$cred'; head -c 2097152 /dev/zero | tr '\\0' 'a'; } >big.txt"
  limit_scenario "50 files, one with a credential" 2 "f07.txt" noskip "mk 50 7"
  limit_scenario "51 files, first has a credential" 2 "f01.txt" err "mk 51 1"
  limit_scenario "3 plain files" 0 "" silent "mk 3 0"

  [ "$fail" -eq 0 ] && { echo "all passed"; exit 0; }
  exit 1
fi

if [ "${2:-quiet}" = gitsafe ]; then
  # Git-safety scenarios: the hook never runs code planted in the repo's git
  # config, still reports credentials, and stays cheap on a dirty tree.
  cred="squ_$(printf 'c0ffee12%.0s' 1 2 3 4 5)"
  n=0
  gsrepo() { # -> sets $r (physical path) and $id
    n=$((n + 1)); id="s$n"; r="$work/s$n"
    mkdir -p "$r"
    git -C "$r" init -q
    git -C "$r" config user.email t@example.invalid
    git -C "$r" config user.name t
    r=$(cd "$r" && pwd -P)
  }
  printf '#!/bin/sh\ntouch "$PWNED"\nexit 0\n' >"$work/plain.sh"
  printf '#!/bin/sh\ntouch "$PWNED"\ncat\n' >"$work/filt.sh"
  printf '#!/bin/sh\ntouch "$PWNED"\ncat "$1"\n' >"$work/conv.sh"

  planted() { # kind (fsmonitor|clean|textconv|external)
    local kind="$1" out rc
    gsrepo
    export PWNED="$work/pwned-$kind"
    rm -f "$PWNED"
    printf 'one\n' >"$r/a.txt"
    printf '*.txt filter=x diff=x\n' >"$r/.gitattributes"
    git -C "$r" add -A
    git -C "$r" commit -q -m init
    case "$kind" in
      fsmonitor) git -C "$r" config core.fsmonitor "sh $work/plain.sh" ;;
      clean) git -C "$r" config filter.x.clean "sh $work/filt.sh" ;;
      textconv) git -C "$r" config diff.x.textconv "sh $work/conv.sh" ;;
      external) git -C "$r" config diff.external "sh $work/plain.sh" ;;
    esac
    pre "$id" "$r"; sleep 1
    printf 'key=%s\n' "$cred" >>"$r/a.txt"
    out=$(post "$id" "$r" 2>&1 >/dev/null); rc=$?
    check "$kind: planted code never ran" "$([ ! -e "$PWNED" ]; echo $?)"
    check "$kind: credential still reported (exit 2, got $rc)" "$([ "$rc" -eq 2 ]; echo $?)"
    check "$kind: names a.txt" "$(printf '%s' "$out" | grep -q 'a.txt.*credential-guard'; echo $?)"
    unset PWNED
  }
  planted fsmonitor
  planted clean
  planted textconv
  planted external

  # An added line that starts with ++ is still checked
  gsrepo
  printf 'one\n' >"$r/a.txt"
  git -C "$r" add -A; git -C "$r" commit -q -m init
  pre "$id" "$r"; sleep 1
  printf '++i; key=%s\n' "$cred" >>"$r/a.txt"
  out=$(post "$id" "$r" 2>&1 >/dev/null); rc=$?
  check "plus-plus line: exit 2 (got $rc)" "$([ "$rc" -eq 2 ]; echo $?)"

  # A tracked file with a NUL byte is still compared as text
  gsrepo
  printf 'one\n' >"$r/t.txt"
  git -C "$r" add -A; git -C "$r" commit -q -m init
  pre "$id" "$r"; sleep 1
  printf 'base\n\0\nk=%s\n' "$cred" >"$r/t.txt"
  out=$(post "$id" "$r" 2>&1 >/dev/null); rc=$?
  check "NUL in tracked file: exit 2 (got $rc)" "$([ "$rc" -eq 2 ]; echo $?)"

  # A promisor remote must not be fetched: its uploadpack would run repo code
  gsrepo
  export PWNED="$work/pwned-lazy"
  rm -f "$PWNED"
  printf 'one\n' >"$r/seed.txt"
  git -C "$r" add -A; git -C "$r" commit -q -m init
  tree=$(printf '100644 blob %s\tf.txt\n' 1111111111111111111111111111111111111111 | git -C "$r" mktree --missing)
  commit=$(git -C "$r" commit-tree "$tree" -m missing)
  git -C "$r" update-ref HEAD "$commit"
  git -C "$r" config core.repositoryformatversion 1
  git -C "$r" config extensions.partialClone origin
  git -C "$r" config remote.origin.url "$r/.git"
  git -C "$r" config remote.origin.promisor true
  git -C "$r" config remote.origin.uploadpack "sh $work/plain.sh; git-upload-pack"
  pre "$id" "$r"; sleep 1
  printf 'data\n' >"$r/f.txt"
  post "$id" "$r" >/dev/null 2>&1
  check "lazy fetch: planted uploadpack never ran" "$([ ! -e "$PWNED" ]; echo $?)"
  unset PWNED

  # A name with glob characters is not confused with its neighbour
  gsrepo
  mkdir -p "$r/app"
  printf 'one\n' >"$r/app/i.txt"; printf 'one\n' >"$r/app/[i].txt"
  git -C "$r" add -A; git -C "$r" commit -q -m init
  pre "$id" "$r"; sleep 1
  printf 'key=%s\n' "$cred" >>"$r/app/i.txt"
  out=$(post "$id" "$r" 2>&1 >/dev/null); rc=$?
  check "glob name: exit 2 (got $rc)" "$([ "$rc" -eq 2 ]; echo $?)"
  check "glob name: names app/i.txt" "$(printf '%s' "$out" | grep -qF 'app/i.txt'; echo $?)"
  check "glob name: not app/[i].txt" "$(printf '%s' "$out" | grep -qF 'app/[i].txt'; [ $? -ne 0 ]; echo $?)"

  # 3000 untracked files and no change: cheap
  gsrepo
  printf 'one\n' >"$r/a.txt"
  git -C "$r" add -A; git -C "$r" commit -q -m init
  for i in $(seq 1 3000); do : >"$r/u$i.txt"; done
  pre "$id" "$r"; sleep 1
  t0=$(perl -MTime::HiRes=time -e 'print time')
  out=$(post "$id" "$r" 2>&1); rc=$?
  t1=$(perl -MTime::HiRes=time -e 'print time')
  check "3000 untracked: exit 0 (got $rc)" "$rc"
  check "3000 untracked: under 1.5 s ($(perl -e "printf '%.2f', $t1 - $t0") s)" "$(perl -e "exit(($t1 - $t0) < 1.5 ? 0 : 1)"; echo $?)"

  # A credential left uncommitted before the command is reported again (E5 as amended)
  gsrepo
  printf 'one\n' >"$r/a.txt"
  git -C "$r" add -A; git -C "$r" commit -q -m init
  printf 'key=%s\n' "$cred" >>"$r/a.txt"
  pre "$id" "$r"; sleep 1
  printf 'more\n' >>"$r/a.txt"
  out=$(post "$id" "$r" 2>&1 >/dev/null); rc=$?
  check "old uncommitted credential: exit 2 (got $rc)" "$([ "$rc" -eq 2 ]; echo $?)"

  # cwd outside the resolved top level: nothing is read
  real="$work/real"; elsewhere="$work/elsewhere"; fake="$work/fake"
  mkdir -p "$real" "$elsewhere" "$fake"
  git -C "$elsewhere" init -q
  git -C "$real" init -q
  git -C "$real" config core.worktree "$elsewhere"
  printf 'gitdir: %s/.git\n' "$real" >"$fake/.git"
  pre outside "$fake"; sleep 1
  printf 'key=%s\n' "$cred" >"$elsewhere/leak.txt"
  out=$(post outside "$fake" 2>&1); rc=$?
  check "outside top level: exit 0 (got $rc)" "$rc"
  check "outside top level: no output" "$([ -z "$out" ]; echo $?)"

  [ "$fail" -eq 0 ] && { echo "all passed"; exit 0; }
  exit 1
fi

# 1. no change
pre t1 "$repo"; sleep 1
out=$(post t1 "$repo" 2>&1); rc=$?
check "no change: exit 0" "$rc"
check "no change: no output" "$([ -z "$out" ]; echo $?)"
check "marker removed after post" "$([ ! -e "$TMPDIR/claudio-bash-t1" ]; echo $?)"

# 2. non-git cwd
mkdir -p "$work/plain"
pre t2 "$work/plain"; sleep 1
echo hi >"$work/plain/f.txt"
out=$(post t2 "$work/plain" 2>&1); rc=$?
check "non-git: exit 0" "$rc"
check "non-git: no output" "$([ -z "$out" ]; echo $?)"

# 3. only ignored file changed
pre t3 "$repo"; sleep 1
echo x >"$repo/ignored.txt"
out=$(post t3 "$repo" 2>&1); rc=$?
check "ignored: exit 0" "$rc"
check "ignored: no output" "$([ -z "$out" ]; echo $?)"

# 4. missing marker
echo y >>"$repo/tracked.txt"
out=$(post nomarker "$repo" 2>&1); rc=$?
check "missing marker: exit 0" "$rc"
git -C "$repo" checkout -q -- tracked.txt

# 5. bad tool_use_id creates nothing
before=$(ls -A "$TMPDIR" | wc -l)
pre '../x' "$repo"; rc=$?
check "bad id: exit 0" "$rc"
after=$(ls -A "$TMPDIR" | wc -l)
check "bad id: nothing created in TMPDIR" "$([ "$before" -eq "$after" ]; echo $?)"
check "bad id: nothing created outside" "$([ ! -e "$work/claudio-bash-../x" ] && [ ! -e "$work/x" ]; echo $?)"

# 6. changed_files
touch -t 202001010000 "$repo/aged.txt"
echo untouched >"$repo/old-untouched.txt"
echo outside >"$work/moved-in.txt"
touch -t 202001010000 "$work/moved-in.txt"
marker="$work/marker"
sleep 1; touch "$marker"; sleep 1
echo more >>"$repo/tracked.txt"
echo new >"$repo/brand-new.txt"
echo sp >"$repo/with space.txt"
# Written during the command with a back-dated mtime: still a change
printf 'old\nmore-old\n' >"$repo/aged.txt"
touch -t 202001010000 "$repo/aged.txt"
# Created before the command, moved in during it (mv keeps the old mtime)
mv "$work/moved-in.txt" "$repo/moved-in.txt"
top=$(cd "$repo" && git rev-parse --show-toplevel)
list=$(
  # shellcheck disable=SC1090
  . "$hook"
  changed_files "$top" "$marker" | tr '\0' '\n'
)
has() { printf '%s\n' "$list" | grep -qxF "$top/$1"; }
check "changed_files: tracked edited" "$(has tracked.txt; echo $?)"
check "changed_files: untracked new" "$(has brand-new.txt; echo $?)"
check "changed_files: name with space" "$(has 'with space.txt'; echo $?)"
check "changed_files: back-dated write present" "$(has aged.txt; echo $?)"
check "changed_files: moved-in file present" "$(has moved-in.txt; echo $?)"
check "changed_files: file untouched since before the marker absent" "$(has old-untouched.txt; [ $? -ne 0 ]; echo $?)"
check "changed_files: ignored absent" "$(has ignored.txt; [ $? -ne 0 ]; echo $?)"

[ "$fail" -eq 0 ] && { echo "all passed"; exit 0; }
exit 1

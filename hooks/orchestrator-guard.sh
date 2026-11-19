#!/bin/bash
# orchestrator-guard: in Orchestrate mode the main session plans and decides; the
# integrator agent does the work. PreToolUse on Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Task|Read.
# Acts only when the session's orch marker exists.
# Main session (no agent_id), exit 2 = block. Allowed there:
#   - writes under a chain: .sdlc/<slug>/ of the repo that holds cwd (found by
#     walking up, so a cd into .sdlc/ does not matter), or an existing chain of
#     another repo (.sdlc/<slug>/ with intent, spec, plan or context.md). The
#     chain written becomes the session's active chain (lib/chain.sh);
#   - read-only git (status, diff, log, blame, show, ls-files, ls-tree,
#     rev-parse, merge-base, cat-file -p/-t/-s/-e, branch in list form), also as git -C <dir>; several of them
#     joined by ; && || and piped into head, tail, wc, sort, uniq or grep;
#   - git add, commit and push, alone, always answered with permissionDecision "ask";
#   - calibrate.sh and the orchestrate clean.sh, alone;
#   no substitution, redirection, subshell or background.
#   - Agent: a plan row (T1 and up, no letter) is not delegated while the
#     chain's plan.md is still a draft; T0, pre-plan inspection, passes.
#   - Read: an integrator artifact (.sdlc/<slug>/work/*.md but its *-brief.md),
#     review/ output and any file outside .sdlc/ only with limit <= 40 (the
#     frontmatter and summary, or one cited file:line); the rest of the chain,
#     briefs and ~/.claude are read freely.
# Agents (agent_id set): git add/commit/push are blocked; an Edit/Write of a file
# another agent of the active chain edited in the last hour gets a warning
# (stdout JSON, exit 0): re-read it first.

. "$(dirname "$0")/lib/mode.sh"
. "$(dirname "$0")/lib/chain.sh"

payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
mode_is_orch "$sid" || exit 0
aid=$(printf '%s' "$payload" | jq -r '.agent_id // ""' 2>/dev/null)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)

block() {
  printf '%s\n' "BLOCKED by orchestrator-guard: Orchestrate mode, the main session does not $1.
Delegate it to the integrator agent (it edits, runs tests and launches the other agents) and read the artifact it returns. Allowed here: writing under .sdlc/<slug>/ (this repo's or the active chain's), read-only git, git add/commit/push (the developer confirms). /orchestrate off leaves the mode." >&2
  exit 2
}

# git_words <cmd>: prints "<verb> <rest>" of a git command, skipping one -C <dir>;
# returns 1 when it is not git
git_words() {
  local w1 w2 w3 rest
  read -r w1 w2 rest <<< "$1"
  [ "$w1" = git ] || return 1
  if [ "$w2" = -C ]; then read -r w3 w2 rest <<< "$rest"; [ -n "$w3" ] || return 1; fi
  printf '%s %s\n' "$w2" "$rest"
}

# git_read <cmd>: 0 when <cmd> is a read-only git command
git_read() {
  local gw verb rest w list=0 val=0 pos=0
  gw=$(git_words "$1") || return 1
  verb="${gw%% *}"; rest="${gw#* }"; [ "$rest" = "$gw" ] && rest=""
  case " $rest " in *" --ext-diff"*|*" --output"*|*" --textconv"*|*" -o "*) return 1 ;; esac
  case "$verb" in
    status|diff|log|blame|show|ls-files|ls-tree|rev-parse|merge-base) return 0 ;;
    cat-file) case " $rest " in *" -p "*|*" -t "*|*" -s "*|*" -e "*) return 0 ;; *) return 1 ;; esac ;;
    branch)
      # List form only: a bare name would create a branch
      for w in $rest; do
        if [ "$val" = 1 ]; then val=0; continue; fi
        case "$w" in
          -a|-r|-v|-vv|--all|--remotes|--verbose|--show-current|--column|--no-column|--no-color|--color|--sort=*|--format=*|--contains=*|--no-contains=*|--merged=*|--no-merged=*|--points-at=*) ;;
          -l|--list) list=1 ;;
          --contains|--no-contains|--merged|--no-merged|--points-at|--sort|--format) val=1 ;;
          -*) return 1 ;;
          *) pos=1 ;;
        esac
      done
      [ "$pos" = 0 ] || [ "$list" = 1 ] ;;
    *) return 1 ;;
  esac
}

# filter_ok <cmd>: 0 for a filter that only reads stdin or files and writes stdout
filter_ok() {
  local w1 rest w
  read -r w1 rest <<< "$1"
  case "$w1" in
    head|tail|wc|grep) return 0 ;;
    sort|uniq)
      for w in $rest; do case "$w" in -o|-o*|--output*) return 1 ;; -*) ;; *) return 1 ;; esac; done
      return 0 ;;
    *) return 1 ;;
  esac
}

# read_chain <cmd>: 0 when every command joined by ; && || is a git read,
# optionally piped into filters. Called only once $ ` < > ( ) and newlines
# are ruled out.
read_chain() {
  local c seg part first
  c=$(printf '%s' "$1" | sed -e 's/&&/;/g' -e 's/||/;/g')
  case "$c" in *'&'*) return 1 ;; esac
  while IFS= read -r seg; do
    [ -n "${seg// /}" ] || return 1
    first=1
    while IFS= read -r part; do
      part="${part#"${part%%[! ]*}"}"
      [ -n "$part" ] || return 1
      if [ "$first" = 1 ]; then git_read "$part" || return 1; first=0
      else filter_ok "$part" || return 1; fi
    done <<< "$(printf '%s' "$seg" | tr '|' '\n')"
  done <<< "$(printf '%s' "$c" | tr ';' '\n')"
  return 0
}

# --- Agents --------------------------------------------------------------
if [ -n "$aid" ]; then
  case "$tool" in
    Bash)
      if gw=$(git_words "$cmd"); then
        case "${gw%% *}" in add|commit|push)
          printf '%s\n' "BLOCKED by orchestrator-guard: in Orchestrate mode the integrator and its agents do not write to git. Report what is ready in your artifact; the main session commits with the developer's confirmation." >&2
          exit 2 ;;
        esac
      fi
      ;;
    Write|Edit|MultiEdit|NotebookEdit)
      chain=$(chain_active "$sid") || exit 0
      printf '%s' "$aid" | grep -qE '^[A-Za-z0-9_-]+$' || exit 0
      f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
      [ -n "$f" ] || exit 0
      case "$f" in /*) ;; *) [ -n "$cwd" ] && f="${cwd%/}/$f" || exit 0 ;; esac
      case "$f" in "$chain"/*) exit 0 ;; esac
      dir="$chain/work/.edits"
      mkdir -p "$dir" 2>/dev/null || exit 0
      key=$(printf '%s' "$f" | cksum | tr ' ' '-')
      rec="$dir/$key"
      other=""
      if [ -f "$rec" ] && [ ! -L "$rec" ] && [ -n "$(find "$rec" -mmin -60 2>/dev/null)" ]; then
        other=$(head -n 1 "$rec" 2>/dev/null)
      fi
      [ -L "$rec" ] && rm -f "$rec"
      printf '%s\n' "$aid" > "$rec" 2>/dev/null
      if [ -n "$other" ] && [ "$other" != "$aid" ]; then
        jq -n --arg c "orchestrator-guard: another agent of this chain edited $(basename "$f") in the last hour. Read the file again right before this edit and keep its changes; mention the shared file in your report." \
          '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$c}}'
      fi
      ;;
  esac
  exit 0
fi

# --- Main session --------------------------------------------------------
case "$tool" in
  Read)
    f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
    lim=$(printf '%s' "$payload" | jq -r '.tool_input.limit // "" | tostring' 2>/dev/null)
    [ -n "$f" ] || exit 0
    case "$f" in /*) ;; *) [ -n "$cwd" ] && f="${cwd%/}/$f" || exit 0 ;; esac
    case "$f" in "$HOME"/.claude/*) exit 0 ;; esac
    case "$f" in
      */.sdlc/*/work/*-brief.md) exit 0 ;;
      */.sdlc/*/work/*|*/.sdlc/*/review/*) what="an integrator artifact or review output whole" ;;
      */.sdlc/*) exit 0 ;;
      *) what="code or docs outside .sdlc/ whole" ;;
    esac
    case "$lim" in ''|*[!0-9]*) ;; *) [ "$lim" -le 40 ] && exit 0 ;; esac
    printf '%s\n' "BLOCKED by orchestrator-guard: Orchestrate mode, the main session does not read $what.
Read with limit 40 (the frontmatter and summary, or one cited file:line with offset), or have the integrator summarize it: a follow-up T0 for the spec, or the task's artifact. Briefs, intent, spec, plan and context.md are read freely." >&2
    exit 2
    ;;
  Agent|Task)
    tag=$(printf '%s' "$payload" | jq -r '.tool_input.prompt // ""' 2>/dev/null \
      | sed -nE '1,3s/.*\[sdlc:([a-z0-9-]+)\/(T[0-9]+) est=[^]]*\].*/\1 \2/p' | head -n 1)
    [ -n "$tag" ] || exit 0
    slug="${tag% *}"; task="${tag#* }"
    [ "$task" = T0 ] && exit 0
    chain=$(chain_dir "$cwd" "$slug" "$sid") || exit 0
    [ -f "$chain/plan.md" ] || exit 0
    st=$(grep -m 1 -E '^- \*\*Status\*\*:' "$chain/plan.md" 2>/dev/null)
    case "$st" in *APPROVED*|*approved*) exit 0 ;; esac
    case "$st" in *[Dd]raft*)
      printf '%s\n' "BLOCKED by orchestrator-guard: $task of $slug is a plan row and plan.md is still a draft. Ask the developer to approve the plan (set its Status) before delegating it to the integrator; only T0, the pre-plan inspection, runs before that." >&2
      exit 2 ;;
    esac
    exit 0
    ;;
  Write|Edit|MultiEdit|NotebookEdit)
    f=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
    [ -n "$f" ] && [ -n "$cwd" ] || block "edit files"
    case "$f" in /*) ;; *) f="${cwd%/}/$f" ;; esac
    case "/$f/" in */../*|*/./*) block "edit files outside .sdlc/<slug>/" ;; esac
    # Physical path: the deepest existing directory resolved, the rest appended
    d=$(dirname "$f")
    while [ ! -d "$d" ]; do d=$(dirname "$d"); done
    pd=$(cd "$d" 2>/dev/null && pwd -P) || block "edit files outside .sdlc/<slug>/"
    tail="${f#"$d"}"
    pf="${pd%/}$tail"
    chain=$(printf '%s' "$pf" | sed -nE 's#^(.*/\.sdlc/[a-z0-9-]+)/.+$#\1#p')
    [ -n "$chain" ] || block "edit files outside .sdlc/<slug>/"
    case "$chain" in */.sdlc/*/.sdlc/*) block "edit files outside .sdlc/<slug>/" ;; esac
    root=$(sdlc_root "$cwd")
    if [ -n "$root" ] && [ "$chain" = "$root/.sdlc/$(basename "$chain")" ]; then
      chain_set "$sid" "$chain"; exit 0
    fi
    chain_ok "$chain" || block "edit files outside .sdlc/<slug>/ (another repo's chain must already hold intent, spec, plan or context.md)"
    chain_set "$sid" "$chain"
    exit 0
    ;;
  Bash)
    # A $ that closes a quoted regex ("\.png$") or stands alone expands nothing
    bare=$(printf '%s' "$cmd" | sed -E 's/\$(["'"'"' |]|$)/\1/g')
    case "$bare" in *[\`\$\>\<\(\)]*|*$'\n'*) block "run commands (only plain git and the orchestrate scripts)" ;; esac
    case "$cmd" in
      *[\;\&\|]*)
        read_chain "$cmd" && exit 0
        block "run commands (only read-only git, chained or piped into head, tail, wc, sort, uniq or grep)" ;;
    esac
    read -r w1 w2 rest <<< "$cmd"
    if [ "$w1" = bash ]; then
      case "$w2" in
        "~/.claude/skills/sdlc/calibrate.sh"|"$HOME/.claude/skills/sdlc/calibrate.sh") exit 0 ;;
        "~/.claude/skills/orchestrate/clean.sh"|"$HOME/.claude/skills/orchestrate/clean.sh") exit 0 ;;
      esac
    fi
    gw=$(git_words "$cmd") || block "run commands, explore or run tests"
    verb="${gw%% *}"
    case "$verb" in
      status|diff|log|blame|show|ls-files|ls-tree|rev-parse|merge-base|cat-file|branch)
        git_read "$cmd" && exit 0
        block "run git $verb in that form (read-only git only; git branch only lists)" ;;
      add|commit|push)
        case " ${gw#* } " in *" --no-verify"*|*" -n "*|*" --force"*|*" -f "*) block "skip git hooks or force a push" ;; esac
        # Always the developer's call, also for git -C forms no permission rule matches
        jq -n --arg r "Orchestrate mode: git $verb from the main session needs the developer's confirmation." \
          '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask", permissionDecisionReason:$r}}'
        exit 0 ;;
      *) block "run git $verb" ;;
    esac
    ;;
esac
exit 0

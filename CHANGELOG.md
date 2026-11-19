# Changelog

Semantic versioning. **MAJOR**: breaks something in a project or a machine
that the migration alone does not fix. **MINOR**: adds rules, skills or project
files (ships `migrations/<version>.md` if it touches projects). **PATCH**:
fixes with no change in expected behavior.

## 3.7.0 — 2026-11-19

From the profile of the ASTRA sessions (13-19 Nov). Slug `.sdlc/claudio-3-7-0/`.
`./install.sh` is enough; a project opts in to `## Agent defaults` in its own
`CLAUDE.md` (no migration).

- **Agents can use LSP**: scout, implementer, integrator, reviewer and
  verifier list `LSP` in `tools`; symbols are looked up with LSP or the tags
  index the repo's `CLAUDE.md` names, before `grep`.
- **Repo agent defaults**: the integrator applies the `## Agent defaults`
  section of the repo's `CLAUDE.md` to the task and every agent it launches;
  the brief template states only the exceptions.
- **Read-only build dir**: while another task builds or measures, read-only
  agents get `CARGO_TARGET_DIR="$TMPDIR/claudio-target-ro"`, never the
  workspace `target/`.
- **`bash-habits` hook** (PostToolUse, Bash): a reminder, never a block, when
  a test run keeps its output in no file and when a python/perl/ruby script
  rewrites a non-temp file.

## 3.6.3 — 2026-11-19

Fixes from the first session on 3.6.2 (ASTRA VIS-EST-001). Slug
`.sdlc/claudio-3-6-3/`. `./install.sh` is enough.

- **Images are read freely**: the main session's Read guard lets PNG, JPG,
  GIF, WebP and BMP through whole, also under `review/shots/`; text under
  `review/` and `work/` keeps the `limit` 40.
- **Main launches only `integrator` and `scout`**: the guard blocks a
  verifier, reviewer or untyped agent from the main session; review rows
  go to the integrator, which writes their findings.
- **Plan rows close for any agent**: at SubagentStop a plan row run by an
  agent other than the integrator takes the report's `RESULT:` line, or
  `done` when it has none. A `needs-decision` is answered by continuing the
  integrator with `SendMessage`, so the row closes.
- **Guard**: metacharacters inside quotes are text (`grep -E "(a|b)"`,
  `grep 'x|y'`); `$` and backticks inside double quotes stay blocked, an
  unterminated quote blocks. `cut` joins the allowed filters.

## 3.6.2 — 2026-11-19

Orchestrate after the second ASTRA session on 3.6.0 (natural-volume-registry):
plan rows left `pending`, whole artifacts read by the main session, and 1.1M
Fable output tokens spent writing the spec and briefs. Slug
`.sdlc/claudio-3-6-2/`. `./install.sh` is enough.

- **Plan Status by hook**: `task-actuals` sets a delegated row to
  `in progress` when the main session launches it with an approved plan
  (new PreToolUse `Agent|Task` entry) and to the artifact's `result`
  (`done`, `blocked`, `needs-decision`) at the integrator's SubagentStop.
  Main rows, nested tags (`T5a`) and a `done` row relaunched are left alone.
- **Summary required**: `subagent-report-check` sends an integrator back
  once when its artifact has no `## Summary` or one over 15 lines.
- **Read guard**: in Orchestrate mode the main session reads integrator
  artifacts (not briefs), `review/` output and files outside `.sdlc/` only
  with `limit` 40 at most (`Read` added to the guard's matcher). The rest of
  the chain and `~/.claude` are read freely.
- **Main decides, the integrator writes**: the main session lists its
  decisions in a brief; a `T0` with a *Spec draft* section writes or amends
  `spec.md` and the plan prose. New `templates/brief.md`, at most 20 lines.

## 3.6.1 — 2026-11-19

Fixes from the first sessions on 3.6.0 (ASTRA AST-ESP-002 in Orchestrate,
EIC front in Spec mode). Slug `.sdlc/claudio-3-6-1/`. `./install.sh` is
enough.

- **Haiku 5.5 has a price** in `task-actuals` ($0.10 / $0.50, cache read
  $0.01 per M): scout rows, and the integrator's `cost` that adds them, no
  longer come out as `usd_min: null`.
- **Main rows when the plan is edited from Bash**: `task-actuals` also runs
  on PostToolUse Bash and measures the plan's main rows when the command
  names `.sdlc/<slug>/plan.md`, or names `plan.md` from inside the chain
  (a `python3` or `sed -i` edit of the Status). Before, those tasks had no
  row or a 0-minute one.
- **Estimates from data in every mode**: `calibrate.sh` ends with one
  `est=` line per runner, from the median actual it says to use; the
  starting table is no longer what gets copied into tags.
- **Guard**: `git ls-tree` and `git cat-file -p/-t/-s/-e` are read-only
  git; a `$` that closes a quoted regex (`grep -e "\.png$"`) or stands
  alone no longer blocks a read chain. `$VAR`, `${...}` and `$(...)` stay
  blocked.
- **T0 for a spec**: the integrator returns every fact the spec needs as a
  line with its file:line, grouped by the spec's sections; the main session
  drafts from that summary and asks a follow-up `T0` for a gap instead of
  reading the sources.

## 3.6.0 — 2026-11-19

Orchestrate mode after its first session with Fable 5.2 as the main
session (3.5.0, chain and session in the same repo). Slug
`.sdlc/claudio-3-5-1/`. No project files change: `./install.sh` is enough.

- **Read-only git in the main session**: `orchestrator-guard` also allows
  `ls-files`, `rev-parse`, `merge-base` and `git branch` in list form (a bare
  name, `-d/-D/-m/-c` or upstream options stay blocked). Reads can be joined
  with `;`, `&&`, `||` and piped into `head`, `tail`, `wc`, `sort`, `uniq` or
  `grep`; substitution, redirection, subshells and `&` stay blocked, and
  `git add/commit/push` must still run alone.
- **No delegation on a draft plan**: the guard now also sees `Agent`; a plan
  row tagged `T1` or later is blocked while `plan.md` says draft. `T0`, the
  pre-plan inspection, passes.
- **Plan-stage reading**: prior chains and design docs are read in `T0`, not
  by the main session.
- **Escalation**: `integrator.md` gains *Escalate*, the cases where it stops
  as `needs-decision` instead of deciding (two readings of the spec, an
  unranked trade-off, a fix outside Files or layer, two competing causes, a
  disputed finding, security, data-loss or irreversibility risk). The main
  session decides them and never sends them back unanswered.
- **No advisor in the main session**: the mode notice and the skill say not
  to call it (a server tool, hooks cannot block it) and to ask for
  `/advisor off`.
- **Nested estimates from data**: the integrator takes `est` from the
  runner's median actual (brief or `calibrate.sh`). The old fixed 3m/400k
  ran 3–5x above the real cost and flagged every row.
- **`usd_min` on main rows** (`task-actuals`), with the same price table as
  subagents: the main session is the most expensive model.
- **test-guard**: removing an exact duplicate assertion passes; Rust
  `assert_eq!`/`assert_ne!` (`assert*!(`) now count as assertions, which
  they did not before.
- **Review evidence**: `subagent-report-check` sends an integrator report
  back when its artifact cites `review/findings.md` and the file is missing;
  evidence left in a scratchpad is copied to `review/evidence/`.
- **macOS**: the implementer uses `sed -i ''` or `perl -pi -e`, and a red
  step that cannot run is retried another way, never skipped.

## 3.5.0 — 2026-11-19

Orchestrate mode, after its first real delivery (chain in one repo, session
in another, main session on Opus 5.5). Slug `.sdlc/orchestrate-hardening/`.

- **Active chain** (`hooks/lib/chain.sh`): the chain may live in another
  repo. `/orchestrate <dir>/.sdlc/<slug>` or the first write to an existing
  chain records it in the session marker. `orchestrator-guard` lets the main
  session write it, and finds the repo's own `.sdlc/` above cwd, so a `cd`
  into `.sdlc/` no longer blocks it.
- **`task-actuals` across repos (fix)**: it looked for `.sdlc/<slug>/` only
  under cwd, so a session in another repo dropped every record, the
  machine log line and the artifact `cost`. It now uses the active chain,
  and the machine log gets the line even when no chain is found.
- **Git closes from the main session**: `git -C <dir>` read-only verbs, and
  `git add/commit/push` answered with `permissionDecision: ask`. Global and
  project settings move those three from `deny` to `ask` (migration
  `3.5.0.md`). Agents stay blocked from git writes in the mode.
- **Scoped deletes**: `skills/orchestrate/clean.sh` removes only inside
  `.sdlc/<slug>/work/` and `$TMPDIR/claudio-*` scratch, allowed in settings;
  `rm -r` stays denied.
- **`/orchestrate allow-test <file>`**: the developer's approval reaches
  `test-guard` for that file, for 30 minutes, for any agent of the session
  (also through `bash-file-check`).
- **Durable evidence**: the integrator keeps test logs in
  `.sdlc/<slug>/review/` and writes `review/findings.md` for the reviewers.
- **Resume**: `plan-resume` also runs on `resume`, reads the active chain
  and lists delegated tasks with no artifact back, to relaunch them.
- **Shared files**: the plan marks `(shared)` files of a wave;
  `orchestrator-guard` warns an agent when another one edited the same file
  in the last hour.
- **Model**: the mode no longer assumes Fable 5.2; `/orchestrate` notes
  when the main session already runs Opus, where the cost split does not
  apply.

## 3.4.0 — 2026-11-18

Orchestrate mode, opt-in: Fable 5.2 plans and decides, Opus 5.5 does the
work, and they talk only through artifacts. From the session profile:
mixed sessions led by Fable 5.2 used about half the weighted tokens per
agent hour of those led by Opus 5.5 (6 sessions against 114, a correlation),
but Fable as the main model still spent 19% of its time on tests. Slug
`.sdlc/fable-orchestrator/`.

- **`/orchestrate` and `/orchestrate off`**: a per-session marker next to
  Vibe's (independent of Spec/Vibe), re-injected after compact and resume,
  cleared on startup and clear; the status line shows `Orch`.
- **New hook `orchestrator-guard.sh`** on `PreToolUse`: in the mode, the
  main session (no `agent_id`) cannot Edit, Write or run Bash, except
  writes under `.sdlc/<slug>/` and plain read-only git.
- **New agent `integrator`** (Opus 5.5, effort medium): takes one task,
  integrates, and launches `implementer`, `verifier`, `reviewer` and `scout`
  as nested agents tagged `T<n>a`, `T<n>b`. Those four now carry
  `disallowedTools: Agent`, so the chain stays at two levels.
- **Artifacts**: template `skills/sdlc/templates/artifact.md` with `data`
  (type of information), `cost` and `regen`; the integrator answers with
  `ARTIFACT: .sdlc/<slug>/work/<file>.md`, which `subagent-report-check`
  validates (file present, required fields). `task-actuals` writes `cost`
  (tokens, `usd_min`, minutes, agents, nested agents included) and adds
  `usd_min` to every record; it is a floor, since transcripts do not carry
  output tokens.
- **New skill `orchestrate`**: roles, delegation, how to read an artifact,
  and the persist-or-discard rule (discard by default; usefulness crossed
  with the cost of regenerating it; destination by data type).
- **`/repo-setup`**: `.gitignore` gets `.sdlc/*/work/`; `check.sh` warns
  without it. Migration `3.4.0`.

## 3.3.0 — 2026-11-18

Less session time on tests and a clear model hierarchy, from a profile of
439 local sessions (21% of agent time on tests, 51% of test runs repeated
with no edit, 55% full-suite runs). Slug `.sdlc/test-time/`.

- **Implementer**: runs its task's test and the tests of the files it
  touches, not the whole suite; the main session runs the suite once after
  the wave. Test output goes to a file and is read from there; no test runs
  again with nothing changed. Failure budget: the same failure twice stops
  the task as `blocked`, never more than four runs of the same test. New
  report lines `Attempts: <n>` (required by `subagent-report-check`, next
  to `Red:`), `Suite: not run` and `Log:`.
- **Verifier**: in its last step, reads the wave's test output instead of
  running that suite again.
- **Model ladder**: ends in `/advisor` with Fable 5.2 (it advises, Opus keeps
  executing) instead of Fable 5.1 as the main model; `high` after two failed
  attempts. Lookups needing more than two searches go to the `scout`, which
  now runs at effort `low` and returns paths and lines.
- **`/repo-setup`**: `CLAUDE.md` gets a one-test command and the "test output
  in a file" convention; Rust repos get `cargo check --tests`,
  `cargo nextest run` filtered while iterating and the workspace at the end.
  Migration `3.3.0`.
- **`evals-on-config-change`**: runs only the cases that name the edited file
  (`EVALS_ONLY` in `run.sh`); shared code or no match still runs the whole
  suite, and so does a coalesced rerun, which may come from another file.

## 3.2.0 — 2026-11-16

File edits made through Bash are now checked. In auto mode (the default
Claudio installs) Claude Code tells the model to make small file changes
with `sed`, heredocs or short scripts instead of Read, Edit and Write, and
`credential-guard`, `test-guard`, `task-actuals` and
`evals-on-config-change` only saw Write and Edit. No project migration.

- **New hook `bash-file-check.sh`** on `PreToolUse`, `PostToolUse` and
  `PostToolUseFailure` (matcher `Bash`). Before the command it records a
  marker; after it (also when the command fails), it lists the files in
  the git work tree whose status changed since the marker (ctime, so `mv`,
  `cp -p` and `tar` count) and runs `credential-guard` and `test-guard` on
  them as if they had been written with Write or Edit, and `task-actuals`
  on changed `plan.md` files. A tracked file is compared with its HEAD
  version, so everything uncommitted in a touched file is checked, and an
  old uncommitted hit can be reported again. A hit reaches the model with
  exit 2: "changed through Bash and checked after the fact… fix it with
  Edit now".
- **Git runs no repo code.** The hook uses only `git rev-parse`,
  `ls-files` and `cat-file`, with `core.fsmonitor` off, lazy fetch off
  (`GIT_NO_LAZY_FETCH`) and the `GIT_*` location variables unset: no
  `git status` or `git diff`, which would run a repo's fsmonitor, clean
  filters, textconv or `diff.external`, and no partial-clone fetch, which
  would run its `uploadpack`. Files are compared as text even with NUL
  bytes. A top
  level that does not contain `cwd` (a `.git` file or `core.worktree`
  pointing elsewhere) is not checked.
- **What it cannot do.** It does not stop the write (no hook event can,
  short of parsing shell). It does not run the evals hook: config files
  changed through Bash get no eval run (the evals hook below covers Write
  and Edit). It checks only the git work
  tree of `cwd`: not ignored files (the command can edit `.gitignore` or
  `.git/info/exclude` itself), not nested repositories, not other
  repositories reached with `cd` or `git -C`. It checks at most 50 files
  per command and none over 1 MB, and says so to the model when it skips.
  A command that also commits its own write, or that deletes or ages the
  marker in `$TMPDIR`, or a background command that writes after it
  returns, is not caught: this is a check against habit, not against
  deliberate evasion. Cost measured: about 50–75 ms per Bash command with
  no change and 170–190 ms with one changed file (repos of 525 and 2003
  tracked files); under 1.5 s with 3000 untracked files.
- **Agents and the `sdlc` skill**: edit repo files with Edit or Write;
  shell only for temp files.
- **The config-change evals hook now finishes.** The suite takes 1–2
  minutes and the hook had a 15 s timeout, so Claude Code cancelled it and
  a red suite never reached the model. It now runs with `asyncRewake` and a
  600 s timeout: the edit does not wait, a red suite wakes Claude with at
  most 40 `FAIL` lines and the summary, and a green one says nothing. A
  burst of edits shares one run (at most one running and one pending per
  suite, locked in `~/.claude/workflow/locks`, mode 700, never through a
  symlink; a lock left by a dead process is taken over). In `claude -p`
  sessions a run still going at exit is cancelled.

## 3.1.0 — 2026-11-16

Delegated work that survives long, multi-layer tasks, from a three-day run
with 154 subagents. No project migration: everything changes in `~/.claude`.

- **Turn limits.** `implementer` and `verifier` go from 40 to 60
  `maxTurns`. All four agents keep a running report, so output cut short at
  the limit (Claude Code returns it marked as partial) still says what is
  done and what is left; the `sdlc` skill says to resume it with
  SendMessage, not relaunch it. No turn-warning hook: the hooks reference
  documents the subagent transcript only for `SubagentStop` and gives no
  turn count.
- **Red evidence.** An implementer report with `RESULT: done` needs a
  `Red: <command> → <failing line>` or `Mutation: <what was broken> →
  <failing line>` line; one that is missing, empty or opens with an
  admission ("not seen", "none", "n/a", "no …", "passed", "green") is sent
  back. A bad `TASK:` id is answered with "task IDs are `T<n>`". The
  verifier counts a suite result given in its prompt with command and
  output.
- **`production-gate` and file writes.** Heredoc bodies are still scanned:
  filtering them without a shell parser let real commands through
  (hyphenated tags, expanded bodies, `>(bash)`). The block message now says
  to write files with Write or Edit, whose content is never scanned.
- **Task ids.** `T<n>` plus an optional letter, then a space or the end of
  the cell: the report hook rejects `T3-red`, and the status-line hint now
  shows a task in progress such as `T3b`.
- **Delegated-work rules** in `implementer` and `verifier`: git in its own
  command, background processes stopped in the same command, repo files
  copied and never moved out, temp files under `mktemp -d`.
- **Verifier order.** Change behavior and adjacent flows first, the suite
  last and only when the main session did not pass its result.
- **`scout`** says what it takes: one lookup per launch, not audits.
- **Plan template.** At most 3 rows per delegated task, `seam:` tasks for
  layers that do not build apart, "may I open windows?" in *Stop and ask
  if*, a *Review* section (three verdicts or a signed waiver), and task IDs
  stated as `T<n>`. The `sdlc` skill: orchestration on `main` rows, and no
  figure reaches the user without a run that could have failed.

## 3.0.0 — 2026-11-04

- **claude-sdlc is now Claudio.** The repository moves to
  `github.com/atcastells/claudio` (GitHub redirects the old URL) and the
  default folder is `~/claudio`. An existing clone keeps working from its
  old folder: `install.sh` and the version notice reuse the recorded
  source and profile paths, and a clone is recognised by its files, not
  its folder name. No project migration: nothing `/repo-setup` leaves in a
  repo carries the name.
  - Breaking: every hook notice is prefixed `Claudio:` instead of
    `claude-sdlc:`, and the temp markers are `claudio-mode-<id>` and
    `claudio-report-<id>`. A session that is in Vibe while you upgrade
    returns to Spec once; type `/vibe` again.
- **Plain README.** One sentence to paste into Claude Code; the agent
  follows `docs/install.md` (checks `git` and `jq` and asks before
  installing them, clones or updates, asks about an organization profile,
  explains the result in plain words). The technical content moves to
  `docs/technical.md`.
- **Plan hints in the status line** (terminal). With an open
  `.sdlc/*/plan.md` (the newest with a task not done): the task in progress
  against its estimate (`T3 4m/6m`; yellow over, red over twice; `T3 ~6m`
  for tasks with no start line), what is left (`5/12 · ~22m left`), and
  `compact between tasks` from 70% context with a task open (90% always).
  New `hooks/lib/plan-hint.sh`; it prints only ids and numbers, skips
  symlinks and files over 256 KB, and any parse error leaves the line as
  before.
- **Company progress phrases.** A profile's `company.json` may name a
  `spinner_verbs` file in the company repository: a JSON array of 1–200
  phrases of 1–80 characters. `install.sh` validates it with the same path
  checks as `rules` and sets `spinnerVerbs` to `replace` mode, replacing the
  user's own phrases (kept in the `settings.json.bak-<ts>` backup). Without
  the key the user's phrases are untouched; if a later profile drops it, the
  last phrases stay.

## 2.7.0 — 2026-11-03

- **Spec and Vibe modes, per session.** Spec (the full chain) stays the
  default. `/vibe` switches the session to Vibe, for work that advances by
  trying ideas and looking at the result; `/vibe off` returns to Spec. In
  Vibe, a new `vibe` skill replaces intent → spec → plan, the `plan.md`
  approval and mandatory TDD; git, credentials, the release rule, verifying
  before claiming and `test-guard` still apply, and a PR still goes
  through Spec.
  - Two documents are the agent's base: `.sdlc/map.md`, a mermaid map of
    the project's systems and features with their state (`idea`, `wip`,
    `done`, `dropped`), read at start and updated each iteration; and
    `.sdlc/vibe/<topic>.md`, one per extension (goal, pieces, done and
    left, log). An idea that settles is promoted to `.sdlc/<slug>/intent.md`.
  - New hook `mode.sh` (`UserPromptSubmit` and `SessionStart`) keeps a
    per-session marker in `$TMPDIR`, keyed by a validated `session_id`.
    Vibe survives compaction and resume; `/clear` and a new session start
    in Spec. It never echoes the prompt.
  - The status line shows `Spec` or `Vibe` after the model.
  - `settings.template.json` adds the `UserPromptSubmit` event. As with
    every event the template defines, `install.sh` replaces an existing
    `UserPromptSubmit` in `~/.claude/settings.json` whole: keep your own
    hooks for it in `settings.local.json`.
- No migration: nothing `/repo-setup` leaves in projects changes.

## 2.6.0 — 2026-10-27

- **`/rules`: personal rules by scope.** A new skill adds, modifies or
  deletes the user's own rules, one question at a time: the action, the
  scope (every repo of this user, or the repo of this session) and, for
  this repo, whole repo or only some files (globs suggested from tracked
  files, each with its match count). Nothing it writes is shared:
  - Global rules go to `~/.claude/rules/personal/<topic>.md`.
  - Repo rules go to `<repo>/.claude/rules/personal/<topic>.md`, excluded
    through `.git/info/exclude` (never `.gitignore`), so `git status` does
    not change; path-scoped ones carry `paths:` frontmatter.
- Every file operation goes through `skills/rules/rules.sh`
  (`write`, `list`, `delete`, `globs`): it writes the frontmatter itself and
  checks it round-trips (a broken one would load the rule everywhere),
  refuses globs with no tracked match, credential-shaped text (through
  `credential-guard`), and a `personal/` dir that is tracked in the repo.
- The skill tells the user once that a rule is not a lock (only a hook
  blocks), that customer data never goes in a rule, and when always-loaded
  personal rules pass 40 lines.
- Eval: `install.sh` leaves `~/.claude/rules/` alone on install and upgrade.
- **Quieter install.** `install.sh` no longer prints the suite case by case:
  it starts `evals/install-verify.sh` in the background and ends with four
  lines. The result goes to `~/.claude/workflow/install-verify.json`
  (`running`, `green` or `red`, with each failed case's name, kind, file and
  detail) and the log to `install-verify.log`.
  - **Behavior change**: a red suite no longer fails the install. Instead,
    `workflow-version-check` tells Claude at the next session start. It only
    interrupts the user when a protection is not active (a failed
    `credential-guard`, `test-guard` or `production-gate` case), naming it
    and the action: reinstall, and tell the workflow maintainer if it
    persists. Any other failure is mentioned in one line under "Found" at
    the end of the run. A run stuck in `running` for over 10 minutes is
    reported too.
  - **Repo cases.** A case can declare `"repo"`: the product repo it tests
    (incident evals). `EVALS_SKIP_REPO=1` skips them; the background
    verification, `--verbose` and `evals-on-config-change` set it, since
    neither an install nor a config change touches that repo's code.
    `EVALS_REPO=<dir>` runs only the cases of that repo; the `verifier`
    runs it in the Test stage. A session in a git worktree of the repo does
    not match (different path). Existing incident evals need `"repo"` added
    by hand.
  - `--verbose` (or `WORKFLOW_INSTALL_VERBOSE=1`) keeps the old foreground
    run that fails the install when red, and also writes the result file;
    this repo's clean test install uses it. `WORKFLOW_INSTALL_NO_VERIFY`
    removes the result file, so an old red result never outlives a reinstall.
    The result shows a file under the home directory as `~/…`, and each
    failed case's `hook`.
  - `evals/run.sh` accepts `EVALS_RESULT_JSON=<file>` for a machine-readable
    result; stdout is unchanged.
- **Company rules from their own repo.** A profile may carry
  `company.json` (`url`, `rules`): the company rules then live in a
  separate repo that names nothing of this workflow. `install.sh
  --company-repo <dir>` composes core + those rules (leading YAML
  frontmatter stripped) + the profile's `CLAUDE.md`, and remembers the dir.
  The rules path must be relative, inside the repo, a regular file, at most
  16 KB; anything else stops the install before it writes. Without a
  terminal and no saved dir, the install stops naming the flag and the
  clone command; nothing searches the disk.
  - New skill `/workflow-install`: asks where the company repo is (or to
    clone it) and shows the one command to run; it runs nothing.
  - At session start, a saved company repo that is gone, or that lost its
    rules file, brings a notice suggesting `/workflow-install`.
  - `profiles/example/company.json.example` documents the format.
- No project migration: nothing `/repo-setup` leaves in projects changes.

## 2.5.0 — 2026-10-20

- **Secondary profile per repository.** A repo declares
  `"profile": ".claude/profile"` in `.claude/workflow.json`. The new
  `project-profile` hook (`SessionStart`: startup, clear, compact; silent on
  resume) injects that profile's `CLAUDE.md` (≤ 150 lines) for that repo
  only. It adds to the organization profile and never disables it: where an
  organization rule has nothing to act on, the profile says so. The repo's
  own `CLAUDE.md` does not grow.
- The path must be relative, without `..`, and stay inside the repo; a
  symlinked `CLAUDE.md` or `profile.env` is ignored.
- `credential-guard` and `production-gate` load the repo profile's
  `profile.env` on top of the global one, so their messages name that
  repo's secrets manager and policy.
- `evals/run.sh` accepts `WORKFLOW_PROFILE=<dir>` in installed mode too:
  a repo profile's `evals/cases/` run with the installed suite.
- Template `skills/repo-setup/templates/project-profile/` (glossary and
  tone, quality criteria, repository policy, organization rules with nothing
  to act on here) and a line in `repo-setup`.
- **Review fixes** (three `reviewer` passes before the PR):
  - Repo profile files are size-capped before reading (`profile.env`
    ≤ 4 KB, `CLAUDE.md` ≤ 16 KB): a large `profile.env` could make a guard
    exceed its 5 s timeout.
  - Injected content is capped at 150 lines and 12 KB; notices never echo
    the declared path; a missing profile dir gets its own notice; the header
    says the text is repo-authored.
  - Profile cases cannot run code (`script`, `env`, path-like `hook` are
    skipped). New case kind `file_lacks` (pattern, optional `until`).
  - Evals for the public template and for guards ignoring symlinked,
    oversized or undeclared repo `profile.env`.
- `/repo-setup upgrade` sets only `workflow_version` and `updated` in
  `.claude/workflow.json` and keeps every other key, such as `profile`.
- No project migration: the key is optional.

## 2.4.0 — 2026-10-20

- **Fix: reports handed back through `SubagentHandback` were not read.**
  Subagents deliver their report as the `message` of that tool, not as final
  text, so in 2.3.0 every `Deviation cause:` was lost and
  `subagent-report-check` saw an empty message. New `hooks/lib/report.sh`
  reads the last handback from the subagent transcript, falling back to
  `last_assistant_message`.
- `subagent-report-check` now checks the report **before** it leaves, on
  `PreToolUse` with matcher `SubagentHandback`; it blocks at most once per
  `agent_id`. On `SubagentStop` it skips agents that handed back.
- **Machine-level log** `~/.claude/actuals.jsonl` (override:
  `CLAUDE_SDLC_ACTUALS`): every closing line also lands there with a `repo`
  field, so a new repo's first plan can calibrate from the others. Never
  committed, never sent anywhere.
- `calibrate.sh`: per runner, repo and machine-log figures side by side;
  `use: repo` from 5 tasks of that runner, else the machine log (or the
  repo when the machine log has none of that runner yet). It prints
  the **median actual** minutes and tokens, which is what to estimate with:
  ratios mix tasks estimated with different starting tables.
- **New starting table** from 18 measured tasks: implementer S 2m/200k,
  M 2m/300k, L 3m/400k; scout 1.5m/650k (each request under 100K);
  verifier/reviewer 8m/700k; main 5m/6M. Rows with under 3 samples are
  marked low confidence.
- **Shared context per plan**: `templates/context.md` (≤ 30 lines). The
  main session writes `.sdlc/<slug>/context.md` before the first wave; every
  implementer reads it first and may add one `Learned:` line to its report;
  the main session folds those lines in after each wave. In this release's
  own plan, the 7 implementer runs had a median of 154k tokens (range
  95–457k) against a median of about 240k in the 15 runs before.
- `main` task causes come only from an explicit `done (cause: …)` in the
  Status cell.
- **Review fixes** (three `reviewer` passes before the PR):
  - `cause` is redacted before it is logged: the `credential-guard`
    patterns (now shared in `hooks/lib/leak-patterns.sh`) and URLs with
    user:password become `[redacted]`. Found live: a reviewer's report
    quoted a fake credential and the hook stored it.
  - Concurrent writes no longer lose lines: `mkdir` lock (a lock older than
    a minute is treated as left by a killed hook), unique tmp file,
    rewrite only when the `agent_id` is already logged.
  - One plan edit that closes a task and starts the next now records the
    closing line in the machine log too.
  - `task-actuals` acts only on a `plan.md` under `cwd`;
    `subagent-report-check` uses `agent_id` as a marker name only when it
    matches `^[A-Za-z0-9_-]+$`.
- Project migration `2.4.0`: `.sdlc/README.md` lists `context.md`.
- Sources: live transcripts of 2.3.0 runs (handback shape, hook events);
  code.claude.com (hooks, sub-agents); claude.dev ("What a task costs on
  Opus 5.5" for the agent-team cost).

## 2.3.0 — 2026-10-20

- **Plans with estimates and parallel waves.** The `plan.md` task table
  gains `Runs on`, `Depends` and `Est` (minutes / tokens); *Status* stays
  last. New sections: `Schedule` (waves of tasks with no pending dependency
  and disjoint files; critical-path wall-clock next to the sequential sum)
  and `Estimate vs actual`.
- **`implementer` agent** (Sonnet 5.5, `effort: medium`, `maxTurns: 40`):
  one well-specified plan task per invocation, only its listed files, red
  test first, no git writes. Its report carries `TASK:`, `RESULT:` and
  `Deviation cause:`; `subagent-report-check` sends it back otherwise.
- **Rule change** from 2.1.0: small models no longer "never edit". Haiku
  never edits; Sonnet edits only as `implementer`, for a task with a clear
  spec and a test that proves it ("Building with Claude Sonnet 5.5",
  claude.dev). Integration and decisions stay in the main session.
- **`task-actuals` hook** (`SubagentStop`; `PostToolUse` on `plan.md`
  edits): appends measured minutes and tokens per task to
  `.sdlc/<slug>/actuals.jsonl`, with the deviation from the estimate and its
  cause; deviations over 50 % are flagged, never blocked. Delegated tasks
  are found by the tag `[sdlc:<slug>/T<n> est=<min>m/<ktok>k]` on the first
  line of the prompt; `main` tasks by their *Status* going from
  `in progress` to `done`. Output tokens are not recorded: transcripts store
  usage at stream start.
- **`skills/sdlc/calibrate.sh`**: prints the starting estimate table and
  the median actual/estimate per runner from past `actuals.jsonl`.
- `plan-resume`: when the plan has a `## Tasks` heading, only that section
  is read; the `Estimate vs actual` table also has `T<n>` rows. Plans
  without the heading keep the old behavior.
- `sdlc` Stage 3: estimate with `calibrate.sh`, route down the ladder,
  launch a wave in one message, check `git diff --stat` after each wave.
- Sources: claude.dev ("Building with Claude Sonnet 5.5", "What a task
  costs on Opus 5.5", "Spending your effort"), code.claude.com (sub-agents,
  hooks), platform.claude.com (models overview).
- Project migration `2.3.0`: `.sdlc/README.md` lists `actuals.jsonl`.
- Known, unchanged: `install.sh` takes each hook event from the template
  wholesale, so a user-defined `PostToolUse` entry in `~/.claude/settings.json`
  is replaced (the backup `settings.json.bak-<timestamp>` keeps it). 2.3.0
  adds a second template `PostToolUse` entry.

## 2.2.1 — 2026-10-08

- **Fix:** `workflow-version-check` stayed silent when the installation came
  from one clone and the developer worked in another clone that was ahead.
  It now notices any claude-sdlc clone ahead of the installation and does
  not treat a clone as a project.
- Every notice that asks for an install ends with the command to run, for
  the agent to show verbatim and the developer to run with `!`:
  `! cd '<clone>' && ./install.sh` (with `git pull --ff-only &&` when a
  project is ahead of the source). Paths are single-quoted.
- No project migration.

## 2.2.0 — 2026-10-08

- **`scout` agent** (Haiku 5.5, `effort: medium`, read-only, `maxTurns:
  15`): lookups, logs and test output, with a summary that cites file:line.
  `effort: medium` because at `low` Haiku 5.5 is more likely to skip a search
  or a check; the turn cap keeps its prompt under the 100K-token price step.
- `sdlc`: the ladder names the models — `scout` (Haiku 5.5) reads, `verifier`
  / `reviewer` (Sonnet 5.5) verify and review, the main session edits — and
  the Haiku 5.5 price step (prompts over 100K tokens cost 5×).
- `verifier` and `reviewer` stay on Sonnet 5.5.
- The `haiku` alias is Haiku 5.5 on the Anthropic API from Claude Code
  2.1.293; on Bedrock, Google Cloud and Foundry it is still Haiku 4.5.
- Sources: platform.claude.com (Haiku 5.5 overview, "Prompting Claude Haiku
  5.5"), code.claude.com (model config, changelog).
- No project migration: nothing `/repo-setup` leaves in projects changes.

## 2.1.0 — 2026-10-07

- **`reviewer` agent** (Sonnet 5.5, `effort: high`, read-only): one pass of
  `REVIEW.md` per invocation. Stage 5 launches three in parallel; the main
  session consolidates and checks every cited file:line.
- `verifier`: `effort: high`, `maxTurns: 40`.
- **`subagent-report-check` hook** (`SubagentStop`, `verifier` and
  `reviewer`): a report without its `VERDICT:` / `PASS:` line, or an
  `[IMPORTANT]` finding without `demonstration:`, is sent back once.
- **`plan-resume` hook** (`SessionStart`, matcher `compact`): after a
  compaction, lists the open tasks of every `.sdlc/*/plan.md` as context.
- `sdlc`: downward rung of the ladder (small models read, never edit; pin the
  model per agent, no `CLAUDE_CODE_SUBAGENT_MODEL`); `/advisor fable` before
  switching to Fable; effort changes keep the cache on API key or
  subscription; dynamic workflow for review only on request.
- Sources: claude.dev ("What a task costs on Opus 5.5", "Building with Claude
  Sonnet 5.5"), code.claude.com (sub-agents, hooks, advisor).
- No project migration: nothing `/repo-setup` leaves in projects changes.

## 2.0.0 — 2026-09-30

- **Profiles.** The core is organization-neutral and in English. Organization
  rules (language, data protection, secrets manager, compliance contact) move
  to a profile: `install.sh --profile <dir>` appends its `CLAUDE.md`, installs
  its evals as `p-*`, merges its `settings.json` and remembers it for
  reinstalls. `profile.env` is parsed as data, never sourced.
- **Breaking:** a 1.x machine that relied on organization rules must reinstall
  with `--profile`. `install.sh` refuses to upgrade 1.x → 2.x without
  `--profile` or `--no-profile`.
- Hook messages name the profile's secrets manager and policy
  (`WF_SECRETS_MANAGER`, `WF_POLICY_NAME`); generic text without a profile.
- `scripts/check-public.sh`: fails if a private profile is tracked or addable,
  or if any publishable file contains a term from a local
  `profiles/*/denylist.txt`. `scripts/install-git-hooks.sh` runs it on
  pre-commit and pre-push.
- `profiles/example/`: a template for your own profile.
- The repo is named `claude-sdlc`; notices are prefixed `claude-sdlc:`.
- A project behind with no migration in range (a patch release) is not
  notified and `check.sh` passes: there is nothing to change in it.
- `check.sh` accepts CLAUDE.md section names in English or Spanish.
- Eval runner: `WORKFLOW_PROFILE`, `{profile}`, `capture: all`, `repo_only`.
- **Project migration**: `migrations/2.0.0.md` (no project file changes).

## 1.1.0 — 2026-09-30

- Versioning: `VERSION`, `migrations/`, `~/.claude/workflow/` and the
  `workflow-version-check` hook (SessionStart), which tells you when a project
  or the machine is behind. `.claude/workflow.json` in every project.
- `/repo-setup upgrade` applies pending migrations; `check.sh` reports the
  version and the CLAUDE.md budget (≤ 200 lines, global + project).
- `install.sh` retires, with a backup, what a previous version installed.
- The suite runs against the repo before installing; the evals hook also
  fires when the source repo is edited.
- Guards also on `NotebookEdit`; bare `git add`, `git commit` and `git push`
  denied.
- Practices from the Opus 5.5 and Sonnet 5.5 guides and the cost-per-task
  guide: stopping and continuing, three closing headings, `plan.md` as a live
  task list, findings that block merge, effort and model ladder, cheap
  subagents, cache-friendly pauses.
- Status line: effort and session cost (USD, from the payload).
- `production-gate` no longer fires on its own name in docs (backticked or
  `production-gate.sh`) and still blocks namespaces such as `production-gate`
  or `production-gateway`.
- `test-guard` on notebooks too; `install.sh` backs up `settings.json` only
  when it changes.
- **Project migration**: `migrations/1.1.0.md`.

## 1.0.0 — 2026-09-28

Baseline: `sdlc`, `intent`, `repo-setup` skills; `verifier` agent;
`credential-guard`, `test-guard`, `production-gate`, `evals-on-config-change`
hooks; a suite of 26 evals.

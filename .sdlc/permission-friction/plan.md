# Plan: Permission friction in delegated work (C1–C2)

- **Derived from**: `../delegation-hardening/spec.md` (requirements C1–C2,
  decisions D3, D4, D9)
- **Status**: APPROVED BY ENGINEER (2026-11-16, "Apruebo los planes")
- **Nothing is implemented until this file is approved.**

## Done means

`bash evals/run.sh` FAIL 0, cases `10`–`13f` unchanged and green; ~~a
heredoc writing a file whose body mentions `production` and an action verb
is allowed~~ (reverted: heredoc bodies stay scanned, the block message points
to Write/Edit; see *After verification*); agent prompts carry the four
delegated-work rules.

## Stop and ask if

- Any of cases `10`–`13f` or `98e`/`98h` needs a change.
- Stripping heredocs needs anything beyond bash and macOS awk.
- The task needs to open windows or apps on the developer's screen.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | `production-gate.sh`: before the scans, drop heredoc bodies (from `<<[-]?['"]?TAG` to a line equal to `TAG`) unless the heredoc's command is `bash`, `sh`, `zsh`, `ssh` or `kubectl`. macOS awk. Cases first, red. | `hooks/production-gate.sh`, `evals/cases/120a-prod-heredoc-body-allowed.json`, `120b-prod-heredoc-to-bash-blocked.json`, `120c-prod-command-before-heredoc-blocked.json` | `120a` (cat > x.rs with `use crate::production::config` and `apply` in body) exit 0; `120b` (`bash <<EOF` with `kubectl apply -n production`) exit 2; `120c` (`kubectl apply -n production -f - <<EOF`) exit 2; `10`–`13f` green | C1 | implementer | — | 3m/200k | done, then reverted after verification (see below) (cause: sent back once, main found `cat <<EOF \| bash` and `python3 <<EOF` bypasses; denylist replaced by a `cat`/`tee` allowlist, 120f–g added red first) |
| T2 | `agents/implementer.md` and `agents/verifier.md`, Rules: git in its own command, never chained with `&&` or `;`; a background process is started and stopped in the same command, none outlives the agent; repo files are copied for a negative test, never moved out of the repo; temporary files under `mktemp -d`, removed in the same command. `skills/sdlc/SKILL.md`: the git line. | `agents/implementer.md`, `agents/verifier.md`, `skills/sdlc/SKILL.md`, `evals/cases/120d*.json` | `120d1–d4` per agent file (8 cases), `120d5` skill, red first | C2 | main | — | 3m/1.2M | done (cause: none; 120d* 9 red then green, suite 311/0; SKILL.md 158 lines) |

Estimates from `calibrate.sh` (2026-11-16): repo medians implementer
2.0m/156k, main 3.1m/1.2M.

## After verification (2026-11-16)

Verifier T7 of `plan-template-gates`: red, two IMPORTANT bypasses in the
heredoc filter. Developer decision: remove the filter. `production-gate.sh`
is back to its 3.0.0 scan plus one message line pointing file writes to
Write/Edit.

| Case | Before | After | Why |
|------|--------|-------|-----|
| `120a` | heredoc body written by `cat` → exit 0 | → exit 2 | filter removed |
| `120e` | `<<-` body → exit 0 | → exit 2 | filter removed |
| `120h`, `120i`, `120j` | — | new, red first | hyphen tag, expanded body, message |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1, T2 | 3m | `bash evals/run.sh` |

- **Estimated wall-clock**: ~3m (+ main check)
- **Sequential sum**: 6m
- **Estimated tokens**: ~1.4M

T2 touches `agents/implementer.md`, `agents/verifier.md` and
`skills/sdlc/SKILL.md`, which `agent-turn-budgets` (T4, T5) and
`report-hook-tdd` (T2) also touch: run it after them, never in the same wave.

## Test strategy

Red first for `120a` (today it is blocked) and for every text case. `120b`
and `120c` guard the bypass and are green before and after; they must stay
green through T1.

## Verification commands

```
bash -n hooks/production-gate.sh
bash evals/run.sh
```

## Implementation risks

- Heredoc parsing in awk can miss quoted or indented terminators (`<<-`):
  scenarios for both.
- A command with two heredocs: each body dropped independently.

## Outside this plan

No permission changes in `settings.template.json` (D9). Release, verification
and review: `plan-template-gates` T6–T10.

## Review

Covered by the review of all four slugs: see `../plan-template-gates/plan.md`, *Review*.

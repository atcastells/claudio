# Plan: test-time

Done means: every requirement of `spec.md` has its eval, seen red first, and
`bash evals/run.sh` is green except the pre-existing
`run.sh: EVALS_RESULT_JSON writes the result file` failure seen on the
baseline run (same result before any change).

Stop and ask if: a budget eval (65, 65b, 79) would need raising.

| Task | Requirement | Files | Test | Status |
|------|-------------|-------|------|--------|
| T1 | R1, R2, R3 | `agents/implementer.md`, `agents/verifier.md`, `hooks/subagent-report-check.sh`, report cases and scripts | cases 120a–120f | done |
| T2 | R4, R5 | `skills/sdlc/SKILL.md`, `agents/scout.md`, cases 77, 86b | cases 120g–120i | done |
| T3 | R6 | `skills/repo-setup/SKILL.md`, `skills/repo-setup/templates/CLAUDE.md`, `migrations/3.1.0.md` | cases 120j–120k | done |
| T4 | R7 | `hooks/evals-on-config-change.sh`, `evals/run.sh` | cases 120l–120m | done |
| T5 | release | `VERSION`, `CHANGELOG.md` | full suite | done |

Git is reserved for the developer: the change is left in the working tree.

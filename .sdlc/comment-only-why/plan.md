# Plan: Comments only in narrow cases, never to record a deviation

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-11-16); rolled back — built on a
  stale 2.0.0 clone. Redo on 3.0.0: core is already at 75 lines, so the
  wording must be re-approved. Eval parked in this folder.

## Done means

- `bash evals/run.sh` → FAIL 0, including `14c`, `14b`, `65`.
- `WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh` → FAIL 0 (`65b`).
- `bash scripts/check-public.sh` → exit 0.

## Stop and ask if

- The new wording pushes the core over 75 lines or the installed file over 110.
- Any existing eval depends on the old wording of the Style paragraph.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Status |
|---|------|-------|---------------------|--------------------|--------|
| T1 | Add eval `14c`, run it, see it red | `evals/cases/14c-claude-md-no-deviation-comments.json` | `bash evals/run.sh` shows `14c` FAIL | R1, R2 | done (red seen: 95/1) |
| T2 | Rewrite the Style paragraph | `global/CLAUDE.md` | `14c`, `14b`, `65`, `65b` green | R1–R4 | done |
| T3 | Bump `VERSION` and add a `CHANGELOG.md` entry (level per its criteria) | `VERSION`, `CHANGELOG.md` | Version cases green | — | done (2.1.0, MINOR) |

## Verification commands

```
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh
bash scripts/check-public.sh
```

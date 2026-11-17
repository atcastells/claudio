# Intent: Comments only in narrow cases, never to record a deviation

- **Originator**: maintainer
- **Date**: 2026-11-16
- **Status**: implemented
- **Slug**: comment-only-why

## The problem, in the originator's words

> "Code comments open the door to deviating from the plan and leaving the
> deviation commented. I want a rule that only allows comments in very
> concrete cases, and never to try to deviate."

## Who it affects

- Engineers who review agent diffs: a deviation hidden in a comment
  (`// simplified for now`, `// TODO`, `// instead of X we do Y`) passes as
  code instead of reaching them as a decision.
- The agent itself: today a comment is a way to decide alone and move on
  instead of stopping.

## What happens if we do nothing

The current rule ("Comments only when the logic is not obvious") does not say
what a comment may contain. Deviations from `plan.md` keep landing in code
comments, outside the plan's status column and outside the stop-and-ask flow.

## What was already known

| Fact | Where |
|------|-------|
| Current comment rule | `global/CLAUDE.md:9`, `skills/repo-setup/templates/CLAUDE.md:20` |
| No hook inspects added comments; `test-guard` only blocks commented-out tests | `hooks/test-guard.sh:37` |
| The implementer reports estimate deviations, not plan deviations | installed `agents/implementer.md` |
| Research: wrong or misleading comments hurt LLM output; correct ones help a little. No evidence that banning all comments helps | arXiv 2609.09242, arXiv 2404.03114 |

## How we will know it is solved

- The core rules list the only cases where a comment is allowed.
- The core rules forbid recording a deviation, shortcut or pending work in a
  comment and send it to stop-and-report instead.
- An eval checks the rule is present; core budget (≤ 75 lines) still holds.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-16 | Ban all comments? | No: a narrow allow-list plus a ban on deviation comments | maintainer |
| 2026-11-16 | Rule or deterministic hook? | Rule only, for now | maintainer |

## Open questions

- Also update `skills/repo-setup/templates/CLAUDE.md` (needs a migration)?

---
Next stage: Design reads this file and writes `spec.md`.

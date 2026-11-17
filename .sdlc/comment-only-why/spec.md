# Spec: Comments only in narrow cases, never to record a deviation

- **Derived from**: `intent.md`
- **Status**: implemented

## Requirements

| # | Requirement | Acceptance criterion |
|---|-------------|----------------------|
| R1 | The core allows a comment only for what the code cannot say: a non-obvious why, an external constraint, a linked ticket | New eval `14c` finds the phrase in `global/CLAUDE.md` |
| R2 | The core forbids commenting a deviation from the plan, a shortcut or pending work, and sends it to stop-and-report | Same eval `14c`, seen red before the edit |
| R3 | Existing rules in the Style paragraph keep their wording | Case `14b` ("No mentions of AI") green |
| R4 | Core stays within budget | Cases `65`, `65b` green |

## Design

`global/CLAUDE.md`, Style paragraph (3 lines → 5; core 73 → 75):

```
Code, identifiers and commit messages in English. Comment only what the code
cannot say: a non-obvious why, an external constraint, a linked ticket.
Never comment a deviation from the plan, a shortcut or pending work: stop
and report it. No emojis in code or comments. No mentions of AI in commits,
code or comments.
```

Eval `evals/cases/14c-claude-md-no-deviation-comments.json`, kind
`file_contains`, `contains`: `Never comment a deviation from the plan` (kept on
one line so the match does not depend on wrapping).

## Out of scope

- A deterministic hook on added comments (possible follow-up).
- The project template in `skills/repo-setup/templates/CLAUDE.md`, unless the
  engineer decides otherwise (it requires `migrations/<version>.md`).

---
Next stage: Plan reads this file and writes `plan.md`.

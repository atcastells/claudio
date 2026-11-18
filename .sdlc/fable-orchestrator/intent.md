# Intent: Fable orchestrates, Opus executes, they talk through artifacts

- **Originator**: maintainer
- **Date**: 2026-11-18
- **Status**: approved by the originator in conversation (2026-11-18)
- **Slug**: fable-orchestrator

## The problem, in the originator's words

> "Que Fable solo orquestre tareas a Opus, que Opus solo se comunique con
> Fable mediante artifacts. Si un artifact es útil para el proyecto Fable lo
> deja como persistente, si no se usa para la comunicación y decisión."
> "Fable lanza Sonnet y Haiku... eso lo debe hacer Opus."
> "La idea es que el artifact que vuelve a Fable sea el más adecuado para que
> pueda tomar su decisión a nivel de qué tipo de datos son y coste de
> generarlo."
> (2026-11-18)

## Facts (session profile, 439 sessions, June–November 2026)

- Fable 5.2 as the main model: 3.1 M cost-weighted tokens per hour against
  9.3 M for Opus 5.5; 8.7 s per turn against 6.1 s. Mixed sessions led by
  Fable 5.2 spent 4.2 M weighted tokens per agent hour (main + subagents)
  against 8.0 M for those led by Opus 5.5 (6 sessions against 114:
  a correlation, not proof).
- Fable 5.2 as the main model still spent 19% of its time on tests and
  repeated 69% of its runs with no edit in between.
- Prices per million tokens (input / output): Fable 5.2 8 / 40, Opus 5.5
  4 / 20, Sonnet 5.5 2 / 10, Haiku 5.5 0.10 / 0.50.
- Claude Code lets a subagent launch its own, up to three levels below the
  main conversation (2.1.219 and later); in an interactive session only the
  first level's summary returns to the main conversation.

## How we will know it is solved

After 3 to 5 large mixed sessions in the new mode, compared with similar
sessions in the current one: cost per closed task equal or lower; wall-clock
per wave at most 20% higher; Fable spends under 15% of its tokens reading
artifacts; at most one task per session reopened because of a wrong summary;
no discarded artifact had to be recovered; the main session runs no tests.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-18 | Default mode or opt-in | Opt-in mode (`/orchestrate`), measured before it becomes a default | originator |
| 2026-11-18 | Who launches Sonnet and Haiku | Opus, as nested subagents; Fable talks only to Opus | originator |
| 2026-11-18 | What the artifact back to Fable carries | The type of data and the measured cost of producing it, so Fable decides without opening the body | originator |

## Gaps

- The "expensive to regenerate" threshold (starting value: over $0.50 or
  over 10 agent minutes) has no data behind it yet.

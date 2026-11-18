---
task: <slug>/T<n>
from: integrator | main
kind: brief | result | finding | decision-request | exploration
result: done | blocked | needs-decision
data: decision | repo-knowledge | evidence | measurement | exploration | raw-output
cost:
regen: "<command that reproduces it>" | not-reproducible
persist: propose | no
files: [<files touched>]
evidence: [<file:line>, <log path>]
---
<!-- Orchestrate mode. Lives in .sdlc/<slug>/work/ (git-ignored). The main
session reads the frontmatter and the summary only. cost is written by the
task-actuals hook (tokens_k, usd, minutes, agents), never by the model. -->

## Summary

<at most 15 lines, shaped for the decision the main session has to take:
five lines and the evidence for a result, a table of options for a
decision-request. Every claim cites file:line or a log.>

## Decision needed

<only for needs-decision: the options, what changes with each, your
recommendation. Delete the section otherwise.>

## Detail

<what the main session opens only to verify: reasoning, alternatives
tried, outputs. No personal or sensitive business data: its shape only.>

---
id: ADR-010
title: Durable execution via journal+replay
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-010: Durable execution via journal+replay

## Status

accepted — 2026-05-31

## Context

Workflow execution must survive crashes. Nodes may run for minutes (LLM calls, sandbox execution). The design required choosing between: (a) message-queue / actor model, (b) durable execution via journal+replay, (c) simple fire-and-forget with manual retry.

## Decision

Durable execution: every workflow step writes a journal entry before executing. On crash-restart, the executor replays from the last committed journal entry. This is the sagas pattern applied to workflow nodes.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Message-queue / actor model | Requires external broker (Kafka, NATS) or in-process actor framework; adds distributed systems complexity for a local app |
| Fire-and-forget + manual retry | No crash safety; user must manually re-run failed workflows |
| Event sourcing (full) | Overkill; journal+replay gives same crash safety at lower complexity |

## Consequences

**Positive:**
- Workflow survives process crashes
- Reproducible: same journal → same result
- No external dependencies (journal is SQLite rows)

**Negative / Trade-offs:**
- Node implementations must be idempotent (replay safety)
- Journal must be pruned (rows accumulate over time)
- More complex executor code

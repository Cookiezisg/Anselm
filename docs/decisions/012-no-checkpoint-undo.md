---
id: ADR-012
title: No Checkpoint/Undo feature
status: accepted
date: 2026-05-27
supersedes:
superseded-by:
---

# ADR-012: No Checkpoint/Undo feature

## Status

accepted — 2026-05-27

## Context

An earlier design spec (§10.1) planned a Checkpoint/Undo system: users could snapshot agent state mid-run and roll back. This would require dedicated infrastructure for state serialization and storage.

## Decision

Drop Checkpoint/Undo. Trinity (function/handler/workflow) has versioning at the entity level. Filesystem operations can be undone via git. The use cases do not justify dedicated checkpoint infrastructure for a single-user local app.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Full checkpoint infrastructure | Dedicated tables, snapshot serialization, storage management — all overhead for a single-user app |
| In-memory checkpoints only | Lost on crash; defeats the purpose |

## Consequences

**Positive:**
- No checkpoint table, no snapshot serialization code
- Simpler agent state model

**Negative / Trade-offs:**
- Agent mid-run state cannot be rolled back (must re-run from beginning)
- Users who wanted undo must use git or re-run workflows

---
id: ADR-019
title: A step's current state is its highest-generation record-once event
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-019: replay-reset — current state = highest-generation record-once event

## Status

accepted — 2026-05-31

## Context

`:replay` of a failed flowrun bumps `generation` (17 §4). The review found the model under-specified: the replay copy-hit key (`(flowrun_id, node_id, iteration_key)`, no generation — 00:185) and the record-once write key (includes generation — 17:89) were never reconciled, and the failures-query predicate ("highest generation" as a flowrun-level scalar vs per-step coverage) was undefined. Without reconciliation, a succeeded step could be re-stamped on replay (duplicate) or stale failures could be reported.

## Decision

**One principle: the current state of a step `(flowrun_id, node_id, iteration_key)` is its highest-generation record-once event.** Everything derives from it:
- **Replay copy-hit:** look up the highest-generation result event for the step. `node_completed` → copy the result (no re-run, no re-write). `node_failed` as highest **and** the current replay generation is newer → re-run + write `node_completed@curGen`. None → first run.
- **`GET /flowruns/{id}/failures`:** the steps whose highest-generation event is `node_failed` (not superseded by a later `node_completed`).

This makes copy-hit generation-aware (so it never re-stamps a succeeded step) and consistent with the generation-bearing write key (ADR-018).

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Generation-agnostic copy-hit | Would let a succeeded step be re-stamped on a new generation → duplicate result events. |
| Flowrun-level scalar "highest generation" for the failures query | Wrong granularity; failure status is per-step `(node, iteration_key)`, not per-run. |

## Consequences

**Positive:**
- Copy-hit, record-once write, and the failures query all derive from one rule.
- `:replay` re-runs only the steps still failing at the latest generation.

**Negative / Trade-offs:**
- Queries aggregate by `(node_id, iteration_key)` taking `MAX(generation)` (one indexed query; index on `(flowrun_id, node_id, iteration_key, generation)`).

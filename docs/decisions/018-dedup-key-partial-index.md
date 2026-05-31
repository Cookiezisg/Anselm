---
id: ADR-018
title: One dedup_key column + one partial unique index for record-once
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-018: record-once via a computed dedup_key column + one partial unique index

## Status

accepted — 2026-05-31

## Context

`17` §1 declared a blanket `UNIQUE(flowrun_id, node_id, iteration_key, type, generation)` for record-once events, while §2 requires `node_started`/`node_failed` to be **append-many** (the retry trail). They share that key tuple, so a literal full index drops the 2nd retry row. The author flagged this exact bug in `16:41` ("套所有 type … 与 retry 多次 node_failed 撞键") but the fix never landed in §1. Separately, agent sub-steps need `turn`/`tool_call_id` in the key, stated inconsistently across docs. And a naive nullable `(turn, tool_call_id)` in a unique index hits SQLite's rule that **NULLs are distinct in a UNIQUE index** — two normal `node_completed` rows with NULL turn/tool_call_id would not collide, breaking record-once.

## Decision

Add a computed `dedup_key TEXT NOT NULL` column to `flowrun_events`, filled by the app at write time:
- scalar record-once: `<node_id>|<iteration_key>|<type>|<generation>`
- agent sub-step: `<node_id>|<iteration_key>|<type>|<generation>|<turn>|<tool_call_id>`
- attempt types (`node_started`/`node_failed`): `""`

One **partial** unique index in `schema_extras.go` (D7): `CREATE UNIQUE INDEX … ON flowrun_events(flowrun_id, dedup_key) WHERE type NOT IN ('node_started','node_failed')`. `AppendEvent` is a plain INSERT; a unique violation means already-recorded → return the existing row (compare-and-insert / first-wins). Attempt types append freely (excluded by the WHERE). The descriptive columns (`node_id`, `type`, `generation`, `turn`, `tool_call_id`, …) stay for queries.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Blanket `UNIQUE(…, type, generation)` over all rows | Drops the `node_failed` retry trail (the §1-vs-§2 contradiction). |
| Nullable `(turn, tool_call_id)` columns inside the unique index | SQLite NULL-distinct rule → record-once breaks for normal events. |
| Two separate partial indexes (scalar + agent) | More moving parts than one `dedup_key`; one computed key is DRY. |

## Consequences

**Positive:**
- One NULL-safe index unifies normal + agent-step + attempt rules; retry trail preserved.
- record-once dedup is a single, testable code path (one `dedupKey()` helper).

**Negative / Trade-offs:**
- The app must compute `dedup_key` consistently — centralized in one helper to avoid divergence.

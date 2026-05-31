---
id: ADR-017
title: iteration_key = deterministic loop back-edge traversal ordinal
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-017: iteration_key is the deterministic loop back-edge traversal ordinal

## Status

accepted — 2026-05-31

## Context

`iteration_key` is the replay/dedup key that distinguishes the same node executed on different loop iterations. Six docs called it "节点+第几轮 / 内部重放键" but **none defined how "第几轮" is computed** — the geology under all record-once dedup was undefined (2026-05-31 review, major). For replay to be correct the key must be deterministic and recomputed identically on every replay.

## Decision

`iteration_key` = the **back-edge traversal ordinal of the enclosing structured loop header** at the moment the interpreter activates the node (`0` for nodes outside any loop). The interpreter maintains a per-loop-header counter that increments each time the deterministic walk traverses the loop's back-edge; the value tagged onto a node activation is that counter. It is **one-dimensional** because nested structured loops are rejected at accept (C6). It is a **pure function of the deterministic walk position** — never a stored mutable counter — so replay recomputes the identical value (loop continuation is a journaled `branch_taken`, so replay performs the same number of iterations).

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Store a per-node iteration counter in the journal | Redundant (derivable) + an extra mutable write that could drift from the walk. |
| Allow nested loops with composite (multi-dimensional) keys | Rejected at accept for reducibility; 1-D key keeps replay simple. Nested iteration → forge function (A-7). |

## Consequences

**Positive:**
- Dedup key is derivable and stable by construction; cannot drift.
- No journal column or counter to maintain across crashes.

**Negative / Trade-offs:**
- The interpreter must track per-loop-header back-edge counts during the walk (small state, rebuilt each replay).
- Nested iteration must be pushed into forge functions.

---
id: ADR-022
title: Trigger retry is schedule-level, with a durable consecutive-failure counter
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-022: trigger retry lives on trigger_schedules, not the node

## Status

accepted — 2026-05-31

## Context

A trigger is the program entry, not an in-flowrun activity (A-3), so its failure happens in the listener / inbox / pre-flowrun polling layer. `01` put trigger retry on the trigger node config; `07` said it lives in `trigger_schedules` / "not in the node inspector" — but **neither `trigger_schedules` nor the trigger node config had any retry column**, and there was no durable counter to drive "trigger retry exhausted → workflow auto-deactivate". Temporal models schedule failure at the schedule level (pause-on-failure), not inside the execution.

## Decision

Trigger-layer retry is **schedule-level**. Add to `trigger_schedules`: `retry_policy` (JSON: `maxAttempts`, `backoff`) and `consecutive_failures INT`. A failed firing increments `consecutive_failures`; a successful one resets it to 0; when `consecutive_failures ≥ retry_policy.maxAttempts` the workflow auto-deactivates (drain) + sets `needs_attention` + notifies. Add `attention_reason` and `last_action_by` columns to `workflows` (written by the deactivate path; `last_action_by = "system"` distinguishes auto-deactivate from a user action). Node-level `retry` stays **only** on tool nodes (in-flowrun activity retry); agent nodes take defaults (no knob); triggers have no node-level retry.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Trigger retry on the trigger node config | A trigger is not an in-flowrun activity; node retry is flowrun-internal (A-3). |
| Count failures by scanning `trigger_firings` | A counter is O(1) and survives firing GC; scanning is O(n) and breaks once old firings are pruned. |

## Consequences

**Positive:**
- A durable counter drives honest auto-deactivate; matches Temporal Schedules pause-on-failure.

**Negative / Trade-offs:**
- `trigger_schedules` gains 2 columns; `workflows` gains 2; the dispatcher updates the counter on every firing outcome.

---
id: ADR-016
title: Durable interpreter replaces topo-walk scheduler (engine shape)
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-016: Durable interpreter replaces topo-walk scheduler

## Status

accepted — 2026-05-31

## Context

ADR-010 chose durable execution. The implementation must relate the new engine to the existing `app/scheduler`: a 14-node topological-walk executor (`buildTopo` → `driveLoop` → `runReadyLoop` → `dispatchBatch`) that snapshots mid-run state into `FlowRun.PausedState` and writes per-dispatch `flowrun_nodes` rows. The revamp is 5 nodes, journal-as-truth, CEL conditions, active-branch join. How to get from here to there?

## Decision

**Refactor in place onto the durable spine.** Reshape `app/scheduler` from topo-walk into a structural durable interpreter (journal + deterministic replay); collapse the 14 `dispatch_*.go` handlers into 5-node activities (`function`/`handler`/`mcp`/`agent`→`tool`; `llm`→`agent`; `condition`→`case`; `loop`/`parallel`/`variable`/`wait`/`http`→control-flow / gate / forge-function); replace `app/workflow/expression.go` text/template with CEL; amend the `workflow` graph model (14→5 node kinds, typed config per 17 §7); build new journal/approval/trigger stores; delete `PausedState` + `flowrun_nodes`. Each milestone leaves the system runnable + pipeline-tested.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Greenfield engine package, run both, big-bang cutover | Pre-launch, no data to preserve (CANON-MIGRATION clears & rebuilds) → no reason for two engines; big-bang violates "each phase delivers value" (principle #1). |
| Bolt journaling under the existing topo-walk | Keeps the message-queue-era abstractions the revamp killed (per-node rows, PausedState, in-degree topo). The 5-node collapse + CEL + active-branch join + journal-as-truth are the point. |

## Consequences

**Positive:**
- Incremental; the `Router.Dispatch` interface is preserved so dispatcher blast radius is bounded.
- Authoring-time code (`validate`/`apply`/`capability_check`) and trigger listeners stay largely intact.

**Negative / Trade-offs:**
- M2/M3 touch the most code (interpreter + node collapse + CEL).
- Old scheduler tests (`state`/`pause`/`retry`) are rewritten, not migrated.

---
id: ADR-020
title: pinned_callables is the transitive forge-callable closure at StartRun
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-020: pin the transitive callable closure at flowrun start

## Status

accepted — 2026-05-31

## Context

A-5 pins callable versions at flowrun start (Temporal versioning) so an in-flight run never drifts when someone edits a referenced entity. But the **closure depth was undefined** — the review's lone blocker. An `agent` node references an `agent` entity (`ag_`) which itself mounts functions/handlers; a `tool` node can call `ag_` with its own `fn_/hd_` closure. Does pinning the agent pin its mounted callables? And `02:32` still said agent refs resolve to "永远 active version, 无 pin" (the pre-A-5 model), directly contradicting A-5.

## Decision

At `StartRun`, resolve `pinned_callables` as the **transitive forge-callable closure**: walk the graph's refs (`tool.callable`, `agent.agentRef`) plus, recursively, each referenced entity's own callable dependencies (an agent's mounted `fn_`/`hd_`; handler methods) to a fixed point; snapshot every `(callable_id → version_id)` reached. The closure is **shallow** — depth ≤ 2: `workflow → {fn, hd, agent} → {agent's fn, hd}`; agents never call agents (employee thinking), and a workflow is not a callable. The entire flowrun lifecycle (crash-replay, parked-approval resume, continue-as-new) uses this one snapshot. Fix `02:32` to state A-5 pinning.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Pin only top-level refs | In-flight edits to deeply-mounted callables would drift → non-determinism — the exact failure A-5 exists to prevent. |
| Resolve `active` at call time | The pre-A-5 model; rejected by A-5 (long-running / parked runs drift). |

## Consequences

**Positive:**
- In-flight runs never drift at any callable depth; replay is deterministic w.r.t. callable versions.

**Negative / Trade-offs:**
- `StartRun` performs a bounded graph + entity walk to build the snapshot (depth ≤ 2, cheap).
- The pinned set can exceed the directly-referenced set; stored as JSON on `flowruns.pinned_callables`.

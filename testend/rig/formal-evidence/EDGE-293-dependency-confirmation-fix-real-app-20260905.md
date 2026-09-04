---
edge: EDGE-293
title: dependency delete confirmation names affected agents
date: 2026-09-05
kind: stop-and-fix validation
status: fixed-and-reverified
---

## Finding

The first real-App pass deleted a function mounted by three Agents, but its confirmation dialog
only said that the function would be removed from the active catalog. The backend correctly emitted
one aggregated `relation.dependency_broken` notification and the remaining Agents became unhealthy,
but the irreversible action did not explain that impact before confirmation. This was a product
discoverability and safety defect, not a backend deletion failure.

## Fix

`frontend/lib/features/entities/ui/entity_rail.dart` now reads the current `GET /api/v1/relgraph`
snapshot before every entity deletion, summarizes up to three incoming `equip/link` dependents, and
uses a generic impact warning for non-Trigger entities. Trigger retains its specialized listener
warning. A failed relationship read still blocks the irreversible action. English and Chinese
strings, the Entities reference doc, and a widget regression test were updated together.

## Real-App recheck

Session: `/private/tmp/anselm-rig-formal-20260903-53d/sessions/20260905-000513`

In the real App, a fresh function `edge293_ui_fix_fn` was mounted by three fresh Agents. The
Computer Use accessibility tree and bound-window recording showed this exact confirmation copy:

> “edge293_ui_fix_fn” is used by edge293_ui_agent_c, edge293_ui_agent_b, edge293_ui_agent_a. Deleting it will leave those entities needing repair. This can't be undone.

The dialog was then cancelled; no second-pass deletion was performed. The fixture was removed by
the terminal cleanup path after the observation. This file proves the repaired confirmation surface,
not a new full L2-L5 deletion judgment; the prior deletion truth remains in the earlier Edge-293
SSE/API evidence.

## Verification

- `mise exec -- flutter test test/features/entities/ui/entity_rail_test.dart` — 33 tests passed.
- `make gen` — slang and build_runner completed with no generated drift.
- `mise exec -- dart format ...` — 5 changed/generated files, 0 formatting changes.
- `rig-check.sh` passed after the session-specific AXTree review was added; all five channels were
  attributed before teardown.

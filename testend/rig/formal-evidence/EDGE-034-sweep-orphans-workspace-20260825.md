# EDGE-034 · 硬崩溃孤儿回合清扫

## Verification

The boot reconciliation path was exercised with crash-shaped `pending` and `streaming`
assistant rows. `SweepOrphans` changed both to `cancelled` with
`StopReasonCancelled`, changed their streaming blocks to `cancelled`, and left an identical
streaming row in a different workspace untouched. This matches the real boot wiring, which calls
the sweep once per detached workspace context.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestSweepOrphansCancelsNonTerminalTurnsPerWorkspace' -count=1       PASS
go test -race ./internal/app/chat -run 'TestSweepOrphansCancelsNonTerminalTurnsPerWorkspace' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: pending/streaming orphan messages and streaming blocks are cancelled, with workspace isolation; measurement law `measure:edge034-sweep-orphans-workspace`.
- L2 `na`: this round did not perform a separate kill-9/restart managed-gateway five-channel session; the deterministic store/boot path is covered by the focused test.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is boot reconciliation and data-integrity behavior, with no independent visual geometry, motion, copy, or layout surface.
- L5 `na`: orphan sweeping is automatic recovery, not a distinct user navigation entry; user-visible recovery is covered by chat/restart journeys.

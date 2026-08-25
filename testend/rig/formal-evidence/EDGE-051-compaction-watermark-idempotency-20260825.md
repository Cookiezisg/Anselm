# EDGE-051 · 压缩水位幂等键

## Verification

The context manager test simulated a process crash immediately after `SetSummary` durably wrote
the new summary and watermark, before block archive roles and the compaction anchor were written.
The recovery service then reran compaction against the same thread. It treated the watermark as
the source of truth, skipped the already-covered block, made no second utility summary call, and
did not duplicate archive or anchor work. The still-hot block in the fixture demonstrates that
the idempotency guarantee does not depend on the archive backstop having completed.

Focused verification passed:

```text
go test ./internal/app/contextmgr -run '^TestSummarize_WatermarkMakesCrashBetweenWritesIdempotent$' -count=1 PASS
go test -race ./internal/app/contextmgr -run '^TestSummarize_WatermarkMakesCrashBetweenWritesIdempotent$' -count=1 PASS
go test ./internal/app/contextmgr -count=1 PASS
```

## Five-level applicability

- L1 `pass`: a crash between durable summary write and archive/anchor writes does not double-fold
  history; measurement law `measure:edge051-compaction-watermark-idempotency`.
- L2 `na`: this edge was verified through the context-manager persistence seam, not a separate
  managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is compaction durability and idempotency semantics, with no independent visual
  geometry, motion, or layout surface.
- L5 `na`: compaction is an existing background behavior and introduces no new navigation or
  discovery entry in this edge.

# EDGE-055 · 最近 2 条 message 的 durable 底线

## Verification

The real context-manager entry point received exactly two durable messages, both far above the
compaction trigger estimate. Persistent compaction honored the two-message verbatim floor: no
summary write, archive update, compaction anchor, or demotion occurred, and both messages stayed
hot. Separately, the continuation-checkpoint projection test passed, proving the loop can still
reduce an oversized prompt in memory without weakening the durable recent-message floor.

Focused verification passed:

```text
go test ./internal/app/contextmgr -run '^TestMaybeCompact_TwoLongMessagesHonorDurableRecentFloor$' -count=1 PASS
go test -race ./internal/app/contextmgr -run '^TestMaybeCompact_TwoLongMessagesHonorDurableRecentFloor$' -count=1 PASS
go test ./internal/app/contextcheckpoint -run '^TestCompactOmitsRawMediaAndKeepsCompleteRecentToolGroups$' -count=1 PASS
go test ./internal/app/contextmgr -count=1 PASS
```

## Five-level applicability

- L1 `pass`: durable compaction never crosses the two-message verbatim floor while prompt-level
  checkpointing remains available; measurement law `measure:edge055-recent-two-durable-floor`.
- L2 `na`: this edge was verified through the real context-manager/checkpoint services, not a
  separate managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is context retention and protocol checkpoint semantics, with no independent visual
  geometry, motion, or layout surface.
- L5 `na`: checkpointing is an existing prompt projection behavior and introduces no new navigation
  or discovery entry in this edge.

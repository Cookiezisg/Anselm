# EDGE-050 · fork 血缘源被删

## Verification

The real SQLite conversation service created a source thread, forked it with a cut-message
lineage pair, and then soft-deleted the source. The source GET became `ErrNotFound`; the fork
remained readable and its `ForkedFromConversationID` and `ForkedFromMessageID` columns retained
the historical source/message IDs. The visible conversation list contained only the surviving
fork. No foreign-key cascade or lineage rewrite occurred.

Focused verification passed:

```text
go test ./internal/app/conversation -run '^TestDelete_SourceAfterForkLeavesForkLineageAsHistoricalPointers$' -count=1 PASS
go test -race ./internal/app/conversation -run '^TestDelete_SourceAfterForkLeavesForkLineageAsHistoricalPointers$' -count=1 PASS
go test ./internal/app/conversation -count=1 PASS
```

## Five-level applicability

- L1 `pass`: deleting a fork source does not delete the fork or falsify its durable lineage;
  measurement law `measure:edge050-fork-source-deleted`.
- L2 `na`: this edge was verified through the real conversation persistence/service boundary,
  not a separate managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is deletion and historical-reference semantics, with no independent visual
  geometry, motion, or layout surface.
- L5 `na`: the existing conversation rail has no new discovery path in this deletion branch.

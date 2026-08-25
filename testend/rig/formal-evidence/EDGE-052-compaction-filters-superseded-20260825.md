# EDGE-052 · 压缩读过滤被取代回合

## Verification

The real compaction entry point received a thread containing an old assistant answer with
`superseded_by` pointing to the current answer. The current answer was the oldest non-protected
turn in the compaction window. The utility summary request contained the current answer and did
not contain the superseded prose; the new watermark advanced through the current answer's block.
This proves compaction uses the same current-version projection as the LLM and cannot re-inject an
old retry answer into every later prompt through the running summary.

Focused verification passed:

```text
go test ./internal/app/contextmgr -run '^TestMaybeCompact_DropsSupersededVersionsBeforeSummary$' -count=1 PASS
go test -race ./internal/app/contextmgr -run '^TestMaybeCompact_DropsSupersededVersionsBeforeSummary$' -count=1 PASS
go test ./internal/app/contextmgr -count=1 PASS
```

## Five-level applicability

- L1 `pass`: compaction excludes superseded versions before building the summary prompt;
  measurement law `measure:edge052-compaction-filters-superseded`.
- L2 `na`: this edge was verified through the real context-manager compaction entry point, not a
  separate managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is transcript projection and summary durability semantics, with no independent
  visual geometry, motion, or layout surface.
- L5 `na`: compaction is an existing background behavior and introduces no new navigation or
  discovery entry in this edge.

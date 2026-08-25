# EDGE-054 · 附件跨压缩水位

## Verification

The real `MaybeCompact` path received an old user turn carrying a native attachment reference.
Because native media is not represented by the text byte estimate, the turn was forced across the
compaction watermark. The summary input retained the opaque attachment ID, the block was archived,
and the durable contract therefore leaves a later agent a truthful route to `read_attachment`
instead of inventing media details or replaying unbounded native content.

Focused verification passed:

```text
go test ./internal/app/contextmgr -run '^TestMaybeCompact_OldAttachmentForcesTraceableSummary$' -count=1 PASS
go test -race ./internal/app/contextmgr -run '^TestMaybeCompact_OldAttachmentForcesTraceableSummary$' -count=1 PASS
go test ./internal/app/contextmgr -count=1 PASS
```

## Five-level applicability

- L1 `pass`: old native attachment turns retain an opaque ID across the summary watermark and are
  archived rather than silently replayed; measurement law `measure:edge054-attachment-across-compaction-watermark`.
- L2 `na`: this edge was verified through the real context-manager compaction entry point, not a
  separate managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is attachment grounding and compaction durability semantics, with no independent
  visual geometry, motion, or layout surface.
- L5 `na`: the existing attachment-read capability is not a new navigation or discovery entry in
  this compaction branch.

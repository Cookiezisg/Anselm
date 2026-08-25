# EDGE-048 · fork 版本指针 remap

## Verification

The real SQLite fork fixture seeded a retried thread with an older assistant whose
`superseded_by` points to the newer assistant and a newer assistant whose `attrs.retryOf`
points back to the older one. A complete fork copied both rows and remapped both pointers to
the fork's own message IDs; the fork's LLM projection exposed only the current answer.

The same fixture forked at the older version. The newer row fell outside the prefix, so the
older copied row retained an empty `superseded_by`, and every `retryOf` targeting outside the
window was dropped. No source message ID remained in either pointer.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestFork_(VersionChainRebasedIntoTheFork|CutAtAnOlderVersionLeavesItCurrent)$' -count=1 PASS
go test -race ./internal/app/chat -run 'TestFork_(VersionChainRebasedIntoTheFork|CutAtAnOlderVersionLeavesItCurrent)$' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: complete forks remap both directions of the version chain; prefix forks clear
  pointers whose targets are outside the copied window. Measurement law:
  `measure:edge048-fork-version-pointer-remap`.
- L2 `na`: this edge was verified through the real persistence/service boundary, not a separate
  managed-gateway five-channel session.
- L3 `na`: the focused and race tests provide no independent App frame, SSE tap, backend
  journal, or frontend console observation.
- L4 `na`: this is durable lineage and LLM projection semantics, with no independent visual
  geometry, motion, or layout surface.
- L5 `na`: fork is an existing chat action; no new navigation or discovery surface is introduced
  by this pointer-rewrite branch.

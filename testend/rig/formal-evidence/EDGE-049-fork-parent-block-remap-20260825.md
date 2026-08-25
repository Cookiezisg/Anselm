# EDGE-049 · fork parent_block_id 跨消息 remap

## Verification

The real messages store fixture seeded a tool-call block in one assistant message and a
subagent turn in a later message. The subagent's block-level `parent_block_id` and its
message-level `attrs.parentBlockId` both pointed at the earlier source block.

Forking through the subagent row pre-minted every destination block ID before inserting rows,
renumbered the copied block sequence contiguously, and remapped both parent pointers to the
fork's own tool-call block. The source tree remained unchanged, and no copied parent escaped
the destination block-ID set.

Focused verification passed:

```text
go test ./internal/app/chat -run '^TestFork_PrefixWindowSeqRenumberAndNestedRemap$' -count=1 PASS
go test -race ./internal/app/chat -run '^TestFork_PrefixWindowSeqRenumberAndNestedRemap$' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

## Five-level applicability

- L1 `pass`: a cross-message subagent tree remains attached to its fork-local parent block;
  measurement law `measure:edge049-fork-parent-block-remap`.
- L2 `na`: this edge was verified through the real messages persistence/service boundary, not a
  separate managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is durable block-tree topology, with no independent visual geometry, motion, or
  layout surface.
- L5 `na`: the existing fork action gains no new navigation or discovery entry from this branch.

# EDGE-053 · demote 只动 tool_result

## Verification

The real context-manager demotion path received a mixed long turn: one assistant message contained
an explanation text block plus sixteen tool-result blocks, and an older user message contained a
large pasted body. Demotion assigned the tool-result blocks to the hot/warm/cold recency tiers;
the user paste and assistant explanation stayed verbatim and hot, and neither non-tool block
entered a context-role update. This covers the single-long-ReAct-turn boundary rather than only
independent messages.

Focused verification passed:

```text
go test ./internal/app/contextmgr -run '^TestDemote_OnlyAgesToolResultsInsideLongMixedTurns$' -count=1 PASS
go test -race ./internal/app/contextmgr -run '^TestDemote_OnlyAgesToolResultsInsideLongMixedTurns$' -count=1 PASS
go test ./internal/app/contextmgr -count=1 PASS
```

## Five-level applicability

- L1 `pass`: demote ages only tool-result blocks and preserves user/assistant prose and large
  pastes; measurement law `measure:edge053-demote-only-tool-results`.
- L2 `na`: this edge was verified through the real context-manager demotion path, not a separate
  managed-gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is context-role projection semantics, with no independent visual geometry, motion,
  or layout surface.
- L5 `na`: demotion is an existing background behavior and introduces no new navigation or
  discovery entry in this edge.

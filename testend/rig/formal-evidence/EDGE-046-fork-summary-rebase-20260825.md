# EDGE-046 · fork summary 水位重定基

## Verification

The real messages store/fork service seeded a compacted source thread and cut the fork after the
summary watermark. The fork carried the summary and re-based `summaryCoversUpToSeq` onto the fork's
own block numbering, so the LLM projection hides exactly the blocks represented by that summary
and does not inherit source sequence coordinates.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestFork_SummaryCarriedWhenCutIsAtOrAfterWatermark' -count=1 PASS
go test -race ./internal/app/chat -run 'TestFork_SummaryCarriedWhenCutIsAtOrAfterWatermark' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

## Five-level applicability

- L1 `pass`: fork carries the truthful summary and re-bases its watermark to the fork's own sequence; measurement law `measure:edge046-fork-summary-rebase`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the compacted fork branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is forked transcript/LLM projection semantics, with no independent visual geometry, motion, or layout surface.
- L5 `na`: the branch is an option of the existing fork action, not a new navigation entry; fork discoverability is covered by chat/lineage journeys.

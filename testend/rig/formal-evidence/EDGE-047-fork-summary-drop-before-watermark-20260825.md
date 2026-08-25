# EDGE-047 · fork 切在水位之前不带 summary

## Verification

The real fork fixture seeded a source summary whose watermark covered blocks beyond the selected
cut. Forking before that watermark dropped both the summary and `summaryCoversUpToSeq`; the copied
prefix therefore did not receive a summary describing messages it did not contain. The fork's LLM
history remained exactly its own prefix.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestFork_SummaryDroppedWhenCutIsBeforeWatermark' -count=1 PASS
go test -race ./internal/app/chat -run 'TestFork_SummaryDroppedWhenCutIsBeforeWatermark' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

## Five-level applicability

- L1 `pass`: a pre-watermark fork carries neither misleading summary nor source watermark; measurement law `measure:edge047-fork-summary-drop-before-watermark`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the pre-watermark fork branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is forked transcript/LLM projection semantics, with no independent visual geometry, motion, or layout surface.
- L5 `na`: the branch is an option of the existing fork action, not a new navigation entry; fork discoverability is covered by chat/lineage journeys.

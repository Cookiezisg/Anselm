# EDGE-038 · :retry 重生成分支

## Verification

The empty retry payload takes the regenerate branch: it supersedes only the last assistant
answer, keeps the old answer and its blocks readable, writes no second user question, and runs
the replacement answer through the existing conversation queue. The durable thread therefore
retains the full version history while the LLM view sees one current answer.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_RegenerateSupersedesTheAnswerAndKeepsItReadable' -count=1       PASS
go test -race ./internal/app/chat -run 'TestRetry_RegenerateSupersedesTheAnswerAndKeepsItReadable' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: empty retry regenerates only the answer and preserves the durable/versioned thread; measurement law `measure:edge038-retry-regenerate`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the retry regeneration branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is versioned chat persistence/queue behavior, with no independent visual geometry, motion, or layout surface.
- L5 `na`: retry is a chat action rather than a distinct navigation entry; version feedback is covered by chat/version journeys.

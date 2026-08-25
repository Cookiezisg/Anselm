# EDGE-035 · 自动标题双预算

## Verification

The regression shrinks the slow auto-title budget and uses a provider that ignores cancellation
and consumes that full generation budget on every call. The generated title still persists because
the final local read/write receives a fresh five-second deadline from the detached lifecycle
context, rather than the exhausted generation context. This covers the real one-turn failure
mode where a good title would otherwise be lost permanently.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestAutoTitle_PersistSurvivesAGenerateThatAteTheBudget' -count=1       PASS
go test -race ./internal/app/chat -run 'TestAutoTitle_PersistSurvivesAGenerateThatAteTheBudget' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: title persistence survives an exhausted generation budget via a fresh persistence budget; measurement law `measure:edge035-autotitle-dual-budget`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the slow utility/title path.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this verifies async title timing and durable write behavior, with no independent visual geometry, motion, or typography judgment.
- L5 `na`: automatic title generation is background chat behavior, not a distinct navigation entry; title presentation is covered by chat-list journeys.

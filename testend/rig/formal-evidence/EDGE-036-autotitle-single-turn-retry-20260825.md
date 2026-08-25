# EDGE-036 · 只发生过一轮的对话标题丢失

## Verification

The original path attempted `SetAutoTitle` once and could leave a one-turn conversation as
`New chat` forever after a transient local write failure. This was treated as a product defect and
fixed: the generated title is retained and the detached lifecycle performs one bounded retry with
a fresh persistence budget. The focused regression fails its first persistence attempt, succeeds
on the second, receives the same title, and proves no second model generation is involved.

Full chat verification passed:

```text
go test ./internal/app/chat                                                               PASS
go test -race ./internal/app/chat                                                        PASS
TestAutoTitle_RetriesOneTransientPersistFailure                                            PASS
TestAutoTitle_PersistSurvivesAGenerateThatAteTheBudget                                    PASS
```

## Five-level applicability

- L1 `pass`: a transient first title-write failure is retried once and no longer permanently loses a one-turn title; measurement law `measure:edge036-autotitle-single-turn-retry`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for a one-turn storage failure/retry.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is background persistence recovery, with no independent visual geometry, motion, or typography judgment.
- L5 `na`: title persistence is background chat behavior, not a distinct navigation entry; title presentation is covered by chat-list journeys.

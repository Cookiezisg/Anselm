# EDGE-044 · retry 非终态尾巴

## Verification

Both retry gates were exercised. A real chat service with a blocking provider rejected retry while
the in-memory conversation queue was generating; a real messages store with a crash-shaped
`streaming` assistant tail rejected retry from durable state as well. Both paths returned
`STREAM_IN_PROGRESS`, appended no user or assistant row, and left the original thread unchanged.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_(RejectsInMemoryGeneratingTurn|RejectsWhatCannotBeRetried)$' -count=1 PASS
go test -race ./internal/app/chat -run 'TestRetry_(RejectsInMemoryGeneratingTurn|RejectsWhatCannotBeRetried)$' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

## Five-level applicability

- L1 `pass`: memory and durable non-terminal gates both reject retry without speculative writes; measurement law `measure:edge044-retry-nonterminal-tail`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the in-flight/crash-tail rejection branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is concurrency and durable-state gating, with no independent visual geometry, motion, or layout surface.
- L5 `na`: the rejection is an existing retry action state, not a new navigation entry; its user-facing explanation is covered by chat/recovery journeys.

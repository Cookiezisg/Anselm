# EDGE-040 · superseded 指针只挡 LLM 视图

## Verification

The real chat service over the real messages store performed a send, an empty-payload retry,
and one later ordinary turn. The old assistant row stayed addressable through all durable history
semantics: the ordinary newest-first pager reached it through its older cursor, `around=<oldId>`
returned it as the target and kept the current answer in the same window, and the window's
`newerCursor` reached the later turn through the `dir=newer` continuation. Only
`LoadThreadForLLM` removed the superseded answer; the current answer and user question remained.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_(SupersededRowsRemainInEveryHistoryRead|RegenerateSupersedesTheAnswerAndKeepsItReadable|EditResendReplacesBothHalves)$' -count=1 PASS
go test -race ./internal/app/chat -run 'TestRetry_SupersededRowsRemainInEveryHistoryRead' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

The first draft of the regression expected `around` to expose a `newerCursor` with only two
rows. That expectation was wrong: the current answer already filled the window. The test was
stopped and corrected by adding a real later turn, so `dir=newer` is exercised against an actual
continuation rather than a fabricated cursor.

## Five-level applicability

- L1 `pass`: ordinary paging, deep jump, newer continuation, and the LLM projection agree on the durable/versioned semantics; measurement law `measure:edge040-superseded-reads`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the retry history-read branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is durable history addressing and LLM projection behavior, with no independent visual geometry or motion surface.
- L5 `na`: the behavior is reached through existing chat history/retry navigation rather than a new product entry point; discoverability is covered by chat journeys.

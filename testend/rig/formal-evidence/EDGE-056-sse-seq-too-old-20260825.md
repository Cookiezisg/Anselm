# EDGE-056 · SSE 410 SEQ_TOO_OLD 重放

## Verification

The in-process stream Bus test filled a two-frame replay ring and verified that a cursor older
than the retained window returns the structured `ErrSeqTooOld`. The real HTTP/SSE scenario then
filled the production-sized replay ring beyond 256 durable frames and reconnected with an evicted
cursor. Transport returned `410 Gone` with `SEQ_TOO_OLD`, proving the client is directed to REST
refetch and resubscribe rather than silently continuing from an unknown point.

Focused verification passed:

```text
go test ./internal/infra/stream -run '^TestSubscribeSeqTooOld$' -count=1 PASS
go test -race ./internal/infra/stream -run '^TestSubscribeSeqTooOld$' -count=1 PASS
go test ./internal/infra/stream -count=1 PASS
go test ./scenarios -run '^TestPlatformR4_SSEProtocolFaces$' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: an evicted SSE replay cursor fails loudly as HTTP 410 `SEQ_TOO_OLD`; measurement law
  `measure:edge056-sse-seq-too-old`.
- L2 `pass`: the real HTTP/SSE scenario exercised the production endpoint and replay ring; the
  durable protocol result was observed through the test harness.
- L3 `na`: this protocol scenario did not include a separate Computer Use frame, frontend
  console, or LLM-wire product session.
- L4 `na`: this edge is transport recovery semantics, with no independent visual geometry, motion,
  or layout surface.
- L5 `na`: reconnect recovery is an existing stream behavior and introduces no new navigation or
  discovery entry.

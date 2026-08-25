# EDGE-033 · 关页不留 streaming 孤儿

## Verification

The focused chat-service regression starts a real provider stream, cancels the conversation while
the stream is in flight, waits for the durable `message_stop`, and reads the message back from the
store. The assistant row is `cancelled` with `StopReasonCancelled`, and the queue no longer reports
an active generation. `WriteFinalize` runs on a detached workspace/conversation context, so losing
the client request cannot strand the streaming row.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestCancelStreamingTurnFinalizesOnDetachedContext' -count=1       PASS
go test -race ./internal/app/chat -run 'TestCancelStreamingTurnFinalizesOnDetachedContext' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: a cancellation during provider streaming reaches durable cancelled state and emits message_stop; measurement law `measure:edge033-cancel-stream-finalize`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the client-close cancellation path.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is cancellation/finalization integrity, with no independent visual geometry, motion, copy, or layout surface.
- L5 `na`: closing or cancelling an active stream is an existing chat control, not a distinct navigation entry; its feedback is covered by chat/composer journeys.

# EDGE-043 · retry 写序中断留重复问句

## Verification

The real messages store was fault-injected only at `MarkSuperseded`, after edit-resend had
committed the replacement user row. The retry returned the injected write failure, while durable
history retained the original user, original answer, and edited user. Both question spellings and
the old answer remained in the LLM projection, proving the deliberate visible-duplicate/self-
correction boundary instead of silently erasing an exchange.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_WriteOrderLeavesBothQuestionsVisibleOnInterruption' -count=1 PASS
go test -race ./internal/app/chat -run 'TestRetry_WriteOrderLeavesBothQuestionsVisibleOnInterruption' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

## Five-level applicability

- L1 `pass`: the interrupted write order preserves both visible question versions and the prior answer; measurement law `measure:edge043-retry-write-order`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the mid-write crash window.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is append-only retry persistence and failure truth, with no independent visual geometry, motion, or layout surface.
- L5 `na`: the duplicate/self-correction state is reached through the existing retry action, not a new navigation entry; discoverability is covered by chat/recovery journeys.

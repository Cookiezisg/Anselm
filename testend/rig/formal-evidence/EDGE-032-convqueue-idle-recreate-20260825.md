# EDGE-032 · convQueue 5 分钟自毁后重建

## Verification

The production queue idle policy remains five minutes. The focused regression shortens that
policy only through an unexported service test seam, sends one complete turn, waits until the
idle queue is removed from the service registry, then sends again and proves the second turn
uses a new queue and reaches `message_stop`. The teardown and the enqueue path continue to share
`q.mu`, so a task cannot be stranded in the retired channel.

Focused verification passed:

```text
go test ./internal/app/chat                         PASS
go test -race ./internal/app/chat                  PASS
TestSendAfterIdleQueueTeardownRecreatesQueue       PASS
```

The implementation review also found and fixed the only issue exposed by the deterministic seam:
the two post-turn timer resets now reuse the selected timeout rather than the production constant,
so the test exercises the actual teardown/recreation path instead of timing out falsely.

## Five-level applicability

- L1 `pass`: idle queue is removed after the configured policy and a later Send recreates it and finalizes; measurement law `measure:edge032-convqueue-idle-recreate`.
- L2 `na`: this queue-lifecycle invariant was verified with the real chat service and persistence, but this round did not start a separate managed-gateway five-channel session for a five-minute idle wait.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is an in-memory queue lifecycle contract, with no independent visual geometry, motion, copy, or layout surface.
- L5 `na`: queue recreation is not a distinct user navigation entry; discoverability is covered by the chat/composer journeys.

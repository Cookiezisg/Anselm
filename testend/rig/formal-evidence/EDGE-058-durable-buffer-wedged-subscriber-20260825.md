# EDGE-058 · durable buffer 满断开卡死订阅者

## Verification

The real stream Bus test subscribed a client and deliberately never read from its channel. It then
published `bufSize + subscriberHeadroom + 10` durable frames. The publisher completed within the
three-second guard, proving the full subscriber was disconnected instead of blocking the workspace
fan-out mutex forever. Cancellation remains idempotent on the same Bus implementation.

Focused verification passed:

```text
go test ./internal/infra/stream -run '^TestBus_DurablePublishDisconnectsWedgedSubscriber$' -count=1 PASS
go test -race ./internal/infra/stream -run '^TestBus_DurablePublishDisconnectsWedgedSubscriber$' -count=1 PASS
go test ./internal/infra/stream -count=1 PASS
```

## Five-level applicability

- L1 `pass`: a wedged durable subscriber is disconnected and cannot stall the publisher;
  measurement law `measure:edge058-durable-buffer-wedged-subscriber`.
- L2 `na`: this edge was verified through the real stream Bus boundary, not a separate managed-
  gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is stream backpressure and cancellation semantics, with no independent visual
  geometry, motion, or layout surface.
- L5 `na`: subscriber recovery is an existing stream behavior and introduces no new navigation or
  discovery entry.

# EDGE-059 · ephemeral delta 丢弃不背压

## Verification

The real stream Bus test subscribed a client and deliberately never read from its channel, then
published 100,000 ephemeral delta frames. The flood completed within the two-second guard: deltas
were dropped when the channel filled rather than blocking the producer. A durable frame published
after the flood still received sequence `1`, proving ephemeral frames neither consume the durable
sequence nor enter the replay ring.

Focused verification passed:

```text
go test ./internal/infra/stream -run '^TestPublishEphemeralDropsOnFullSubscriberWithoutBlocking$' -count=1 PASS
go test -race ./internal/infra/stream -run '^TestPublishEphemeralDropsOnFullSubscriberWithoutBlocking$' -count=1 PASS
go test ./internal/infra/stream -count=1 PASS
```

## Five-level applicability

- L1 `pass`: ephemeral deltas are lossy and non-blocking while durable sequence truth remains
  intact; measurement law `measure:edge059-ephemeral-delta-drop`.
- L2 `na`: this edge was verified through the real stream Bus boundary, not a separate managed-
  gateway five-channel session.
- L3 `na`: the focused, race, and package tests provide no independent App frame, SSE tap,
  backend journal, or frontend console observation.
- L4 `na`: this is stream backpressure and durability semantics, with no independent visual
  geometry, motion, or layout surface.
- L5 `na`: delta delivery is an existing stream behavior and introduces no new navigation or
  discovery entry.

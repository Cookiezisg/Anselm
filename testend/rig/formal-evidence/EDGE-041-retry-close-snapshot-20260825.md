# EDGE-041 · retryOf 在 close 快照里

## Verification

The retry assistant's `message_stop` close snapshot carries the `retryOf` pointer through the
actual JSON payload. The regression reads that close frame as a standalone replay artifact, so a
client that connected after `message_start` or rebuilt after a 410 replay can group the replacement
with the superseded answer without relying on the open frame or local process state. An ordinary
turn's close snapshot contains no retry pointer.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_(CloseSnapshotCarriesTheVersionPointer|OpenFramesCarryTheVersionPointer)$' -count=1 PASS
go test -race ./internal/app/chat -run 'TestRetry_CloseSnapshotCarriesTheVersionPointer' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: the durable close snapshot preserves the version link and the ordinary-turn negative case; measurement law `measure:edge041-retry-close-snapshot`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the late-client/replay branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is an SSE payload/version-link invariant, with no independent visual geometry, motion, or layout surface.
- L5 `na`: the behavior is consumed by existing chat reconnect/replay rendering rather than a new product navigation entry; discoverability is covered by chat journeys.

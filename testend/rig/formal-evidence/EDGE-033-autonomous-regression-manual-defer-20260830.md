# EDGE-033 · 关页不留 streaming 孤儿

## Autonomous verification

The backend cancellation regression passed in both ordinary and race modes:

```text
mise exec -- go test -count=1 ./internal/app/chat -run 'TestCancelStreamingTurnFinalizesOnDetachedContext|TestFinalizeCancelled|TestCancel_NoQueue' PASS
mise exec -- go test -race -count=1 ./internal/app/chat -run 'TestCancelStreamingTurnFinalizesOnDetachedContext|TestFinalizeCancelled|TestCancel_NoQueue' PASS
```

The frontend stream-provider regression passed and verifies that the durable cancelled terminal
arrives through the stream rather than being fabricated locally. The Composer test suite was
started, but this invocation hit a local Flutter native-assets/signing race (`objective_c.dylib`
missing) after another Flutter command held the startup lock; it is not used as acceptance proof.

## Manual completion required

L2/L3 remain unsettled. The final acceptance must run the real App with the managed gateway and
the five observation channels while stopping or closing an in-flight turn, then verify the
cancelled transcript, `message_stop`, SSE, backend journal, and frontend console/frames. This is
intentionally deferred under the user-authorized autonomous-first queue; no `pass` or `na` is
written for the missing real observation.

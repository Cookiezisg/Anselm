# EDGE-212 · 瞬时失败绝不轮换

## L1 · 办成

The focused free-tier regression passed under `-race`:

```text
mise exec -- go test ./internal/app/freetier \
  -run 'TestProvisionNow_(TransientFailureNeverRotates|HealFailureLeavesRowIntact)$' \
  -count=1 -race -v

=== RUN   TestProvisionNow_TransientFailureNeverRotates
--- PASS: TestProvisionNow_TransientFailureNeverRotates (0.00s)
=== RUN   TestProvisionNow_HealFailureLeavesRowIntact
--- PASS: TestProvisionNow_HealFailureLeavesRowIntact (0.00s)
PASS
```

The test covers connection refusal, HTTP 429 rate limiting, a healthy probe, and a failed reinstall.
None rotates the existing managed credential except the separate structured `INVALID_INSTALL` path;
failed repair leaves the existing row untouched and retryable.

## Evidence boundary

This is focused/service evidence only. No independent formal real-App, gateway, SSE, wire, timing,
visual-craft, or discoverability session was run for this cell, so L2-L5 remain `na`.

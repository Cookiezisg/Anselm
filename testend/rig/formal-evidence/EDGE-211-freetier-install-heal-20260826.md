# EDGE-211 · 网关 install 自愈

## L1 · 办成

Focused regression:

```text
mise exec -- go test ./internal/app/freetier \
  -run 'TestProvisionNow_(HealsDeadInstall|TransientFailureNeverRotates|HealFailureLeavesRowIntact)$' \
  -count=1 -race -v

=== RUN   TestProvisionNow_HealsDeadInstall
--- PASS: TestProvisionNow_HealsDeadInstall (0.00s)
=== RUN   TestProvisionNow_TransientFailureNeverRotates
--- PASS: TestProvisionNow_TransientFailureNeverRotates (0.00s)
=== RUN   TestProvisionNow_HealFailureLeavesRowIntact
--- PASS: TestProvisionNow_HealFailureLeavesRowIntact (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/freetier 1.858s
```

The regression proves the narrow product contract: a structured `INVALID_INSTALL` probe causes a
fresh gateway install and `RotateManagedCredential` on the same managed row; transient network,
rate-limit and healthy results do not rotate; a failed re-install leaves the row untouched for the
next explicit repair.

## Evidence boundary

This is an L1 focused/service regression only. No independent formal real-App repair session was
run for this cell in this batch, so L2-L5 remain `na`: no five-channel gateway/SSE/wire observation,
no timing series, no Computer Use visual-craft review, and no discoverability session.

# EDGE-214 · 开通降级不挂 boot

## L1 · 办成

Focused regression passed under `-race`:

```text
mise exec -- go test ./internal/app/freetier \
  -run 'Test(ProvisionNow_ReportsHonestly|Ensure_DegradesWithoutFingerprint|Ensure_DegradesOnInstallError|Ensure_DisplayNameConflictIsIdempotent)$' \
  -count=1 -race -v

=== RUN   TestProvisionNow_ReportsHonestly
--- PASS: TestProvisionNow_ReportsHonestly (0.00s)
=== RUN   TestEnsure_DegradesWithoutFingerprint
--- PASS: TestEnsure_DegradesWithoutFingerprint (0.00s)
=== RUN   TestEnsure_DegradesOnInstallError
--- PASS: TestEnsure_DegradesOnInstallError (0.00s)
=== RUN   TestEnsure_DisplayNameConflictIsIdempotent
--- PASS: TestEnsure_DisplayNameConflictIsIdempotent (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/freetier 1.581s
```

The regression covers missing machine fingerprint, gateway install failure, and the concurrent
display-name persistence race. These degraded states return nil from the background ensure path,
never block boot/onboarding, and preserve the honest foreground result (`false,nil` when no managed
row exists). A persistence conflict is treated as the concurrent winner and remains idempotent.

## Evidence boundary

This is focused/service evidence only. No independent formal cold-boot/onboarding App session,
gateway/SSE/wire observation, timing measurement, visual-craft review, or discoverability session was
run for this cell, so L2-L5 remain `na`.

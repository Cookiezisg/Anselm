# EDGE-213 · 未开通读配额

## L1 · 办成

Focused regression passed under `-race`:

```text
mise exec -- go test ./internal/app/freetier \
  -run 'TestQuotaRead_NotProvisioned$' -count=1 -race -v

=== RUN   TestQuotaRead_NotProvisioned
--- PASS: TestQuotaRead_NotProvisioned (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/freetier 1.564s
```

With no managed `anselm` row, the quota reader returns the typed `FREETIER_NOT_PROVISIONED` error
before resolving credentials or contacting the gateway. This lets the settings surface hide the
quota gauge instead of rendering a false zero.

## Evidence boundary

This is focused/service evidence only. No independent formal real-App settings session, gateway/SSE/
wire observation, timing measurement, visual-craft review, or discoverability session was run for
this cell, so L2-L5 remain `na`.

# EDGE-216 · 被引用的 key 拒删

## L1 · 办成

Focused regression passed under `-race`:

```text
mise exec -- go test ./internal/app/apikey \
  -run 'TestDelete_(RefScannerBlocks|OKWhenUnreferenced|InUseCarriesReferences)$' \
  -count=1 -race -v

=== RUN   TestDelete_RefScannerBlocks
--- PASS: TestDelete_RefScannerBlocks (0.00s)
=== RUN   TestDelete_OKWhenUnreferenced
--- PASS: TestDelete_OKWhenUnreferenced (0.00s)
=== RUN   TestDelete_InUseCarriesReferences
--- PASS: TestDelete_InUseCarriesReferences (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/apikey 1.641s
```

The service blocks deletion when a reference scanner reports a scenario/default or other live
reference, carries the structured reference details for repair guidance, and still allows an
unreferenced normal key to be deleted. The managed-key guard remains a separate earlier boundary.

## Evidence boundary

This is focused/service evidence only. No independent formal settings/API, SSE/wire, timing,
visual-craft, or discoverability session was run for this cell, so L2-L5 remain `na`.

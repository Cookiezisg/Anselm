# EDGE-215 · 受管 key 不可变

## L1 · 办成

Focused regression passed under `-race`:

```text
mise exec -- go test ./internal/app/apikey \
  -run 'Test(Delete_ManagedImmutable|Update_ManagedImmutable|AnselmProviderIsManaged)$' \
  -count=1 -race -v

=== RUN   TestDelete_ManagedImmutable
--- PASS: TestDelete_ManagedImmutable (0.00s)
=== RUN   TestUpdate_ManagedImmutable
--- PASS: TestUpdate_ManagedImmutable (0.00s)
=== RUN   TestAnselmProviderIsManaged
--- PASS: TestAnselmProviderIsManaged (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/apikey 1.836s
```

Both update and delete attempts against the managed `anselm` row return the managed-immutability
error, even with zero references; the provider metadata also remains explicitly managed. Normal user
keys remain editable/deletable in the same regression, preventing an over-broad guard.

## Evidence boundary

This is focused/service evidence only. No independent formal settings UI/API/SSE/wire, timing,
visual-craft, or discoverability session was run for this cell, so L2-L5 remain `na`.

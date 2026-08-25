# EDGE-218 · 播种只填未设

## L1 · 办成

Focused regression passed under `-race`:

```text
mise exec -- go test ./internal/app/workspace \
  -run 'TestSeedDefaultsIfUnset$' -count=1 -race -v

=== RUN   TestSeedDefaultsIfUnset
--- PASS: TestSeedDefaultsIfUnset (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/workspace 1.558s
```

The workspace seeding test starts with an explicit user-selected dialogue model, seeds the managed
model, verifies the dialogue pick remains untouched, and verifies unset scenarios are filled. A
second seed is idempotent, so boot/self-heal cannot clobber an explicit user choice.

## Evidence boundary

This is focused/service evidence only. No independent formal settings/model-picker App session,
gateway/SSE/wire observation, timing, visual-craft, or discoverability session was run for this cell,
so L2-L5 remain `na`.

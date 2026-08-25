# EDGE-217 · 旋转 key 重探失败

## L1 · 办成

Focused regression passed under `-race`:

```text
mise exec -- go test ./internal/app/apikey \
  -run 'TestUpdate_KeyRotationProbeFailureStillSucceeds$' -count=1 -race -v

=== RUN   TestUpdate_KeyRotationProbeFailureStillSucceeds
--- PASS: TestUpdate_KeyRotationProbeFailureStillSucceeds (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/apikey 1.576s
```

The PATCH rotation is persisted successfully even when the post-rotation probe fails. The returned
and stored row exposes the failed `testStatus` rather than claiming success or rolling back the new
credential, so rotation state and probe state cannot become split-brain.

## Evidence boundary

This is focused/service evidence only. No independent formal settings/API, gateway/SSE/wire, timing,
visual-craft, or discoverability session was run for this cell, so L2-L5 remain `na`.

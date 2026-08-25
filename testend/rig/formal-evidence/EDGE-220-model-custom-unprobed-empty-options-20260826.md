# EDGE-220 · 未探测/custom 模型

## L1 · 办成

Focused regression passed under `-race`:

```text
mise exec -- go test ./internal/app/model \
  -run 'TestCapabilityValidateOptions_OnlyPermitsPublishedNativeContract$' \
  -count=1 -race -v

=== RUN   TestCapabilityValidateOptions_OnlyPermitsPublishedNativeContract
--- PASS: TestCapabilityValidateOptions_OnlyPermitsPublishedNativeContract (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/model 1.603s
```

The regression confirms that an unlisted/custom model with an empty options map remains writable and
runnable, while adding a native option without a published contract is rejected. The product does not
pretend to know a native schema it has not probed; a misspelled model id remains fail-loud at invoke.

## Evidence boundary

This is focused/service evidence only. No independent formal model-picker/invoke App session,
gateway/SSE/wire, timing, visual-craft, or discoverability session was run for this cell, so L2-L5
remain `na`.

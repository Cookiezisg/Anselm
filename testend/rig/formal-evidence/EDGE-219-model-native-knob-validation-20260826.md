# EDGE-219 · native knob 校验

## L1 · 办成

Focused regressions passed under `-race`:

```text
mise exec -- go test ./internal/app/model ./internal/app/modelref \
  -run 'Test(CapabilityValidateOptions_OnlyPermitsPublishedNativeContract|Validate)$' \
  -count=1 -race -v

=== RUN   TestCapabilityValidateOptions_OnlyPermitsPublishedNativeContract
--- PASS: TestCapabilityValidateOptions_OnlyPermitsPublishedNativeContract (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/model 2.330s
=== RUN   TestValidate
--- PASS: TestValidate (0.00s)
PASS
ok github.com/sunweilin/anselm/backend/internal/app/modelref 1.541s
```

The regression accepts a published native option/value, rejects an unknown knob with
`MODEL_OPTION_UNSUPPORTED`, rejects an invalid enum value with `MODEL_OPTION_VALUE_INVALID`, and
keeps an unprobed/custom model usable when its options map is empty. Write-time validation delegates
to the exact probed key/model contract instead of silently dropping user-visible settings.

## Evidence boundary

This is focused/service evidence only. No independent formal model-picker/API, gateway/SSE/wire,
timing, visual-craft, or discoverability session was run for this cell, so L2-L5 remain `na`.

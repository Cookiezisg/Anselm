# EDGE-045 · retry 的 modelOverride 逐回合

## Verification

The real chat service used a recording resolver across three generations: the first ordinary turn
resolved with the conversation setting, retry resolved with the explicit per-turn model override,
and the next ordinary turn resolved with the conversation setting again. The retried message stored
the actual override model id, while the conversation head was never changed.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_PerTurnModelOverrideDoesNotStickToTheThread' -count=1 PASS
go test -race ./internal/app/chat -run 'TestRetry_PerTurnModelOverrideDoesNotStickToTheThread' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

## Five-level applicability

- L1 `pass`: model override is scoped to exactly one retry generation and is recorded on that version; measurement law `measure:edge045-retry-model-override`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the per-turn model selection branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is model resolution and conversation-head persistence, with no independent visual geometry, motion, or layout surface.
- L5 `na`: the override is an option on the existing retry action, not a new navigation entry; model selection discoverability is covered by chat/settings journeys.

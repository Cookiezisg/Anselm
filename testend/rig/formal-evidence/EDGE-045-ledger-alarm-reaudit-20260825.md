# EDGE-045 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that model override scope was skipped.
- `discovery-collapse`: this edge is a focused model-resolution/head-persistence invariant. L2-L5
  are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestRetry_PerTurnModelOverrideDoesNotStickToTheThread` records all three resolver inputs and the
  retried row's model id over the real messages store/service.
- Full `internal/app/chat` and focused `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

# EDGE-033 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that cancellation finalization was skipped.
- `discovery-collapse`: the row is a deterministic cancellation/finalization invariant. L2-L5 are
  explicitly `na`, not hidden passes.

## Independent revalidation

- `TestCancelStreamingTurnFinalizesOnDetachedContext` starts an in-flight provider stream, invokes
  the service cancellation path, observes `message_stop`, and verifies durable cancellation.
- Focused ordinary and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The re-audit is attached to this row; alarms are acknowledged as controlled timing/applicability
  signals rather than evidence failures.

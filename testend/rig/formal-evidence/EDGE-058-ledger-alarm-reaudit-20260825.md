# EDGE-058 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the wedged-subscriber path was skipped.
- `discovery-collapse`: this edge is a focused stream backpressure invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestBus_DurablePublishDisconnectsWedgedSubscriber` proves the non-reading subscriber cannot
  block durable publishing past the bounded guard.
- Ordinary, focused `-race`, and the complete stream package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

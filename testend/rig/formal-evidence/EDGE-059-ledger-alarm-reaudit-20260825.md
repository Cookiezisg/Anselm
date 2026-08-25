# EDGE-059 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the ephemeral flood path was skipped.
- `discovery-collapse`: this edge is a focused lossy-stream invariant. L2-L5 are explicitly `na`,
  not hidden passes.

## Independent revalidation

- `TestPublishEphemeralDropsOnFullSubscriberWithoutBlocking` checks bounded completion under a
  full non-reading subscriber and verifies the next durable sequence remains 1.
- Ordinary, focused `-race`, and the complete stream package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

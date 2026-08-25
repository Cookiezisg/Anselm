# EDGE-051 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the recovery idempotency test was skipped.
- `discovery-collapse`: this edge is a focused durability invariant. L2-L5 are explicitly `na`,
  not hidden passes.

## Independent revalidation

- `TestSummarize_WatermarkMakesCrashBetweenWritesIdempotent` simulates the exact write boundary,
  recovers with a fresh service, and asserts one summary write with no duplicate archive/anchor.
- Ordinary, focused `-race`, and the complete contextmgr package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

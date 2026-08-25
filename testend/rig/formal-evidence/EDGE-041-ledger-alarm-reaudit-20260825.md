# EDGE-041 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the close snapshot was skipped.
- `discovery-collapse`: this edge is a focused wire/version invariant. L2-L5 are explicitly `na`,
  not hidden passes.

## Independent revalidation

- `TestRetry_CloseSnapshotCarriesTheVersionPointer` parses the actual close event JSON and checks
  both the retry pointer and the ordinary-turn omission; the open-frame companion also passed.
- Focused ordinary and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

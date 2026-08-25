# EDGE-050 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that source deletion was skipped.
- `discovery-collapse`: this edge is a focused historical-lineage invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestDelete_SourceAfterForkLeavesForkLineageAsHistoricalPointers` exercises the real SQLite
  app/store path and checks source absence, fork survival, durable pointer preservation, and list
  projection.
- Ordinary, focused `-race`, and the complete conversation package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

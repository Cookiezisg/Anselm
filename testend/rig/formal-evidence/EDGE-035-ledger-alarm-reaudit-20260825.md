# EDGE-035 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the dual-budget path was skipped.
- `discovery-collapse`: the row is a deterministic timeout-boundary invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestAutoTitle_PersistSurvivesAGenerateThatAteTheBudget` forces the generate budget to expire and
  observes the title write through the independent persist budget.
- Focused ordinary and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

# EDGE-034 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that boot reconciliation was skipped.
- `discovery-collapse`: the row is a deterministic boot/data-integrity invariant. L2-L5 are
  explicitly `na`, not hidden passes.

## Independent revalidation

- `TestSweepOrphansCancelsNonTerminalTurnsPerWorkspace` covered both non-terminal statuses,
  streaming-block cleanup, and cross-workspace isolation.
- Focused ordinary and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

# EDGE-055 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the durable floor was skipped.
- `discovery-collapse`: this edge is a focused retention/checkpoint invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestMaybeCompact_TwoLongMessagesHonorDurableRecentFloor` checks the exact two-message oversized
  boundary and all forbidden durable writes; the checkpoint regression checks the prompt escape hatch.
- Ordinary, focused `-race`, and the complete contextmgr package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

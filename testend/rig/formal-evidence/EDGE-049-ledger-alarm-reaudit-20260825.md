# EDGE-049 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that cross-message remapping was skipped.
- `discovery-collapse`: this edge is a focused block-tree invariant. L2-L5 are explicitly `na`,
  not hidden passes.

## Independent revalidation

- `TestFork_PrefixWindowSeqRenumberAndNestedRemap` uses the real messages store and checks both
  parent-pointer locations, destination ID closure, contiguous sequence numbers, and source
  immutability.
- Ordinary, focused `-race`, and the complete chat package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

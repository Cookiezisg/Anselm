# EDGE-048 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that pointer remapping was skipped.
- `discovery-collapse`: this edge is a focused lineage invariant. L2-L5 are explicitly `na`, not
  hidden passes.

## Independent revalidation

- `TestFork_VersionChainRebasedIntoTheFork` proves both copied pointers target fork-local IDs and
  that the fork LLM view hides the superseded answer.
- `TestFork_CutAtAnOlderVersionLeavesItCurrent` proves outside-window `superseded_by` and
  `retryOf` references are cleared.
- Ordinary and focused `-race` verification passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

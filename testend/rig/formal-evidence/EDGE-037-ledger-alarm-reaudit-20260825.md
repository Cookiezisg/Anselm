# EDGE-037 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that archived Send was skipped.
- `discovery-collapse`: the row is a deterministic archived-state recovery invariant. L2-L5 are
  explicitly `na`, not hidden passes.

## Independent revalidation

- `TestSendArchivedConversationUnarchivesAndContinues` covers both successful unarchive and the
  soft-failure path, with a terminal assistant close in both cases.
- Focused ordinary and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

# EDGE-054 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that attachment compaction was skipped.
- `discovery-collapse`: this edge is a focused attachment-grounding invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestMaybeCompact_OldAttachmentForcesTraceableSummary` checks the native-attachment force path,
  opaque ID in the summary prompt, watermark advancement, and archive backstop.
- Ordinary, focused `-race`, and the complete contextmgr package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

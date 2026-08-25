# EDGE-057 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that cursor-source handling was skipped.
- `discovery-collapse`: this edge is a focused transport invariant. L2-L5 are explicitly `na`,
  not hidden passes.

## Independent revalidation

- `TestDecodeFromSeq` checks header precedence, query fallback, absent cursor, and malformed cursor.
- `TestStreamHandler_SeqTooOld410` checks the structured error's HTTP mapping.
- Ordinary, focused `-race`, and the complete handlers package passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

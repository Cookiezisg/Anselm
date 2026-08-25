# EDGE-043 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that the mid-write failure was skipped.
- `discovery-collapse`: this edge is a focused append-only/failure-truth invariant. L2-L5 are
  explicitly `na`, not hidden passes.

## Independent revalidation

- `TestRetry_WriteOrderLeavesBothQuestionsVisibleOnInterruption` uses the real messages store with a
  narrow pointer-write fault and checks durable rows plus assembled LLM history.
- Full `internal/app/chat` and focused `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

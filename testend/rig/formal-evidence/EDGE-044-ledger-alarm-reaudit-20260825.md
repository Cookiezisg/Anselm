# EDGE-044 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that either non-terminal gate was skipped.
- `discovery-collapse`: this edge is a focused in-memory/durable concurrency invariant. L2-L5 are
  explicitly `na`, not hidden passes.

## Independent revalidation

- `TestRetry_RejectsInMemoryGeneratingTurn` pins the provider inside the real queue and checks no
  speculative rows; `TestRetry_RejectsWhatCannotBeRetried` checks the real durable streaming tail.
- Full `internal/app/chat` and focused `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

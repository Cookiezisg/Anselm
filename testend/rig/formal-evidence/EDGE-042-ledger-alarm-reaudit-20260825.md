# EDGE-042 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that crash recovery was skipped.
- `discovery-collapse`: this edge is a focused recovery/transcript invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestRetry_BareUserTailProducesTheMissingAnswer` exercises the real service/store path, including
  boot sweep, retry enqueue, close, durable row count, retry pointer absence, and LLM projection.
- Full `internal/app/chat` and focused `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

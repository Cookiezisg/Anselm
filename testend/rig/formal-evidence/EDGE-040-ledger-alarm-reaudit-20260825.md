# EDGE-040 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that history reads were skipped.
- `discovery-collapse`: this edge is a deliberate durable-read versus LLM-projection invariant;
  L2-L5 are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestRetry_SupersededRowsRemainInEveryHistoryRead` exercises the service over the real messages
  store and covers ordinary paging, `around`, `dir=newer`, and `LoadThreadForLLM` together.
- Full `internal/app/chat` and the focused `-race` run passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

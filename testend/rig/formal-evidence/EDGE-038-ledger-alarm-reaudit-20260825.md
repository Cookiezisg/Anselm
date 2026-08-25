# EDGE-038 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that retry semantics were skipped.
- `discovery-collapse`: the row is a deterministic retry/version invariant. L2-L5 are explicitly
  `na`, not hidden passes.

## Independent revalidation

- `TestRetry_RegenerateSupersedesTheAnswerAndKeepsItReadable` verifies old-row readability, no
  duplicate user turn, and the current LLM view after regeneration.
- Focused ordinary and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

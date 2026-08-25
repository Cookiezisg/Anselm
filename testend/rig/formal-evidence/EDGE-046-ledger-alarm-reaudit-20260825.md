# EDGE-046 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; this is a
  ledger timing signal, not evidence that fork summary handling was skipped.
- `discovery-collapse`: this edge is a focused summary/watermark projection invariant. L2-L5 are
  explicitly `na`, not hidden passes.

## Independent revalidation

- `TestFork_SummaryCarriedWhenCutIsAtOrAfterWatermark` uses the real store and fork service and
  checks both copied summary metadata and the re-based watermark.
- Full `internal/app/chat` and focused `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- The alarms are acknowledged as controlled timing/applicability signals, not evidence failures.

# EDGE-029 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; the alarm
  measures ledger timing, not unsupported review speed.
- `discovery-collapse`: duplicate resolve handling is a deterministic idempotency boundary. The
  focused test passes and levels 2-5 are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestResolveInteraction_ConversationScoped` resolves a real ask interaction, then repeats the
  same service request and requires `ErrNoPendingInteraction`.
- `TestResolveUnknownIsNoop` independently locks broker safe handling for unknown/already-resolved ids.
- Focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 526 carried judgments, 0 tombstones.

The alarms describe controlled ledger timing and honest applicability, not an evidence failure.
They are acknowledged with this re-audit attached.

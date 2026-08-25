# EDGE-028 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; the alarm
  measures ledger timing, not unsupported review speed.
- `discovery-collapse`: this is a closed-enum protocol invariant. The focused test passes and levels
  2-5 are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestResolveInteractionRejectsUnknownActionLoudly` sends `aprove` and verifies the stable error
  plus all five `validActions` details before any conversation lookup.
- Focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 525 carried judgments, 0 tombstones.

The alarms describe controlled ledger timing and honest applicability, not an evidence failure.
They are acknowledged with this re-audit attached.

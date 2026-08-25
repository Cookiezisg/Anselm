# EDGE-026 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; the alarm
  measures that ledger protocol, not unsupported review speed.
- `discovery-collapse`: this is a deterministic trust-state transition. The focused tests found no
  failure and levels 2-5 are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate` proves changed `allowed-tools` resets
  the prior approval and local drift remains protected.
- `TestUpdateInstalled_UnchangedToolsKeepApproval` proves a body-only update preserves approval
  when the requested grant has not changed.
- Focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 523 carried judgments, 0 tombstones.

The alarms describe controlled ledger timing and honest applicability, not an evidence failure.
They are acknowledged with this re-audit attached.

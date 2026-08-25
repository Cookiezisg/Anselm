# EDGE-024 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: this row's five levels were recorded as one controlled batch; the spacing alarm
  therefore measures the ledger protocol, not an unsupported speed claim.
- `discovery-collapse`: this row is a deterministic read/write residency rule with no focused fail;
  levels 2-5 are explicitly `na`, so the clean result is not hidden product coverage.

## Independent revalidation

- `TestDispatchWithGate_NonWriterToolNeverPathGated` now covers both `Read` and `Grep` outside the
  mounted root.
- Neither call surfaces an interaction; both execute successfully.
- Focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 521 carried judgments, 0 tombstones.

The alarms describe controlled ledger timing and honest applicability, not an evidence failure.
They are acknowledged with this re-audit attached.

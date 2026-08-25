# EDGE-022 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch, so the
  timestamp-spacing curve detected the ledger protocol rather than inferring observation speed.
- `discovery-collapse`: this is a deterministic work-directory safety invariant; the focused tests
  found no failure, and levels 2-5 are explicitly `na`, not hidden passes.

## Independent revalidation

- `TestDispatchWithGate_OutsideWorkDirForcesGate` proves a safe self-report cannot bypass the
  outside-root gate and that `outsideWorkDir=true` is surfaced.
- `TestDispatchWithGate_OutsideWorkDirIgnoresApproveAlways` and
  `TestDispatchWithGate_OutsideWorkDirIgnoresSkillPreApproval` prove both bypass paths remain
  blocked for out-of-root writes.
- Focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 519 carried judgments, 0 tombstones.

The alarms describe the controlled ledger write pattern and honest applicability, not an evidence
failure. They are acknowledged with this re-audit attached.

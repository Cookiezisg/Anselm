# EDGE-025 · 账本警报独立复审

## Triggered alarms

- `gap-too-fast`: the five judgments were written as one controlled row-closing batch; the alarm
  measures that protocol, not the evidence review itself.
- `discovery-collapse`: the trust gate is a deterministic state invariant. The focused tests found
  no failure, while levels 2-5 are explicitly `na`, not silently counted as passes.

## Independent revalidation

- `TestTrustGate_WithholdsUntilApproved` proves body injection and active-skill identity survive
  while pre-authorization is withheld, then become active only after explicit approval.
- `TestDispatchWithGate_NotPreApprovedGated` proves an uncovered dangerous tool still surfaces and
  is denied instead of using the skill name as a blanket bypass.
- Focused and `-race` runs passed.
- No CODEX law, alarm threshold, coverage rule, anchor, or gate was changed.
- `gen_coverage.py --check` remains clean: 848 rows, 522 carried judgments, 0 tombstones.

The alarms describe controlled ledger timing and honest applicability, not an evidence failure.
They are acknowledged with this re-audit attached.

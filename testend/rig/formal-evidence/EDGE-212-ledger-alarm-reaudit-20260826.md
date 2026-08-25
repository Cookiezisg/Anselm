# EDGE-212 · ledger alarm re-audit

- `gap-too-fast` is the expected guard firing for the five journal entries of one atomic row; the
  L1 pass is backed by a race-enabled focused test and L2-L5 are explicit `na`, not five fabricated
  product passes.
- `discovery-collapse` reflects the focused-only batch window: no failure was observed in this
  regression, while absent real-App/five-channel evidence is deliberately recorded as `na`.
- Anchor calibration remains `10/10`; the sequence gate allowed only the first unsettled row. Keep the
  target at `✓~~~~`, retain all evidence boundaries, and acknowledge both alarms for this re-audited
  atomic judgment only.

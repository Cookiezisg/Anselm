# EDGE-214 · ledger alarm re-audit

- `gap-too-fast` is the expected signal for five entries settling one atomic row; the local
  regression is one L1 claim and the four higher-level entries explicitly remain `na`.
- `discovery-collapse` is explained by the focused-only window: the degraded-provision tests passed,
  and the missing cold-boot/real-App evidence was not falsely marked green.
- Anchor calibration remains `10/10`; the first-unsettled sequence gate admitted only `EDGE-214`.
  Keep `✓~~~~`, preserve the evidence boundary, and acknowledge both alarms for this re-audit.

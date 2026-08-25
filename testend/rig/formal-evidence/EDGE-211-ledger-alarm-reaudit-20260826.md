# EDGE-211 · ledger alarm re-audit

- `gap-too-fast` was opened because the five levels of one EDGE row are necessarily journaled in one
  short command sequence. This is not five independent product claims: it is one focused L1 result
  plus four explicit `na` boundaries, all backed by the same recorded test scope.
- `discovery-collapse` was opened because the recent window contains no product `fail`. The absence is
  explained by the current batch policy: focused regressions are only marked pass when they pass, and
  missing real-App/five-channel evidence is marked `na`, never silently converted to a pass. The
  anchor calibration is current (`10/10`), and the coverage target is `EDGE-211` in first-unsettled
  order.
- Re-audit action: keep `EDGE-211` as `✓~~~~`, retain the L2-L5 `na` notes, and do not promote this
  cell without an independent formal repair session. Both alarms may be acknowledged with this note;
  the next new judgment must re-run the alarm curves.

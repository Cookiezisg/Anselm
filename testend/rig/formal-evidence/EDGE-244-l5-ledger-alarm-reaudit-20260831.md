# EDGE-244 L5 ledger/alarm re-audit

- Re-audit target: `EDGE|bearer token 缺失` L5=`G1`, using the repaired
  real-App session `/private/tmp/anselm-rig-formal-20260831-13/sessions/20260831-175540`.
- The reviewer re-read the normal launch path, Computer Use AX tree, repaired
  stable frame, frontend source/test, backend 401 journal and the session
  manifest. The evidence shows a discoverable user action without exposing
  internal auth vocabulary; it is not inferred from the ledger or from the
  earlier red state.
- The raw-detail defect remains preserved as a red finding and was fixed
  before this judgment. `gap-too-fast` and `discovery-collapse` are treated as
  review telemetry only; thresholds (`25s`, `5%`) and their algorithms remain
  unchanged.
- Anchors remain `10/10`; `gen_coverage.py --check` remains `848 rows, 848
  carried judgments, 0 tombstones`. No CODEX law, five-level standard,
  sequence policy or alarm gate changed.

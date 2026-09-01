# EDGE-244 fixed L4 ledger/alarm re-audit

- Re-audit target: the red `EDGE|bearer token 缺失` L4 finding and its
  repaired replacement, using sealed session
  `/private/tmp/anselm-rig-formal-20260831-13/sessions/20260831-175540`.
- The reviewer re-read the red frame, the updated source/test, the repaired
  Computer Use AX tree and recording, strict diff/latency/regions/contrast
  measurements, backend 401, SSE, frontend and LLM journals, and the
  pre-teardown rig check. The raw diagnostic is absent from the product frame
  while remaining available to operators in journals.
- The failure and repair are both preserved in the append-only judgment
  journal; the green replacement is not a deletion of the red evidence.
- `gap-too-fast` is treated as ledger write-rate telemetry and `discovery-
  collapse` as the trailing-window fail-share signal. Their original `25s`
  and `5%` thresholds remain unchanged; no alarm algorithm, CODEX law, anchor
  set, five-level standard or sequence policy changed.
- Anchors remain `10/10`; `gen_coverage.py --check` remains `848 rows, 848
  carried judgments, 0 tombstones`.

# SURF-072 · ledger/alarm re-audit

## Re-audit

- Time: `2026-08-20 00:10 +08`
- Red discovery session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-234423`（未入账）
- Fixed green sessions: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-235804`, `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-000144`
- Evidence reread: both fixed `screen.mov`, recording lifecycle, manifests, backend journals, three-stream `sse.jsonl`, frontend journals, llmtap journals, focused Flutter output, and successful live `rig-check`/`rig-down`.

## Independent result

- The red run found two concrete product defects and stopped: stale slug error presentation and a breadcrumb path that bypassed dirty-state confirmation. Those observations were repaired in code and covered by a new shell-level regression test; the red session is explicitly not admissible evidence.
- The fixed run re-exercised both defects as positive regressions. A legal name cleared the previous error before save. A dirty detail stayed mounted after `Keep editing` and only left after `Discard`.
- The deletion run exercised both cancel and confirm branches. The UI warning named the exact memory and the irreversible physical-file consequence; the `memory.deleted` notification arrived after the row disappeared.
- No law, threshold, coverage row, anchor, alarm algorithm, or gate definition was weakened. The expected `400` for an intentionally incomplete create request is documented as a negative product path, followed by a real `200` after the required fields were supplied.

## Decision

The five judgments are admissible after the fixed sessions are copied into the evidence store. Recompute alarms after the five serial writes; if the statistical alarms open, acknowledge them only with this independent re-audit as the resolution note. Do not alter thresholds or bypass the gate.

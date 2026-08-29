# EDGE-308 账本与告警复审

- target: `EDGE-308 | 侧幕失败行清除 | L3`
- judgment: `pass (B2)`
- primary evidence: `testend/rig/formal-evidence/EDGE-308-sidestage-failure-clear-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-164838`
- anchors: `10/10` calibration passed; judge unlocked

## Ledger re-audit

- `COVERAGE.md` row `EDGE-308` is present in the generated `848`-row inventory.
- The row carries the prior L1/L2 judgments and the new `L3:B2` evidence without replacing or weakening earlier evidence.
- The law reference `B2` exists in `docs/working/acceptance-loop/CODEX.md`.
- The primary evidence is a non-empty formal file and names the real App session, frame samples, five journals, and durable SQLite truth.
- The L3 claim is limited to frame-level stability of the failure hold and its row-level clear exit; it does not claim L4 craft or L5 discoverability.

## Alarm re-audit

The new judgment caused the expected statistical signals:

- `pass-burst`: the recent ten judgments completed faster than the trailing baseline. This is a throughput signal, not evidence that the product passed by itself.
- `discovery-collapse`: the trailing failure share is below the configured floor. The anchor set was rechecked at `10/10`, and this real failure path contains an intentional failed Function, a visible red failure state, and a preserved traceback rather than an artificially successful fixture.

Both signals are therefore explained by a legitimate batch boundary and independently evidenced real failure path. They are acknowledged with this note; no threshold, law, anchor, or gate was changed. The final `alarms.py check` must be clean before this cell is considered closed.

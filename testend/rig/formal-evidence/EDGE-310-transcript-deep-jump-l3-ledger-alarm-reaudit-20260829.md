# EDGE-310 账本与告警复审

- target: `EDGE-310 | 深跳 ?around= 整窗替换 | L3`
- judgment: `pass (B2)`
- primary evidence: `testend/rig/formal-evidence/EDGE-310-transcript-deep-jump-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-062450`
- anchors: `10/10` calibration passed; judge unlocked

## Ledger re-audit

- `COVERAGE.md` retains the existing L1/L2 judgments and adds `L3:B2`; no previous evidence was replaced or weakened.
- `B2` exists in `docs/working/acceptance-loop/CODEX.md`.
- The new evidence is non-empty and contains the real App session, copied stable frames, measured transition data, five-channel references, and the durable-window boundary.
- The judgment distinguishes user-triggered deep-jump/re-anchor replacement from non-user movement and makes no L4/L5 claim.

## Alarm re-audit

The judgment reopened the expected statistical signals:

- `pass-burst`: recent throughput is faster than the long trailing baseline. This is a batch-progress signal and not evidence that the unmeasured dimensions passed.
- `discovery-collapse`: the trailing failure share is below the configured floor. Anchors were rechecked at `10/10`; the new evidence explicitly records the large user-triggered diffs and independently checks long stable windows after each transition.

Both signals are explained by the current batch boundary and the intentionally conservative cell-level scope. They are acknowledged here without changing thresholds, law text, anchor answers, or gate behavior. The final `alarms.py check` must be clean before the cell is closed.

# EDGE-309 账本与告警复审

- target: `EDGE-309 | 侧幕分档时钟 | L3`
- judgment: `pass (B2)`
- primary evidence: `testend/rig/formal-evidence/EDGE-309-sidestage-relative-clock-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-055857`
- anchors: `10/10` calibration passed; judge unlocked

## Ledger re-audit

- `COVERAGE.md` retains the existing L1/L2 evidence and adds `L3:B2` without replacing, weakening, or erasing any prior judgment.
- The cited law `B2` exists in `docs/working/acceptance-loop/CODEX.md`.
- The new formal evidence is non-empty and includes the real App recording, independent pixel measurement, five-channel journal references, and the durable-result boundary.
- The L3 claim is deliberately limited to the relative-clock transition's frame stability; it does not claim L4 visual craft or L5 discoverability.

## Alarm re-audit

The new judgment reopened the expected statistical signals:

- `pass-burst`: recent judgments are faster than the long trailing baseline because this batch is progressing through already instrumented cells; it is a throughput warning, not a product verdict.
- `discovery-collapse`: trailing failure share is below the configured floor. The anchor set was rechecked at `10/10`, and this cell includes an independently measured transition with a nonzero, localized change rather than an unexamined pass.

Both signals are explained by the batch boundary and are acknowledged with this evidence. No alarm threshold, law, anchor answer, or gate behavior was changed. The final `alarms.py check` must be clean before the cell is closed.

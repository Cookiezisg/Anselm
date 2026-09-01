# EDGE-214 · ledger alarm re-audit

The four EDGE-214 judgments were independently re-read after `alarms.py check` opened
`gap-too-fast` and `discovery-collapse`. The short gaps are an artifact of one bounded startup
session followed by sequential ledger writes, not evidence that the App frame was skipped: the
session contains a finalized `33.421667s` MOV, backend journal, three SSE connections, frontend
console, and LLM wire journal, and `rig-check` passed before teardown.

The discovery curve is expected for this one degraded boundary: it has no product failure to
report in the repaired session, while the closed-upstream install failure is explicitly preserved
as the negative boundary rather than hidden. The evidence does not alter the threshold, the
five-level standard, CODEX, anchors, or sequence policy. The anchor set remains `10/10`; the next
pass is allowed only after this re-audit is acknowledged.

Evidence reviewed:

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-110713`
- Product evidence: `EDGE-214-real-app-provision-degraded-green-20260831.md`
- Focused branches: `backend/internal/app/freetier/freetier_test.go`
- Controls: `testend/rig/judge.py`, `testend/rig/alarms.py`, and `ledger-sequence.json`

Disposition: acknowledge only the two expected statistical alarms; leave all thresholds and
judgement criteria unchanged.

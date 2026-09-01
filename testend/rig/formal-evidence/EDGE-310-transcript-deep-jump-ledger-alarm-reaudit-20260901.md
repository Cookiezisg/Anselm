# EDGE-310 深跳：ledger/alarm 独立复审

- live judgment: `EDGE|深跳 ?around= 整窗替换|L4=pass|C4`
- formal evidence: `testend/rig/formal-evidence/EDGE-310-transcript-deep-jump-l4-l5-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-193428`
- journal: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`

The unchanged `discovery-collapse` alarm opened after the L4 ledger write because the trailing
50 live judgments had `0.0% < 5%` fail share. This remains a statistical stop signal, not a
product verdict and not permission to lower the bar.

Independent review re-read the sealed session, the four extracted Computer Use frames, the
REST `?around=` results for earliest/middle/latest targets, the forward continuation result,
the backend/frontend journals, all three SSE connections, and the rig lifecycle. The first
malformed-time fixture that duplicated the pivot was retained as a red test-data finding and
excluded; the corrected production-driver timestamp format returned each pivot exactly once.
The real App session then showed the earliest and middle target windows, the explicit
`Jump to present` affordance, and stable forward scrolling without a second pivot or viewport
reset. `anchors.py check` remained `10/10`.

No alarm threshold, algorithm, anchor set, CODEX law, five-level standard, or sequence policy
was changed. The alarm is acknowledged only against this independently reviewed evidence and
the current journal watermark; a later applicable statistical signal must reopen it.

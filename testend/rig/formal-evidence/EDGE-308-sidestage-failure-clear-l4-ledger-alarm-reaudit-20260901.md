# EDGE-308 侧幕失败行清除：L4 ledger/alarm re-audit

- live judgment: `EDGE|侧幕失败行清除|L4=pass|C4`
- formal evidence: `testend/rig/formal-evidence/EDGE-308-sidestage-failure-clear-l4-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-174601`
- journal: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`

The ledger accepted the L4 judgment only after the fresh real-App session was sealed. The session
contains the window-owned recording, backend journal, independent three-stream SSE witness,
frontend console, managed LLM wire journal, and SQLite execution truth. The Computer Use AX
witness also proves the hover-only `Clear this row` affordance and its post-click `Ran` state.

The unchanged `discovery-collapse` alarm opened because the trailing-50 fail-share rule observed
`0.0% < 5%`. This is the expected statistical alarm after a clean run, not evidence to weaken the
standard: the new session was independently watched and the failure path was deliberately injected.
No threshold, anchor, CODEX law, or gate algorithm changed. This alarm is acknowledged against the
newest journal watermark; the final `alarms.py check` must be clean before another pass is recorded.

# EDGE-308 侧幕失败行清除：L5 ledger/alarm re-audit

- live judgment: `EDGE|侧幕失败行清除|L5=pass|G1`
- formal evidence: `testend/rig/formal-evidence/EDGE-308-sidestage-failure-clear-l5-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-175425`
- journal: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`

The ledger accepted this L5 judgment only after a fresh real-App session was sealed. The session
contains the window-owned recording, backend journal, independent three-stream SSE witness,
frontend console, managed LLM wire journal, SQLite durable truth, and Computer Use screenshots/AX
evidence for both the hover affordance and the post-clear state.

The unchanged `discovery-collapse` alarm opened because the trailing-50 fail-share rule observed
`0.0% < 5%`. Review found a deliberately injected failure, an independent ordinary-user path,
and a real UI affordance whose honest result was checked against durable history. The test stopped
the model's unnecessary second exploratory branch before it could repeat the fixture; that control
is explicitly disclosed in the formal evidence and is not counted as a product success. No
threshold, anchor, CODEX law, or gate algorithm changed. The alarm is acknowledged against this
new journal watermark; the final `alarms.py check` must be clean before the next pass.

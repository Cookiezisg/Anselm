# EDGE-306 L3 ledger alarm re-audit

- trigger: `discovery-collapse` after the fresh L3 judgment; the trailing 50 judgment window had no failures because this is a clean acceptance run.
- evidence: `/Users/sunweilin/Developer/Anselm/testend/rig/formal-evidence/EDGE-306-live-ghost-cleanup-l3-real-app-20260829.md`
- independent checks: the session contains a window-owned recording, backend journal, three-stream SSE journal, frontend console journal, LLM wire journal, proxy journal proving `drop → 410 → forward`, and SQLite durable-result verification.
- disposition: acknowledged as a statistical low-failure-rate alarm, not a product failure. Thresholds, CODEX laws, anchors, and ledger gate were not changed. The judgment remains backed by real five-channel evidence and the alarm is closed with an explicit note.

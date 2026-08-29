# EDGE-304 L3 ledger alarm re-audit

- trigger: `discovery-collapse` after the fresh L3 judgment; the trailing 50 judgment window had no failures because this is a clean acceptance run.
- evidence: `/Users/sunweilin/Developer/Anselm/testend/rig/formal-evidence/EDGE-304-sidestage-follow-modes-l3-real-app-20260829.md`
- independent checks: the same session has a window-owned recording, backend journal, three-stream SSE journal, frontend console journal, and LLM wire journal; frame measurements are stored under `/private/tmp/edge304-first-hi-20260829` and `/private/tmp/edge304-every-hi-20260829`.
- disposition: acknowledged as a statistical low-failure-rate alarm, not a product failure. Thresholds, CODEX laws, anchors, and ledger gate were not changed. The judgment remains backed by real five-channel evidence and the alarm is closed with an explicit note.

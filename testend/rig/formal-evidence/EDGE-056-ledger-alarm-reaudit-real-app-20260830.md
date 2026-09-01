# EDGE-056 · 账本与告警复审

- The L2 judgment was written only after the isolated formal session was sealed and the evidence
  was copied inside that session; the first outside-session attempt was refused by `judge.py`.
- The session contains a window-owned recording, backend journal, independent three-stream SSE
  journal, frontend console journal, LLM wire journal, and the exact backend `SEQ_TOO_OLD` response.
- The messages replay sequence was observed from the real baseline cursor `seq=8` through `seq=392`
  while the App connection was down; the backend, not the proxy, returned HTTP 410 with
  `code=SEQ_TOO_OLD`.
- The two alarms opened immediately after this judgment are expected rate-shape alarms: the
  judgment journal has a short write interval and no new failure in the last 50 rows. I re-audited
  the full session and did not change any threshold, law, anchor, or verdict. They are resolved by
  this independent evidence review, not by suppressing the curves.

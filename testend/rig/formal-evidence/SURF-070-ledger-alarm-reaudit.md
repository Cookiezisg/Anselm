# SURF-070 · ledger/alarm re-audit

## Re-audit

- Time: `2026-08-19 23:20 +08`
- Trigger: SURF-070 was first observed in a non-clean session after an App restart; the conductor therefore refused to use that session as the sole formal proof.
- Clean source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-231808`
- Earlier product-path source: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-225633`
- Evidence reread: clean `screen.mov`, `recording-lifecycle.json`, `backend.log`, `sse.jsonl`, `frontend.log`, `llm.jsonl`, the earlier generation/media journals, the 35-test Flutter output, and the successful live `rig-check`.

## Independent result

- The five cells were not inferred from a generated attachment row. A real managed-gateway image and video were generated, the image was opened in the full-size viewer, the video was initialized by the real macOS player, played to a visible frame, allowed to finish, replayed, seeked to the middle, paused and opened in the shared full-screen viewer.
- The first session's App PID mismatch was treated as an evidence-quality defect, not silently waived. The old session was sealed; a new session started and owned the backend, ssetap, llmtap, direct App and window recorder from the beginning. `rig-check` passed all five physical attribution checks.
- The gray poster seen before initialization was explicitly investigated. Backend content and Range requests were successful, the local blob was a valid H.264/AAC MP4, and a later clean run produced the real lighthouse frame and transport state. The intermediate frame is not recorded as a product failure or as a false pass.
- UI media metadata, REST attachment metadata, SQLite `attachments` row, blob size/hash, SSE tool-result lifecycle and LLM wire evidence agree. The clean restart rebuilt the conversation from durable state and the card remained discoverable; no orphan streaming state or frontend error appeared.
- No law, threshold, coverage row, anchor or gate definition was weakened. The alarm check and anchor calibration were rerun before ledger entry.

## Decision

The alarms are acknowledged only for this judgment batch. The next batch must recompute all three curves; this note is not a blanket waiver for future fast or all-green judgments.

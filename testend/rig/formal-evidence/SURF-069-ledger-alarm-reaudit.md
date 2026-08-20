# SURF-069 · ledger/alarm re-audit

## Re-audit

- Time: `2026-08-19 22:51 +08`
- Trigger: the five SURF-069 judgments opened `gap-too-fast` and `discovery-collapse`.
- Source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-224143`
- Evidence reread: sealed `screen.mov`, the two saved panel frames, `recording-lifecycle.json`, `backend.log`, `sse.jsonl`, `frontend.log`, `llm.jsonl`, the 55-test Flutter output and the successful live `rig-check`.

## Independent result

- The five cells were not inferred from one screenshot: a real managed-gateway workspace was provisioned, the complete Models & keys panel was traversed, six scenario selectors were expanded and closed, quota and model-capability refreshes were executed, and the final panel returned to a stable state without configuration drift.
- The free-tier card, managed key row, cloned-voice empty inventory, scenario defaults and Search key empty state were cross-checked against the backend and gateway journals. The settings path performed no entity/message mutation, so the eight-line SSE journal (discovery, three connects and clean disconnects) is the honest expected result; no durable business frame was invented.
- The visual judgment used the continuous app-region recording and saved top/scenario frames. No layout jump, clipped text, stale spinner, accidental selector commit or misleading “wait for quota reset” voice-inventory copy was observed. The focused 55-test suite passed, including the inventory-not-daily-quota wording law across every locale.
- All five channels were physically attributed by `rig-check`; `rig-down` sealed the recording and left no backend, ssetap, llmtap, App or recorder process. No law, threshold, coverage row, anchor or gate definition was weakened.

## Decision

The alarms are acknowledged only for this judgment batch. The next batch must recompute all three curves; this note is not a blanket waiver for future fast or all-green judgments.

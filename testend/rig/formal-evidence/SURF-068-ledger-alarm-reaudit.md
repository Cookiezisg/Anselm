# SURF-068 · ledger/alarm re-audit

## Re-audit

- Time: `2026-08-19 22:38 +08`
- Trigger: the five SURF-068 judgments opened `gap-too-fast` and `discovery-collapse`.
- Source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-221915`
- Evidence reread: the sealed `screen.mov`, `recording-lifecycle.json`, `backend.log`, `sse.jsonl`, `frontend.log`, `llm.jsonl`, final SQLite workspace row, focused Flutter output and the successful live `rig-check`.

## Independent result

- The five cells were not inferred from one settings screenshot: the session exercised a real managed-gateway chat, a real tool activity, tool cancellation, two workspace PATCHes with final SQLite readback, a Models & keys navigation round trip and restoration of defaults.
- The apparent absence of an auto-opened island during `Glob` is consistent with the repository's explicit stage route: `Glob` is not in the stage-worthy set. The focused `sidestage_auto_reveal_test.dart` and `stage_director_test.dart` cover the actual stage-worthy route and the three follow modes; no law or threshold was weakened.
- The long recursive `Glob` was stopped deliberately after the UI showed approximately 53 seconds. The stop caused `/conversations/{id}:cancel`, an SSE `tool_result` close with `status=cancelled`, an assistant `message close` with `stopReason=cancelled`, and a clean UI `Interrupted` state. No hidden success or orphan activity was counted.
- The 97-test focused Flutter suite passed. The source evidence contains all five channels and rig attribution; the App was stopped only after evidence capture and the recording was sealed at `963.813333s` with no process remnants.

## Decision

The alarms are acknowledged only for this judgment batch. The next batch must recompute all three curves; this note is not a blanket waiver for future fast or all-green judgments. No coverage row, law, anchor, threshold or gate definition changed.

# SURF-066 · ledger/alarm re-audit

## Re-audit

- Time: `2026-08-19 22:01 +08`
- Trigger: the ledger opened `gap-too-fast` and `discovery-collapse` after the five sequential SURF-066 judgments.
- Ledger movement: `2275 → 2280`; only the five SURF-066 levels were added.
- Source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-214739`
- Evidence reread: all SURF-066 screenshots, the `673.656667s` screen recording, `backend.log`, `sse.jsonl`, `frontend.log`, `llm.jsonl`, SQLite workspace language, focused test output and the live `rig-check` result.

## Independent result

- `gap-too-fast` is explained by the required five-level ledger protocol: one real App session was observed for more than eleven minutes and judged level-by-level only after the evidence and focused tests were complete. The close-write cadence is a ledger signal, not evidence that the App path was skipped.
- `discovery-collapse` is not supported by the source evidence. The path included positive and negative setting states: dark/system/light, minimum and capped zoom, disabled high zoom click, three font axes, English/Chinese/System language transitions, workspace PATCH responses, off/on switch round trips and restoration to defaults. No failure was hidden by the alarm window.
- The focused Flutter suites passed `38/38` and `12/12`; the source evidence shows all five channels and the rig attribution check passed while the App was alive.
- No law, threshold, anchor, coverage row, or gate definition is changed by this re-audit. No product defect was found and no stop-and-fix action is required.

## Decision

The two alarms are acknowledged for this judgment batch only. They must be recomputed on the next batch; this note is not a blanket waiver for future fast or all-green judgments.
